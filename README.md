# wrapped-images

외부 오픈소스 컨테이너 이미지(Docker Hub / quay / ghcr 등)를 **OCI(KSA) 외부 오픈소스 이미지 보안 정책**에 맞춰
허용된 **BaseImage(navix / ubuntu / alpine)** 로 **래핑(wrapping)** 한 Dockerfile 을 모아두고, CI 로 멀티아치 빌드해
**OCIR** 로 push 하는 저장소입니다.

> 정책 핵심: **외부 이미지는 직접 pull·배포 금지. 허용 BaseImage 로 래핑 → OCIR push → 보안검수** 순서로만 사용한다.

---

## 1. 목적

- 외부 이미지의 `FROM` 을 **WASL 팀이 OCIR 에 제공하는 승인 BaseImage** 로 교체(래핑)한 Dockerfile 을 버전·태그별로 보관.
- `main` 에 머지되면 CI 가 **amd64 / arm64 멀티아치**로 빌드해 OCIR 에 push.
- 래핑 작업 자체는 `/baseimage-oci` 스킬로 표준화 (아래 3장).

### 허용 BaseImage

| BaseImage | OCIR 경로 | 계열 |
|---|---|---|
| navix | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos` | RHEL/centos (dnf, glibc) |
| ubuntu | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04` | debian/ubuntu (apt, glibc) |
| alpine | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23` | alpine (apk, musl) |

---

## 2. 디렉터리 규칙

래핑된 Dockerfile 은 **원본 레지스트리 경로 = OCIR repository, 마지막 디렉터리 = 태그** 규칙으로 둡니다.

```
<registry>/<org>/<image>/<tag>/Dockerfile      (+ 필요 시 벤더링 파일)
```

예시 → OCIR push 대상:

```
quay.io/argoproj/argocd/v3.2.3/Dockerfile
  → me-riyadh-1.ocir.io/axlo4g31gl45/quay.io/argoproj/argocd:v3.2.3

docker.io/library/redis/8.2.1/Dockerfile
  → me-riyadh-1.ocir.io/axlo4g31gl45/docker.io/library/redis:8.2.1
