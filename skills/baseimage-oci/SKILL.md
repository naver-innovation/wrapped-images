---
name: baseimage-oci
description: "외부 오픈소스 이미지(Docker Hub 등)를 OCI 이미지 보안 정책에 따라 허용된 BaseImage(navix/ubuntu/alpine — 원본 계열에 맞춰 선택)로 교체(래핑)하는 워크플로. 원본 Dockerfile 탐색 → 계열 매핑으로 base 선택 → FROM 교체 → 필요 시 계열 차이(apt→dnf 등) 보정 → 빌드 → OCIR push → 보안검수 안내. 공개 Dockerfile 이 없는 이미지(bitnami 등)는 같은 소프트웨어의 공개 대체 이미지(apache/공식 라이브러리 등) base 를 사용자 확인 후 교체. 그래도 없으면 예외 whitelist 안내. Use when: 사용자가 외부/오픈소스 도커 이미지(예: airflow, kafbat, nginx)를 OCI(KSA) 환경에서 쓰려 할 때, Dockerfile 의 FROM 이 외부 이미지일 때, 이미지 보안 정책/래핑/예외 whitelist 를 물을 때. Trigger keywords: baseimage, base image, navix, 외부 이미지, 오픈소스 이미지, 이미지 보안, 래핑, wrapping, docker hub, dockerfile from, 이미지 교체, whitelist, 이미지 검수, ocir push, alpine, ubuntu"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
argument-hint: <외부 이미지명 | Dockerfile 경로 | GitHub repo URL>
metadata:
  version: 0.2.0
  author: taes.kim@navercorp.com
  tags: [wasl, oci, baseimage, navix, ocir, security, korean]
---

# /baseimage-oci — 외부 이미지 → 허용 BaseImage(navix/ubuntu/alpine) 교체

OCI(KSA) 환경의 **외부 오픈소스 이미지 보안 정책**을 코드 레벨로 실행하는 스킬.
정책 핵심: **외부 이미지는 직접 사용 금지. 허용된 BaseImage 로 래핑 → OCIR push → 보안검수** 순서로만 사용한다.

