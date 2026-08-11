# 원본          : docker.io/falcosecurity/falco:0.44.1
# 원본 base      : cgr.dev/chainguard/wolfi-base — apk 를 쓰지만 musl 이 아니라 glibc 배포판
#                  (원본 이미지 apk db 실측: P:glibc, P:ld-linux)
# 계열 매핑      : wolfi(glibc) → baseimage/ubuntu:24.04
#                  falco 바이너리 실측(ELF 헤더 파싱): INTERP=/lib/ld-linux-aarch64.so.1,
#                  NEEDED=libm/libpthread/libc/libdl/librt → glibc 동적링크라 musl 인
#                  baseimage/alpine 에서는 loader 부재로 실행 불가. 반드시 glibc base.
#                  원본 config.d/falco.container_plugin.yaml 주석도 "non musl installation" 명시.
# 원본 Dockerfile: falcosecurity/falco 태그 0.44.1 의 docker/falco/Dockerfile
# 원본 런타임 계약(docker inspect 실측): USER 0(root), WORKDIR /, ENTRYPOINT 없음,
#                  CMD ["/usr/bin/falco"],
#                  ENV FALCO_VERSION/VERSION_BUCKET/HOST_ROOT/HOME/SSL_CERT_FILE
# 방식          : 원본 Dockerfile 의 단계·순서를 그대로 옮기고 apk → apt 로만 치환한다.
#                  download.falco.org 는 이 경로에 체크섬·서명 파일을 제공하지 않아
#                  (SHA256SUMS/.sha256/.asc 모두 미제공) 릴리스 tarball 의 sha256 을 직접
#                  측정해 아키텍처별로 핀하고 빌드에서 검증한다 (kafka-ui 래핑과 동일 패턴).
#                  원본이 빌드 컨텍스트에서 ADD 하던 config/falco.iso8601_timeformat.yaml 은
#                  내용이 두 줄뿐이라 RUN 으로 직접 생성해 컨텍스트 의존을 없앴다.

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

# baseimage/ubuntu 기본 USER 는 비루트(uid 500 waslteam) — 설치 단계 위해 root 로 전환
USER root

ARG FALCO_VERSION=0.44.1
ARG VERSION_BUCKET=bin
ARG HOST_ROOT=/host
ARG HOME=/root
# buildx 가 주입하는 타깃 아키텍처 (미주입 시 dpkg 값으로 폴백)
ARG TARGETARCH

LABEL org.opencontainers.image.authors='The Falco Authors https://falco.org' \
      org.opencontainers.image.url='https://falco.org' \
      org.opencontainers.image.source='https://github.com/falcosecurity/falco' \
      org.opencontainers.image.vendor='Falco Organization' \
      org.opencontainers.image.licenses='Apache-2.0' \
      org.opencontainers.image.version=${FALCO_VERSION} \
      org.opencontainers.image.description="Wrapped docker.io/falcosecurity/falco:0.44.1 (falco on approved ubuntu base)" \
      maintainer="cncf-falco-dev@lists.cncf.io"

LABEL usage="docker run -i -t --privileged -v /var/run/docker.sock:/host/var/run/docker.sock -v /proc:/host/proc:ro  -v /etc:/host/etc:ro falcosecurity/falco:latest"
# NOTE: for the "least privileged" use case, please refer to the official documentation

# 원본 이미지와 동일한 ENV. SSL_CERT_FILE 은 wolfi ca-certificates 가 잡아주던 값으로,
# ubuntu 에서도 같은 경로라 그대로 명시해 동등성을 맞춘다.
ENV FALCO_VERSION="${FALCO_VERSION}" \
    VERSION_BUCKET="${VERSION_BUCKET}" \
    HOST_ROOT="${HOST_ROOT}" \
    HOME="${HOME}" \
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

# 원본 `apk add curl ca-certificates jq libstdc++` 대응(apt 패키지명: libstdc++6).
# base 선탑재 패키지의 구버전 CVE 는 apt-get upgrade 로 함께 보정한다.
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        libstdc++6; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /

# 원본과 동일하게 릴리스 tarball 을 받아 / 에 펼친다.
#   - /falco/usr/src/falco-* (드라이버 소스) 제거 — 원본과 동일
#   - falcoctl 제거 — 원본과 동일(런타임 플러그인/룰 자동 다운로드 비활성)
# 아키텍처 이름은 falco 배포 규칙(x86_64/aarch64)에 맞춰 매핑한다.
RUN set -eux; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
        amd64) FALCO_ARCH=x86_64;  FALCO_SHA256=bc5b7a3bdf26fc91e520fc20b3461613c6e725148437121697a8d20243132127 ;; \
        arm64) FALCO_ARCH=aarch64; FALCO_SHA256=17ff67764cb84374ca0fcc98a733316f973a90f3457495df35a24bd839b4ce87 ;; \
        *) echo "unsupported architecture: ${TARGETARCH:-unknown}" >&2; exit 1 ;; \
    esac; \
    echo "Downloading Falco ${FALCO_VERSION} for ${FALCO_ARCH}"; \
    curl -fsSL -o falco.tar.gz \
        "https://download.falco.org/packages/${VERSION_BUCKET}/${FALCO_ARCH}/falco-${FALCO_VERSION}-${FALCO_ARCH}.tar.gz"; \
    echo "${FALCO_SHA256}  falco.tar.gz" | sha256sum -c -; \
    tar -xf falco.tar.gz; \
    rm -f falco.tar.gz; \
    mv "falco-${FALCO_VERSION}-${FALCO_ARCH}" falco; \
    rm -rf /falco/usr/src/falco-*; \
    cp -r /falco/* /; \
    rm -rf /falco; \
    rm -rf /usr/bin/falcoctl /etc/falcoctl/

# 원본이 빌드 컨텍스트에서 ADD 하던 config/falco.iso8601_timeformat.yaml 과 동일한 내용
RUN set -eux; \
    mkdir -p /etc/falco/config.d; \
    printf '%s\n' \
        '# Enable iso 8601 time format on docker' \
        'time_format_iso_8601: true' \
        > /etc/falco/config.d/falco.iso8601_timeformat.yaml

# 원본 런타임 계약 복원: USER root(=0) + WORKDIR / + ENTRYPOINT 없음 + CMD /usr/bin/falco
WORKDIR /
USER root
CMD ["/usr/bin/falco"]