```

CI(`.github/workflows/build-and-push-image.yml`)는 `main` push 시 변경된 `**/Dockerfile` 디렉터리를
자동 감지해 멀티아치 빌드 후 OCIR 로 push 합니다.

---

## 3. CI/CD — GitHub Actions(ARC 러너) → OCIR 배포 파이프라인

[`.github/workflows/build-and-push-image.yml`](.github/workflows/build-and-push-image.yml) 가 머지된 Dockerfile 을
**자가호스트 ARC 러너**에서 아키텍처별 네이티브 빌드 후 **OCIR** 로 push 합니다. 수동 push 불필요 — **`main` 머지가 곧 배포 트리거**.

**트리거**
- `main` 에 `**/Dockerfile` 변경 push (그 커밋이 바꾼 이미지 디렉터리만 빌드)
- 수동 `workflow_dispatch` — `image_dir` 입력으로 특정 이미지 재빌드(비우면 전체)

**잡 구성 (3단계)**
1. **detect** (`arc-amd64`) — 변경된 Dockerfile 디렉터리 감지(`git diff before..sha`) → `{dir,image,tag,arch,runner}` 빌드 매트릭스 생성
2. **build** (`arc-amd64` / `arc-arm64`, dir×arch 매트릭스) — 각 아키텍처 **네이티브 러너**에서 `buildx` 빌드 → arch-suffix 태그로 push:
   `…/<image>:<tag>-amd64`, `…/<image>:<tag>-arm64` (GHA 캐시 사용, `fail-fast: false`)
3. **manifest** (`arc-amd64`) — `docker buildx imagetools create` 로 두 arch 를 묶어 **멀티아치 manifest**(원본 태그)로 push: `…/<image>:<tag>`

**대상 레지스트리** — `me-riyadh-1.ocir.io/axlo4g31gl45/<image>:<tag>` (워크플로 env `REGISTRY` / `NAMESPACE`)

**OCIR 인증** — GitHub Secrets 사용: `OCIR_USERNAME`, `OCIR_AUTH_TOKEN` (repo/org Secrets 에 OCI 서비스 계정 auth token 설정)

**동시성** — `${workflow}-${sha}` 그룹 + `cancel-in-progress: false` → 연속 머지 시 커밋별 빌드가 서로 취소되지 않고, 동일 커밋 재실행만 직렬화

> 결과: OCIR 에 **arch-suffix 2개(`-amd64`/`-arm64`) + 멀티아치 manifest(원본 태그)** 가 올라갑니다.
> ⚠️ amd64 전용 upstream(예: pinpoint)은 빌드 매트릭스를 amd64 로 제한해야 합니다(arm64 빌드 실패 방지).

### 3-1. PR 빌드 테스트 (머지 전 검증)

[`.github/workflows/pr-build-test.yml`](.github/workflows/pr-build-test.yml) 는 **`main` 으로의 PR** 에서
변경된 Dockerfile 을 **amd64 로만 빌드(push 안 함)** 해서 머지 전에 빌드 가능 여부를 검증합니다.

- **트리거** — `main` 대상 PR 에 `**/Dockerfile` 변경
- **detect → build-test** — 변경 디렉터리를 감지(`base...head`)해 **amd64 단일 arch** 로 네이티브 빌드. 빌드 실패는 대부분 arch 무관(의존성/GPG/ARG 등)이라 amd64 하나로 잡는다.
- **amd64 만 빌드하는 이유** — 머지 후 `build-and-push-image.yml` 이 어차피 amd64/arm64 둘 다 빌드한다. PR 에서까지 양쪽을 빌드하면 신규 wrap 당 full 빌드가 4회가 되어 러너 낭비 → PR 은 amd64 단일로 줄이고, **arm64 전용 실패는 머지 빌드에서 잡아 fix-forward** 한다.
- **push 안 함** — `push: false`, OCIR 인증/`packages: write` 불필요 (테스트 전용)
- **러너 볼륨 보호** — 빌드 후 `if: always()` 로 `docker buildx prune` / `docker image prune` 실행 → **빌드가 실패해도** 캐시·이미지를 정리한다
- main 의 GHA 캐시는 `cache-from`(read-only)으로만 재사용하고, 머지 전 PR 은 공유 캐시에 쓰지 않는다(`cache-to` 없음)

---

## 4. `/baseimage-oci` 스킬

래핑 워크플로(원본 Dockerfile 탐색 → 계열 매핑 → FROM 교체 → 빌드 보정 → 로컬 테스트 → OCIR push → 보안검수)를
Claude Code 스킬로 제공합니다. 이 repo 는 그 스킬의 **Claude Code 플러그인 마켓플레이스**이자 **프로젝트 스코프 스킬** 소스입니다.

스킬 본문: [`skills/baseimage-oci/SKILL.md`](skills/baseimage-oci/SKILL.md)
참고 문서: [`references/policy.md`](skills/baseimage-oci/references/policy.md) · [`references/build-troubleshooting.md`](skills/baseimage-oci/references/build-troubleshooting.md)

### 4-1. 플러그인으로 설치 (다른 환경에서 쉽게 다운로드)

Claude Code 에서:

```text
/plugin marketplace add naver-innovation/wrapped-images
/plugin install baseimage-oci@wrapped-images
```

설치 후 `/baseimage-oci <이미지명 | Dockerfile 경로 | repo URL>` 로 호출합니다.

### 4-2. 프로젝트 스코프로 사용 (이 repo 안에서 자동)

이 repo 를 클론해 Claude Code 로 열면 `.claude/skills/baseimage-oci`(→ `skills/baseimage-oci` 심볼릭)가
**프로젝트 스코프 스킬**로 자동 인식됩니다. 별도 설치 없이 `/baseimage-oci` 사용 가능.

### 4-3. 사용 예

```text
/baseimage-oci apache/kafka:4.0.0
/baseimage-oci docker.io/library/redis:8.2.1
/baseimage-oci https://github.com/argoproj/argo-cd      # repo URL
/baseimage-oci ./quay.io/argoproj/argocd/v3.2.3/Dockerfile   # 로컬 Dockerfile
```

스킬이 하는 일:
1. **판정** — 이미 OCIR 이미지면 skip, 외부 이미지면 래핑 진행
2. **원본 Dockerfile 확보** + **계열 판별 → 승인 base 선택**
3. **FROM 교체 + 보정** (USER root, idempotent 명령, 주입 ARG, GPG 실서명자 등 필수 원칙 적용)
4. (선택, 사용자 확인 후) **로컬 빌드·실행 스모크 테스트** → 끝나면 이미지 자동 정리
5. **OCIR push** + **보안검수** 체크리스트
6. 공개 Dockerfile 이 없으면 → **공개 대체 이미지** 래핑(사용자 확인) → 그래도 안되면 **예외 whitelist** 안내

### 4-4. 핵심 원칙 (요약)

- `baseimage/*` 는 clean base 가 아니다 → 기본 USER 비루트(`USER root` 필요), 선존재 파일/uid·gid 주의(`ln -sf`/`mkdir -p`/충돌 처리)
- 원본 multi-stage 구조 보존 — 빌드 전용 stage 는 원본 pinned base 유지, **출하 런타임 stage 의 FROM 만** 교체
- 빌드시스템 주입 ARG 명시, 의존 설치 누락 금지, GPG 는 벤더 HTTPS 키 + 실제 서명자
- navix 는 신형 RHEL(el10/OpenSSL3/Python3.12) — el8/el9 RPM ABI 불일치 주의
- 무거운 소스 빌드(maven/yarn)는 빌더 VM ≥16–24GB, 한 번에 하나씩

---

## 5. 새 이미지 래핑 기여 흐름

1. `origin/main` 에서 브랜치 생성 (`feat/wrap-<image>-<tag>`)
2. `/baseimage-oci <이미지>` 로 Dockerfile 작성 (+ 필요 시 로컬 빌드 테스트)
3. `<registry>/<org>/<image>/<tag>/Dockerfile` 경로에 커밋
4. **shared compartment 에 OCIR repository 직접 생성** — 머지 시 CI 가 push 할 대상 repository(= tag 를 뺀 `<registry>/<org>/<image>` 경로)를 미리 만들어 둔다. shared compartment 는 push 시 자동 생성이 안 되므로, 없으면 머지 빌드의 push 가 실패한다.
   - 예: `docker.io/curlimages/curl/8.11.0/Dockerfile` → OCIR repository `docker.io/curlimages/curl` 를 생성
5. PR 생성 → **CI 빌드 테스트(`pr-build-test`)** 통과 + 리뷰 → `main` 머지 → CI 가 OCIR push
6. **클라우드 이미지 보안검수**(Critical CVE 없음) 통과 후 배포

---

## 6. 라이선스 / 출처

각 래핑 Dockerfile 은 원본 프로젝트의 라이선스를 따르며, Dockerfile 헤더 주석에 원본 출처·태그·계열 매핑 근거를 명시합니다.