정책 원문: [12.2.2 외부 오픈소스 이미지 보안 정책](https://wiki.navercorp.com/spaces/KSAAPP/pages/5390619759)
정책 발췌·검수 기준: [references/policy.md](references/policy.md)

## 허용 BaseImage (래핑 대상)

WASL 팀이 OCIR 에 제공하는 base image 3종. 원본 이미지와 **같은 계열**을 선택하면 패키지 보정 없이 FROM 교체만으로 끝나는 경우가 대부분이다.

| BaseImage | 경로 | 계열 |
|---|---|---|
| navix | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos` | RHEL/centos (dnf) |
| ubuntu | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04` | debian/ubuntu (apt) |
| alpine | `me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23` | alpine (apk, musl) |

> 위 태그가 현재 표준 제공 태그다 (alpine 3.23 / ubuntu 24.04 / navix 10.1). **alpine/ubuntu 는 OCIR push 진행 중** — pull 실패 시 push 완료 여부를 먼저 확인한다. 신규 태그 제공 여부는 `oci artifacts container image list --repository-name baseimage/<name>` 또는 OCI 콘솔에서 확인. naver 사내 BaseImage (`reg.navercorp.com/base/...`) 는 **비권장** — 사내 보안검수 허들 추가 + 사내 개발환경 정보 포함 가능성 (반출 검수 challenge 대상).

> ⚠️ **`baseimage/*` 는 vanilla(clean) alpine/ubuntu 가 아니다.** userland·라이브러리가 이미 들어 있고(예: `baseimage/alpine` 에 busybox + **libcurl** 등), **기본 USER 가 비루트**다. 이 때문에 동일 계열 FROM 교체만 해도 빌드가 깨질 수 있다 → 아래 [필수 원칙](#필수-원칙--한-번에-통과시키기) 을 반드시 적용.

### 계열 매핑 (원본 → 교체 base)

| 원본 이미지 계열 | 교체 base | 비고 |
|---|---|---|
| alpine | `baseimage/alpine` | musl libc — glibc 계열(navix/ubuntu)로 교체 시 비용 큼, 반드시 alpine 사용 |
| debian / ubuntu | `baseimage/ubuntu` | apt 계열 그대로 — 보정 최소 |
| rhel / centos / rocky / alma / fedora / amazonlinux | `baseimage/navix` | dnf 계열 |
| busybox | `baseimage/alpine` | 가장 근접한 계열 |
| distroless / scratch (정적 바이너리) | 아무 base 가능 (navix 권장) | 바이너리 COPY 만 필요 |
| 판별 불가 / 기타 | `baseimage/navix` 시도 | 실패 시 Step D(대체 이미지) → 예외 whitelist |

계열이 **다른** base 로 교체해야 하는 경우(예: 매핑상 navix 통일이 필요하거나 동일 계열 base 태그가 없는 경우)에만 패키지 매니저·패키지명 보정이 필요하다 → [references/build-troubleshooting.md](references/build-troubleshooting.md)

## 입력

`$ARGUMENTS` 로 다음 중 하나를 받는다:

- 외부 이미지명 (예: `apache/airflow:2.10.3`, `kafbat/kafka-ui:latest`)
- 로컬 Dockerfile 경로 (또는 Dockerfile 이 있는 프로젝트 디렉토리)
- 외부 이미지의 GitHub repo URL

인자가 없으면 사용자에게 위 셋 중 무엇인지 물어본다.

## 필수 원칙 — 한 번에 통과시키기

> **빌드는 보통 로컬이 아니라 merge 후 CI 에서 수행된다.** 로컬 `docker build` 로 미리 검증하지 못하는 경우가 많으므로 **Dockerfile 은 처음부터 맞아야 한다.** 아래는 재수정 루프를 막기 위한 핵심 원칙이다 (실제 재수정 사례에서 도출). 단, **로컬에 docker + OCIR 인증이 있으면 [Step 4.5](#step-45--로컬-빌드실행-테스트-선택--사용자-확인-후) 로 미리 빌드·실행을 검증**할 수 있다(권장 — 재수정 루프를 가장 확실히 줄인다).

1. **`baseimage/*` 는 clean·minimal base 가 아니다.** userland·라이브러리가 이미 들어 있다 (`baseimage/alpine` 은 busybox + libcurl 등, `baseimage/ubuntu` 도 기본 패키지 포함). 따라서:
   - 파일/디렉토리/심볼릭 링크/유저가 **이미 존재할 수 있다** → 생성·링크 명령은 **idempotent** 하게: `ln -sf`, `mkdir -p`, `adduser ... 2>/dev/null || true`.
   - 원본이 clean alpine/scratch 를 가정해 쓴 `ln -s`, `mkdir` 를 그대로 옮기면 `File exists` 로 실패한다.
   - **고정 uid/gid 가 base 에 이미 선점돼 있을 수 있다**: `baseimage/ubuntu:24.04` 는 **uid/gid 1000=`ubuntu` 유저**, `baseimage/navix` 는 **999** 등. `useradd --uid 1000` 가 실패하고 `|| true` 로 삼켜지면 정작 유저가 안 만들어져 **다음 `chown` 이 깨진다.** → 충돌 계정을 먼저 제거(`userdel -r ubuntu || true`)하고 원하는 uid 로 만들거나, 고정 id 를 포기하고 폴백(`useradd --uid N ... || useradd ...`). 생성 후 유저 존재를 보장하고 chown.
   - 단순히 `... || true` 로 덮지 말 것 — 실패가 **뒤 단계에서** 터진다. (로컬 빌드 테스트로 zookeeper/mysql 에서 실제로 잡힌 사례.)
2. **기본 USER 가 비루트다** (`baseimage/alpine`·`ubuntu` 모두). 패키지 설치·빌드·시스템 파일 수정 단계 **앞에 `USER root`**, 런타임 stage 끝에서 원본의 비루트 USER 로 복귀.
3. **원본 multi-stage 구조를 충실히 보존한다 — 스테이지를 합치지(collapse) 마라.**
   - 빌드 전용(throwaway) 스테이지는 **원본 pinned base(golang/node 등)를 그대로 유지**해도 된다. 정책 대상은 *출하되는* 런타임 stage 뿐이다.
   - 각 언어 빌더는 **그 언어 전용 base** 를 써라(JS→`node:*`, Go→`golang:*`). 빌더 base 를 임의 계열로 바꾸거나 패키지 매니저를 바꾸면(yarn berry↔classic 등) 툴체인이 깨진다.
4. **빌드 시스템이 주입하던 ARG/옵션을 명시하라.** 원본이 외부 빌드 시스템에서 `--build-arg` 로 받던 값(예: curl `CURL_CONFIGURE_OPTION`, grafana `BASE_IMAGE`)은 CI 가 옵션 없이 빌드하면 **빈 값**이 되어 실패한다 → Dockerfile 에 **구체 기본값을 ARG 로 박아라.**
5. **의존 설치 단계를 빼먹지 마라.** 프론트엔드 빌드 전 `yarn install`/`npm ci`, 소스 빌드 전 `-dev` 헤더·`go mod download` 등.
6. **소스 빌드는 태그로 핀**하고, `./configure` 류는 **기능 플래그를 명시**(예: curl 7.85+ 는 TLS 백엔드 `--with-openssl` 미지정 시 실패).
7. **final stage 의 `COPY --from=` 출처 경로가 실제로 존재하는지** 빌더 산출물 기준으로 확인.
8. **빌드 타임 외부 네트워크는 HTTPS(443) 로, GPG 키는 "실제 서명자"를 받아라.**
   - `hkp://...`(포트 11371)·`hkp://...:80` 키서버는 빌드 네트워크에서 자주 차단되어 `keyserver receive failed` 로 깨진다 → **벤더가 HTTPS 로 배포하는 키 파일**을 우선 import (`wget -O- https://<vendor>/<key>.key | gpg --batch --import`). 키서버가 꼭 필요하면 HTTPS 웹 조회(`https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x<KEYID>`).
   - **원본 Dockerfile 이 명시한 keyid 를 맹신하지 마라.** 그 키가 폐기(revoked)됐거나, 벤더가 키를 로테이션·재서명해 **아티팩트의 실제 서명자가 다른 키**일 수 있다 (예: telegraf 1.25.0 `.deb.asc` 실제 서명자는 `influxdata-archive_compat.key`, 원본이 받던 `05CE…` 구키 아님). 의심되면 `gpg --list-packets <file>.asc | grep issuer` 로 실제 서명자를 확인하거나, 벤더 HTTPS 키를 import 후 `gpg --verify` 가 통과하는 키를 쓰고 fingerprint 로 핀한다.
   - 서명 검증(`gpg --verify`)은 그대로 유지. 패키지·바이너리 다운로드도 HTTPS 우선.

> **안전 기본기**: 원본 Dockerfile 을 **스테이지·명령·base 태그까지 그대로 옮기되**, (a) *출하* stage 의 `FROM` 만 승인 base 로 교체, (b) 위 idempotent/`USER root`/ARG 보정만 추가하는 방식이 한 번에 통과할 확률이 가장 높다. 증상별 대응표: [references/build-troubleshooting.md](references/build-troubleshooting.md)

## 워크플로

### Step 0 — 사전 분기 (idempotent / 정책 예외)

대상 이미지(또는 Dockerfile FROM)를 보고 먼저 분기:

| 상태 | 처리 |
|---|---|
| 이미 `*.ocir.io/...` 이미지 | **이미 정책 준수 — skip** 출력 후 종료 |
| `reg.navercorp.com/base/...` (naver 사내 base) | 동작은 하지만 비권장 사유 안내 후 navix 전환 diff 제안 |
| 사내 n3r 레지스트리 이미지 (`*.navercorp.com`) | 이 스킬 범위 외 — WASL-IMAGE-Copier 로 OCIR 복제 (cross-ref: apply-oci-ocir). **WASL-IMAGE-Copier 는 사내 n3r 이미지 전용**이며 순수 외부 이미지는 n3r 을 경유하지 않는다 |
| 외부 이미지 (Docker Hub, ghcr, quay 등) | Step 1 진행 |

### Step 1 — 원본 Dockerfile 확보

1. 로컬 Dockerfile 이 주어졌으면 그대로 사용.
2. 이미지명/repo URL 만 주어졌으면 원본 Dockerfile 탐색:
   - 공식 GitHub repo 검색: `<이미지명> github`, `<이미지명> Dockerfile`
   - Docker Hub 페이지의 source repo 링크 확인
   - **태그를 정확히 핀**해서 그 태그의 Dockerfile·소스를 확보 (raw.githubusercontent.com/<repo>/<tag>/Dockerfile 등). 빌드 컨텍스트로 repo 가 필요하면 빌더에서 `git clone --branch <tag>` 한다.
3. **공식 Dockerfile 을 찾을 수 없으면** (대표적으로 `bitnami/*` 처럼 비공개 빌드 파이프라인 + prebuilt tarball 기반이라 FROM 교체로 재현 불가) → **Step D (공개 대체 이미지 base 교체)** 로 진행.
   - ⚠️ **소스 재구성(reconstruction)을 강행하지 마라.** 이미지가 **Paketo/Cloud Native Buildpacks 로 빌드된 경우**(Spring Boot `build-image`, `pack` 등 — Dockerfile 자체가 없음), 또는 공개 대체 이미지조차 없어 **빌드를 소스에서 직접 재구성해야만 하는 경우**, 그건 "충실한 래핑"이 아니다. 재구성 이미지는 enforcer/필수 ENV/툴체인 차이로 빌드가 깨지기 쉽고 원본과 동작이 달라진다. → 이 경우 **곧장 Step E(예외 whitelist) 를 추천**한다. (실제 사례: pinpoint-collector/web 은 Paketo 빌드팩 이미지라 Dockerfile 이 없어 소스 재구성했으나 `maven-enforcer` 필수 env 로 빌드 실패 → 예외 트랙 전환.)

### Step 2 — 계열 판별 + 교체 base 선택

1. 원본 `FROM` 의 base 계열을 판별한다 (이미지명·태그·`/etc/os-release` 기준).
2. **계열 매핑 표**에 따라 교체 base 를 선택한다 (alpine→alpine, debian/ubuntu→ubuntu, RHEL 파생→navix).
3. 선택한 base 의 제공 태그를 OCIR 에서 확인한다.
4. **같은 계열로 교체하는 경우**: 패키지 매니저 보정 불필요 — 단, [필수 원칙](#필수-원칙--한-번에-통과시키기)(비루트 USER, idempotent 명령, 선존재 라이브러리) 은 동일 계열에도 적용된다.
5. **계열을 건너 교체하는 경우** (navix 통일 필요 등): 차이를 목록화 — 패키지 매니저(`apt`/`apk`→`dnf`), 패키지명, 경로/사용자. 상세: [references/build-troubleshooting.md](references/build-troubleshooting.md)
6. 어느 경우든 base 의 기본 USER·홈 디렉토리·쉘은 단정하지 말고 `docker run --rm <base> id` / `docker inspect` 로 확인 후 반영한다. (확인 불가 시 비루트 가정 + `USER root` 보정.)

### Step 3 — FROM 교체 + Dockerfile 수정

**단일 스테이지 (동일 계열 — 보정 최소):**

```dockerfile
# 원본: FROM debian:bookworm-slim   → debian 계열이므로 baseimage/ubuntu 선택
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
USER root                                  # baseimage 기본 USER 가 비루트 → 설치 단계 위해 root
# 이하 원본 Dockerfile 의 빌드 단계 유지 (생성 명령은 mkdir -p / ln -sf 로 idempotent)
```

```dockerfile
# 원본: FROM alpine:3.21   → baseimage/alpine 선택 (musl 계열 유지)
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
```

**계열 전환 (RHEL 파생 → navix, 또는 동일 계열 base 사용 불가 시):**

```dockerfile
# 원본: FROM rockylinux:9
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos
# dnf 계열 유지 — 패키지명 차이만 확인
```

**Multi-stage build (스테이지 합치지 말 것):** 각 `FROM` 스테이지를 **독립적으로** 다룬다.
- **출하되는 런타임 stage** 의 `FROM` 만 계열 매핑 표에 따라 승인 base 로 교체한다.
- **빌드 전용(throwaway) stage** 는 원본의 pinned base(golang/node 등)를 **그대로 유지**해도 된다 (출하 레이어가 아니므로 정책 대상 아님). 언어 전용 base 와 패키지 매니저를 바꾸지 마라.
- 스테이지 이름(`AS builder` 등)과 `COPY --from=<stage>` 관계는 **그대로 유지**한다. 대개 **단일 Dockerfile 로 끝나며 중간 이미지 OCIR push 는 불필요**하다:

```dockerfile
# 빌드 전용 stage: 원본 FROM node:24-alpine 그대로 유지 (프론트엔드 빌드 — 출하 안 됨)
FROM node:24-alpine AS js-builder
WORKDIR /app
COPY . .
RUN yarn install --immutable && yarn build   # 의존 설치(install) 를 build 앞에 반드시

# 빌드 전용 stage: 원본 FROM golang:1.25-alpine 그대로 유지
FROM golang:1.25-alpine AS go-builder
WORKDIR /app
COPY . .
RUN go mod download && make build-go

# 런타임 stage(출하): 원본 FROM alpine → 계열 매핑(baseimage/alpine)으로 교체
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root                                              # 비루트 기본 → root 전환
COPY --from=go-builder /app/bin/ /usr/local/bin/       # COPY --from 관계 그대로 유지
COPY --from=js-builder /app/public ./public
RUN mkdir -p /var/lib/app && ln -sf /usr/local/bin/app /usr/bin/app   # idempotent
USER 65534                                             # 원본 런타임 비루트 USER 복귀
CMD ["app"]
```

> **중간 이미지를 따로 빌드·OCIR push 해야 하는 예외**: 어떤 스테이지의 base 가 그 자체로 Dockerfile 이 없는 불투명한 prebuilt 외부 이미지일 때만 해당한다 (예: `FROM apache/airflow AS base`). 이 경우 그 prebuilt 이미지를 먼저 계열 매핑 base 로 래핑해 OCIR 에 push(`<APP_NS>/<원본이미지명>-base:<원본태그>` 권장)한 뒤, 해당 스테이지의 `FROM` 만 그 이미지로 교체한다. 나머지 스테이지·`COPY --from=` 구조는 그대로 둔다.

수정 결과는 **원본 대비 unified diff** 로 먼저 보여주고 사용자 확인 후 파일에 반영한다.

### Step 4 — 빌드 및 에러 해결

```bash
docker build -t <로컬태그> .
```

빌드 에러 발생 시 [references/build-troubleshooting.md](references/build-troubleshooting.md) 를 먼저 적용한다. 특히 **동일 계열에서도 자주 터지는 케이스**(`ln: File exists` → `ln -sf`, 비루트 USER → `USER root`, 주입 ARG 누락, `yarn install` 누락, configure TLS 백엔드 미선택 등)를 우선 확인한다.
**보정을 시도해도 빌드가 불가능하면** → Step D(공개 대체 이미지) → 그래도 불가하면 Step E(예외 whitelist).

### Step 4.5 — 로컬 빌드·실행 테스트 (선택 — 사용자 확인 후)

CI(merge 후) 빌드에만 의존하지 않고 **로컬에서 미리 빌드·실행을 검증**하면 재수정 루프를 크게 줄인다. Dockerfile 작성/수정 직후 **반드시 사용자에게 "로컬 빌드 테스트를 진행할까요?"를 묻고, 동의한 경우에만** 아래를 수행한다 (사용자가 원치 않으면 건너뛰고 Step 5 로).

**0) 사전 점검 — 테스트 가능 여부**

```bash
docker version --format '{{.Server.Os}}/{{.Server.Arch}}'   # 데몬 동작 + 호스트 아키텍처
docker manifest inspect me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/<name>:<tag> >/dev/null 2>&1 \
  && echo "base pull 가능" || echo "base 미인증 → docker login me-riyadh-1.ocir.io 필요"
```

- docker 데몬 미동작 / baseimage pull 불가(미인증)면 로컬 테스트 불가 → 사용자에게 알리고 (인증 안내 후) Step 5 로 진행.

**1) 빌드**

```bash
docker build -t <local-tag> <Dockerfile-dir>
```

- 무거운 빌드(grafana/pinot/clickhouse 등)는 오래 걸린다 → 백그라운드 실행 권장.
- **소스 빌드(maven/yarn/make)는 빌더 VM 메모리를 크게 먹는다 → ≥16–24GB 할당.** 예: grafana 는 `NODE_OPTIONS=--max_old_space_size=8000`(node 힙 8GB), pinot 는 maven 힙. 메모리 부족 시 빌드가 깨지는 게 아니라 **도커 데몬(colima)이 OOM 으로 죽는다.** (colima 기본은 2GB 라 반드시 상향: `colima start --cpu 10 --memory 24`.)
- **무거운 이미지는 한 번에 하나씩 빌드한다.** 한 빌드의 OOM 이 데몬을 죽이면, 같은 배치의 **무관한 후속 빌드가 `Cannot connect to the Docker daemon` 으로 거짓 FAIL** 처리된다 → 데몬 상태부터 확인(`docker info`)하고 그 항목들만 재실행.
- 실패 시 [references/build-troubleshooting.md](references/build-troubleshooting.md) 적용 후 재시도. (이 단계가 Step 4 의 로컬 실현이다.)

**2) 실행(스모크) 테스트 — 아키텍처가 맞을 때만**

호스트 아키텍처(0단계에서 확인)와 이미지 타깃이 **같으면** 네이티브로 실행해 정상 동작을 확인한다. **다르면**(예: amd64 전용 이미지를 arm64 호스트에서) QEMU 에뮬레이션(`--platform linux/amd64`)이 필요 — 느리고 일부 런타임은 실패할 수 있으니, 에뮬 테스트 강행/생략을 **사용자와 합의**한다.

| 이미지 유형 | 스모크 명령 예 |
|---|---|
| CLI 도구 (kubectl, curl, busybox) | `docker run --rm <local-tag> version` 또는 `--version` |
| 서버 (grafana, kafka, clickhouse, nexus, redis, mysql) | 백그라운드 기동 → 로그/포트 헬스 확인 → 정리: `docker run -d --name smoke <local-tag>` → `docker logs smoke` (정상 기동 로그 확인) → `docker rm -f smoke` |
| JRE/라이브러리 앱 | 엔트리포인트 help/version: `docker run --rm <local-tag> --version` (또는 `--help`) |

- 서버류는 필수 ENV(예: `MYSQL_ROOT_PASSWORD`, `ALLOW_ANONYMOUS_LOGIN`)가 없으면 기동이 의도적으로 멈출 수 있다 → 최소 ENV 를 주거나 "설정 미비로 인한 정상 종료"인지 로그로 판별한다.

**3) 결과 보고**: 빌드 성공/실패 + 스모크 통과/실패(또는 아키텍처 불일치로 생략)를 명시한다. 모두 통과하면 Step 6 체크리스트의 "빌드 성공 + 컨테이너 기동 스모크" 항목을 충족한 것으로 표시한다.

