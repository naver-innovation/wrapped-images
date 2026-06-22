# 계열 전환 빌드 가이드 — 패키지 보정 + 알려진 에러

**동일 계열로 교체하는 경우 이 문서는 대부분 불필요하다** (alpine→`baseimage/alpine`, debian/ubuntu→`baseimage/ubuntu`, RHEL 파생→`baseimage/navix` — FROM 교체만으로 빌드되는 경우가 많음).

아래 보정은 **계열을 건너 교체**할 때 적용한다 (예: debian 계열 원본을 navix 로 통일하는 경우, 동일 계열 base 태그가 없는 경우).

> **musl 주의**: alpine 원본을 glibc 계열(navix/ubuntu)로 옮기는 것은 패키지 보정만으로 해결되지 않는다 (musl↔glibc 바이너리 비호환). alpine 원본은 반드시 `baseimage/alpine` 을 사용한다.

## 동일 계열 래핑에서도 자주 터지는 케이스 (재수정 루프 방지)

`baseimage/*` 는 vanilla alpine/ubuntu 가 아니라 **userland·라이브러리가 이미 든** 이미지다. 동일 계열 FROM 교체만 해도 아래가 터진다. 빌드를 로컬에서 못 돌려보는 경우가 많으니 **처음부터** 반영한다.

| 증상 (빌드 로그) | 원인 | 해결 |
|---|---|---|
| `ln: <path>: File exists` | baseimage 에 해당 파일/링크가 이미 존재 (예: `baseimage/alpine` 의 libcurl → `/usr/lib/libcurl.so.4`) | `ln -s` → **`ln -sf`** |
| `mkdir: can't create '/lib64': File exists` | 디렉토리 선존재 | `mkdir` → **`mkdir -p`** |
| `adduser: user '...' in use` / `addgroup: group '...' in use` | 동일 이름 UID/그룹 선존재 | 존재 검사 후 생성 또는 `... 2>/dev/null \|\| true` |
| `useradd: UID N is not unique` / `groupadd: GID N already in use` (exit 4) / 또는 이후 `chown <user>` 가 깨짐 | **baseimage 가 그 고정 uid/gid 를 이미 다른 계정에 선점** — `baseimage/ubuntu:24.04` 는 **uid/gid 1000 = `ubuntu` 유저**, `baseimage/navix` 는 **gid/uid 999** 등. `useradd --uid N` 가 실패하고 `\|\| true` 로 삼켜지면 정작 유저가 안 만들어져 다음 `chown` 이 깨진다 | (a) 충돌 계정을 먼저 제거해 id 를 비운다: `userdel -r ubuntu 2>/dev/null \|\| true; groupdel ubuntu 2>/dev/null \|\| true` 후 원하는 uid 로 생성, **또는** (b) 고정 id 를 포기하고 폴백: `groupadd --gid N x 2>/dev/null \|\| groupadd x` + `useradd --uid N --gid x 2>/dev/null \|\| useradd --gid x`. 어느 쪽이든 **생성 후 유저가 실제 존재하는지 보장**하고 chown 한다 |
| `tar: can't change directory to '/opt/...'` | `mkdir -p opt/foo`(상대경로)로 만들고 `tar -C /opt/foo`(절대경로)로 쓰는 불일치 | 생성·참조 경로를 **절대경로로 일치**시킨다 (`mkdir -p /opt/foo`) |
| `/usr/bin/rm: cannot execute: required file not found` 등 base 명령이 깨짐 | tgz/아카이브를 `tar -C /` 로 풀어 **base 의 시스템 라이브러리/바이너리를 덮어씀** (alpine 전용 패턴을 glibc base 에 그대로 이식) | 아카이브를 `/` 가 아닌 전용 경로(예: `/opt/<app>`)로 풀거나, 그 이미지에 맞는 공식 Dockerfile 패턴(예: clickhouse 의 `Dockerfile.ubuntu`)을 따른다 |
| `Permission denied` / apk·apt·파일쓰기 실패 | baseimage 기본 USER 가 **비루트** | 설치·시스템수정 단계 앞 **`USER root`**, 런타임 끝에 원본 비루트 USER 복귀 |
| `configure: ... select one of --with-openssl ...` (curl 7.85+ 등) | 외부 빌드시스템이 주던 ARG(예 `CURL_CONFIGURE_OPTION`) 미주입 → 기능/백엔드 미선택 | Dockerfile 에 구체값 ARG 명시: `ARG CURL_CONFIGURE_OPTION="--with-openssl --with-libssh2 --with-nghttp2 --with-brotli"` + 해당 `-dev` 헤더 설치 |
| `Couldn't find the node_modules state file` (yarn) | 프론트엔드 빌드 전 의존 설치 누락, 또는 yarn classic 으로 berry 프로젝트 빌드 | **`yarn install --immutable`** 를 build 앞에. JS 빌더는 **`node:*` base** 사용(golang+apk yarn classic 금지) |
| `make: *** [build-js] Error` / 빌더 합쳐서 실패 | multi-stage 를 단일 stage 로 합치고 언어 툴체인을 욱여넣음 | 원본 multi-stage 보존, 빌드 전용 stage 는 원본 pinned base(golang/node) 유지, `COPY --from=` 관계 유지 |
| `COPY --from=...: not found` | 빌더 산출물 경로 오인 | 빌더에서 실제 생성 경로 확인 후 final stage COPY 출처 정정 |
| `not a commit!` / 태그 clone 경고 | annotated tag 를 `--branch` 로 clone | 대개 무해(경고). 필요 시 `git fetch --tags` 후 체크아웃 |