**4) 정리(cleanup) — 테스트 끝나면 반드시 로컬 이미지·캐시 제거 (디스크 잠식 방지)**

로컬 테스트 이미지·중간 레이어는 빠르게 쌓여 디스크를 잠식하고(무거운 빌드일수록 심함) 데몬 OOM·디스크 풀의 원인이 된다. 각 이미지의 빌드+스모크가 끝나는 **즉시** 정리한다:

```bash
docker rm -f <smoke-container> 2>/dev/null || true   # 스모크 컨테이너 제거(서버류)
docker rmi -f <local-tag>                             # 방금 테스트한 이미지 제거
docker image prune -f                                 # dangling 중간 레이어 회수
docker builder prune -f                               # 빌드 캐시 회수(무거운 빌드 후 권장)
```

- 여러 이미지를 일괄 테스트할 때는 **공통 태그 접두사**(예: `localtest/`)를 써서 한 번에: `docker images 'localtest/*' -q | xargs -r docker rmi -f`. 배치 스크립트라면 각 이미지 루프 끝에 `docker rmi`/스모크 컨테이너 정리를 넣어 **쌓이지 않게** 한다.
- pull 한 base(`baseimage/*`)는 재빌드 시 다시 받아야 하므로 보통 유지(선택). 디스크가 빠듯하면 `docker system df` 로 확인 후 `docker system prune -f`.

> 로컬 테스트는 **보조 검증**이다. 통과 여부와 무관하게 OCIR push·보안검수(Step 5~6)와 CI 멀티아치 빌드는 그대로 진행한다. 로컬에서 못 도는 아키텍처(에뮬 실패 등)는 CI 네이티브 러너에서 최종 확인한다.

### Step 5 — OCIR push

```bash
# OCIR 로그인 (OCI 서비스 계정 auth token 사용)
# auth token 은 명령행 인자로 넘기지 말 것 — 셸 히스토리/로그에 남는다. --password-stdin 사용 권장.
docker login me-riyadh-1.ocir.io -u '<TENANCY_NAMESPACE>/<USER>' --password-stdin

docker tag <로컬태그> me-riyadh-1.ocir.io/<TENANCY_NAMESPACE>/<APP_NS>/<IMAGE>:<TAG>
docker push me-riyadh-1.ocir.io/<TENANCY_NAMESPACE>/<APP_NS>/<IMAGE>:<TAG>
```

- OCIR repository 는 첫 push 시 자동 생성 (또는 `oci artifacts container repository create`)
- 순수 외부 이미지는 **n3r 을 경유하지 않고 OCIR 에 직접 push** 한다
- auth token 발급·계정: ask-oci 의 [container-registry.md](../../../ask-oci/skills/ask-oci/references/known-answers/container-registry.md) 참고