> **핵심 안전 전략**: 원본 Dockerfile 을 **스테이지·명령·base 태그까지 그대로 옮기고**, (a) *출하* stage 의 `FROM` 만 승인 base 로 교체, (b) 위 idempotent(`ln -sf`/`mkdir -p`)·`USER root`·주입 ARG 보정만 추가한다. 원본 명령을 임의로 단순화하거나 스테이지를 합치지 않는다.

## 런타임 실행 실패 (빌드는 성공하는데 컨테이너가 기동 직후 죽는 경우)

래핑은 빌드만 통과하면 끝이 아니다. base 교체로 **실행 유저·CWD·libc 가 원본과 달라지면** 빌드는 성공해도 런타임에 죽는다. 빌드 로그가 아니라 **파드/컨테이너 로그**에서 잡힌다.

| 증상 (컨테이너/파드 로그) | 원인 | 해결 |
|---|---|---|
| `exec /<binary>: no such file or directory` (바이너리는 `ls` 로 보이는데도) | **glibc 동적 링크 바이너리를 musl `baseimage/alpine` 에서 실행** → loader `/lib64/ld-linux-*` 부재. GitHub release(GoReleaser) tarball 바이너리에서 흔하다 | 원본처럼 **소스에서 `CGO_ENABLED=0` 정적 빌드**(golang 빌더 → alpine COPY) 권장, 또는 glibc base(`baseimage/ubuntu`). 확인: `readelf -l <bin> \| grep interp` / `qemu-*: Could not open '/lib64/ld-linux-*'` |
| `stat <dir>/: permission denied` / `the path "<dir>/" cannot be accessed` (상대경로) | 원본은 **root + WORKDIR=/** 로 돌았는데 wrap 이 USER/WORKDIR 를 안 맞춰 **비루트(uid 500/1000) + CWD=/root(0700)** 로 실행 → 상대경로가 풀리는 `/root` 를 비루트가 traverse 못 함 | 런타임 stage 에 원본과 동일하게 **`USER root` + `WORKDIR /`** 명시 (원본 USER 는 `docker inspect --format '{{.Config.User}} {{.Config.WorkingDir}}' <원본>` 으로 확인; 빈 값/`0`=root) |
| `... has runAsNonRoot and image will run as root` (파드 기동 실패) | 원본은 비루트인데 wrap 이 빌드용 `USER root` 후 **원본 비루트 USER 로 복귀 안 함** → 차트의 `runAsNonRoot` 정책과 충돌 | 런타임 stage 끝에서 **원본의 정확한 비루트 uid 로 복원** |
| 권한/소유권 관련 동작 이상 (uid 는 비루트인데 원본과 다른 값) | 원본 비루트 uid 와 **다른 uid** 로 설정(예: 65532↔65534, nobody↔다른 번호) | 원본 uid 와 정확히 일치 (이름 USER 는 `getent passwd <name>` 로 숫자까지 대조) |

> **예외 — 의도적 비루트는 그대로 둔다**: `redis`·`zookeeper` 등 공식 이미지는 entrypoint 가 `uid≠0` 를 감지해 root 권한강하(`gosu`)를 건너뛰고 그대로 실행하도록 설계돼 있고, 데이터 디렉터리도 빌드 때 미리 chown 한다. 이런 이미지는 wrap 이 비루트로 실행해도 정상이므로 `USER root` 로 되돌리지 말 것. entrypoint 의 uid 분기를 먼저 확인한다.

## 패키지 매니저 전환

| 원본 계열 | 원본 명령 | navix(RHEL) 대응 |
|---|---|---|
| debian/ubuntu | `apt-get update && apt-get install -y <pkg>` | `dnf install -y <pkg>` (캐시 정리: `dnf clean all`) |
| debian/ubuntu | `apt-get purge --auto-remove` | `dnf remove -y <pkg>` |
| alpine | `apk add --no-cache <pkg>` | `dnf install -y <pkg>` |
| alpine | `apk del <pkg>` | `dnf remove -y <pkg>` |

> navix 에 `dnf` 가 없고 `microdnf` 만 있는 경우가 있으니 빌드 전 `docker run --rm <navix> sh -c 'command -v dnf microdnf'` 로 확인한다.

## 자주 나오는 패키지명 차이 (debian → RHEL)

| debian/ubuntu | RHEL 계열 |
|---|---|
| `libssl-dev` | `openssl-devel` |
| `libpq-dev` | `libpq-devel` (또는 `postgresql-devel`) |
| `libffi-dev` | `libffi-devel` |
| `zlib1g-dev` | `zlib-devel` |
| `libcurl4-openssl-dev` | `libcurl-devel` |
| `build-essential` | `gcc gcc-c++ make` (또는 `dnf groupinstall "Development Tools"`) |
| `ca-certificates` | `ca-certificates` (동일, 갱신은 `update-ca-trust`) |

> 표에 없는 패키지는 `dnf search <키워드>` 또는 RHEL 패키지 검색으로 확인. `-dev` 접미사는 대부분 `-devel` 로 대응된다.

## navix(신형 RHEL) RPM ABI 불일치 — el 타깃·OpenSSL·Python 버전 주의

`baseimage/navix:10.1` 은 **신형 RHEL 계열(el10): OpenSSL 3 + Python 3.12** 다. 외부 벤더가 배포하는 RPM 이 **el8/el9 빌드**면 런타임 공유라이브러리 의존이 navix 에서 **불충족**되어 `dnf install` 이 깨진다(실측 사례):

| 증상 | 원인 | 해결 |
|---|---|---|
| `nothing provides libssl.so.1.1 / libcrypto.so.1.1 needed by <pkg>.el8` | el8 RPM 은 **OpenSSL 1.1** 링크. navix 는 OpenSSL **3** 만 있고 `compat-openssl11` 패키지도 없음 | OpenSSL3 링크인 **el9+ RPM**(보통 상위 패치 버전)으로 bump. el9 에 해당 버전이 없으면 사용자와 버전 상향/whitelist 합의 (예: mysql 8.0.35 el8 → **8.0.37 el9**) |
| `nothing provides libpython3.9.so.1.0 needed by <pkg>.el9` | el9 RPM 은 **Python 3.9** 링크. navix(el10)는 Python **3.12** | 해당 패키지가 핵심이면 el10 빌드/대체 확인, **보조 패키지면 드롭**(아래) |

> **핵심 RPM 은 navix(el10)의 OpenSSL3/Python3.12 ABI 에 맞는 el 타깃(el9+, openssl3 링크)을 골라라.** "버전 동일" 이 그 base 에서 물리적으로 불가하면(해당 el 타깃에 그 버전이 없음) **버전 상향 vs whitelist 를 사용자에게 확인**한다.

## 선택적 보조 패키지는 드롭 가능

이미지의 **부가/관리 도구**(예: mysql 의 `mysql-shell`/`mysqlsh`)가 base 비호환(위 ABI 불일치 등)으로 설치 불가할 때, 그 패키지가 **핵심 동작(서버/클라이언트)에 필수가 아니면 생략**하고 기능하는 코어 이미지를 제공한다. 생략 사실과 사유·복구 조건을 Dockerfile 주석·PR 에 명시한다. (예: mysql-shell el9 가 python3.9 요구 → navix 에서 드롭, mysqld/mysql 클라이언트는 영향 없음.)

## 경로/환경 차이 체크리스트

- [ ] 쉘: debian 의 `/bin/sh`(dash) 가정 스크립트 → bash 문법 확인
- [ ] 기본 USER / 홈 디렉토리: 단정하지 말고 `docker run --rm <navix> id && docker inspect <navix>` 로 확인 후 `USER`/`WORKDIR` 반영
- [ ] root 권한이 필요한 단계는 `USER root` → 작업 → 원래 사용자로 복귀 패턴 사용
- [ ] locale / timezone 설정 명령 계열 차이 (`localedef` vs `locale-gen`)

## 알려진 빌드 에러와 해결 (위키 정책 4-4)

| 문제 | 해결 방법 |
|---|---|
| gpg key error / `keyserver receive failed: End of file` | 빌드 네트워크에서 **hkp 포트(11371)/hkp:80 차단**이 흔하다. **벤더가 HTTPS 로 배포하는 키 파일**을 우선 import: `wget -O- https://<vendor>/<key>.key \| gpg --batch --import`. 키서버를 쓸 거면 HTTPS(443) 웹 조회: `wget -O- "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x<KEYID>" \| gpg --batch --import`. 서명 검증(`gpg --verify`)은 유지 |
| `no public key - can't apply revocation certificate` / `gpg --verify: No public key` | 원본 Dockerfile 이 명시한 keyid 가 **폐기(revoked)됐거나 그 아티팩트의 실제 서명자가 아님**(벤더가 키 로테이션·재서명한 경우 흔함. 예: InfluxData telegraf 1.25.0 `.deb.asc` 실제 서명자는 `influxdata-archive_compat.key`, 원본이 받던 `05CE…` 구키 아님) | **아티팩트의 실제 서명자(issuer)를 확인**하고 그 키를 import. 확인법: `gpg --list-packets <file>.asc \| grep -i issuer` (또는 keyid 무시하고 벤더 HTTPS 키 파일을 import 후 `gpg --verify` 가 통과하는지 확인). 검증 통과하는 키만 사용, fingerprint 로 핀 |
| 사용자 입력 요구로 빌드 중단 | Dockerfile 최상단에 `ENV DEBIAN_FRONTEND=noninteractive` 추가 |
| `apt purge --auto-remove` 에러 | `-o Dpkg::Options::="--force-confnew"` 옵션 추가 |

> 위 사례는 debian/ubuntu 계열 빌드 단계가 Dockerfile 에 남아있는 경우 기준이다.
> **교체 시도 후에도 빌드가 불가능하면 예외 whitelist 처리로 진행한다** ([policy.md](policy.md) 참고).

## 검증

1. `docker build` 성공
2. 컨테이너 기동 스모크: `docker run --rm <이미지> <버전출력/헬스체크 명령>`
3. 애플리케이션 핵심 기능 1개 이상 동작 확인 (예: HTTP 응답, CLI 출력)