### Step 6 — 보안검수 및 마무리 체크리스트

- [ ] FROM 이 허용 BaseImage(navix/ubuntu/alpine)로 교체됨 (또는 예외 whitelist 승인 완료)
- [ ] 빌드 성공 + 컨테이너 기동 스모크 확인 (`docker run --rm <이미지> <헬스체크>`)
- [ ] OCIR push 완료
- [ ] **클라우드 이미지 보안 검수** 진행 (검수 통과 후 배포 가능)
- [ ] Critical CVE 없음 확인

### Step D — 공개 Dockerfile 부재 시: 공개 대체 이미지 base 교체 (사용자 확인 필수)

원본 이미지가 **공개 Dockerfile 이 없는** 경우(대표적으로 `bitnami/*`, `bitnamilegacy/*` — 비공개 빌드 시스템 + `downloads.bitnami.com` prebuilt tarball 기반이라 FROM 교체로 재현 불가), 곧장 whitelist 로 가기 전에 **같은 소프트웨어의 다른 공개 이미지**를 찾아 그 Dockerfile 을 래핑한다.

1. **같은 소프트웨어의 공개 Dockerfile 이 있는 대체 이미지**를 찾는다. 우선순위:
   - 프로젝트 공식 이미지 (예: `bitnami/kafka` → `apache/kafka`, `bitnami/zookeeper` → `apache/zookeeper`)
   - Docker 공식 라이브러리 이미지 (예: `bitnami/mysql` → `mysql`, `bitnami/redis` → `redis`, `bitnami/postgresql` → `postgres`)
   - 벤더의 공개 OSS Dockerfile
2. **반드시 사용자에게 확인받는다.** base 만 바뀌는 게 아니라 **이미지 출처·기본 설정·환경변수·디렉토리 레이아웃이 원본(bitnami)과 다를 수 있다**(bitnami 는 비루트 UID·`/opt/bitnami` 경로·자체 설정 규약을 씀). 대체 이미지 후보와 함께 "원본과의 차이(설정/경로/유저/포트)"를 제시하고 진행 여부를 묻는다.
3. 승인되면 그 **공개 대체 이미지의 Dockerfile** 을 Step 1~6 워크플로로 래핑한다. OCIR 경로/태그를 원본 기준으로 둘지(호환성), 대체 이미지 기준으로 둘지 사용자와 합의한다.
4. **공개 대체 이미지조차 정말 없으면** → 래핑이 **불가능함을 명확히 알리고** Step E(예외 whitelist) 로 진행한다.

| 원본(비공개) | 공개 대체 후보 | 주의 |
|---|---|---|
| `bitnami/kafka` | `apache/kafka` | 설정 env·경로 상이 |
| `bitnami/zookeeper` | `apache/zookeeper` (또는 공식) | 〃 |
| `bitnami/mysql` | `mysql` (공식 라이브러리) | 데이터 경로·env 상이 |
| `bitnami/redis` | `redis` (공식) | 〃 |
| `bitnami/kubectl` | kubectl 단일 바이너리 — 승인 base 에 직접 다운로드 | 버전 핀 필요 |

### Step E — 예외 whitelist (모든 래핑 경로 불가 시)

**Step D(공개 대체 이미지)까지 시도한 뒤에도 불가능할 때만** 예외 whitelist 를 요청한다:

- 원본도 공개 대체 이미지도 **공개 Dockerfile 이 전혀 없는** 경우 (Paketo/buildpack 이미지 등 — 소스 재구성은 충실 래핑이 아니므로 강행 금지)
- 비공개 prebuilt base 에 의존해 합성해야 하고 그 합성이 빌드 불가한 경우 (예: confluent `cp-base-new`)
- 계열에 맞는 허용 base 로 교체 후에도 빌드가 불가능한 경우 (의존성 해결 불가)

| 단계 | 항목 | 기준 |
|---|---|---|
| 1차 검수 | 취약성 체크 | Critical CVE 없어야 함 |
| 1차 검수 | 바이러스 탐지 체크 | 바이러스 의심 없어야 함 |
| 2차 승인 | 보안책임자 승인 | KSA 보안책임자 승인 |

**예외 승인을 받았더라도 외부 저장소에서 직접 pull 은 금지** — 반드시 OCIR 로 복제 후 사용한다.

## 허용/차단 요약

| 구분 | 케이스 |
|---|---|
| ✅ 허용 | 허용 BaseImage(navix/ubuntu/alpine) 래핑 후 OCIR push + 검수 통과 / 공개 대체 이미지 래핑(사용자 승인) / 예외 whitelist 승인 이미지 / 보안검수 후 반출된 naver base 기반 래핑 이미지 |
| 🚫 차단 | 외부 저장소 직접 pull·배포 / 검수 미통과 이미지 / Critical CVE 보유 이미지 |

## 출력 형식

1. **판정**: 대상 이미지의 분기 결과 (정책 준수 / 래핑 필요 / 대체 이미지 트랙 / 예외 트랙)
2. **Dockerfile diff**: 원본 대비 변경점 (unified diff) — [필수 원칙](#필수-원칙--한-번에-통과시키기) 반영 여부 명시
3. **실행 명령**: build / tag / push 명령 시퀀스
4. **로컬 테스트 결과**: (사용자 동의 후 수행한 경우) 빌드 성공/실패 + 스모크 통과/생략(아키텍처 불일치) — Step 4.5
5. **체크리스트**: Step 6 항목
6. **다음 단계**: 보안검수 또는 (대체 이미지 확인 / 예외 whitelist) 요청 안내

## 관련 자료 (cross-reference)

- 정책 발췌·검수 기준: [references/policy.md](references/policy.md)
- 계열 전환·빌드 에러·동일 계열 함정: [references/build-troubleshooting.md](references/build-troubleshooting.md)
- OCIR 이관(레지스트리 전환) plan: apply-oci 플러그인의 `apply-oci-ocir` sub-skill
- Container Registry / WASL-IMAGE-Copier: ask-oci 의 [container-registry.md](../../../ask-oci/skills/ask-oci/references/known-answers/container-registry.md)
