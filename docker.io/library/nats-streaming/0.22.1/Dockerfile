# =============================================================================
# 원본 이미지      : docker.io/nats-streaming:0.22.1  (docker.io/library/nats-streaming)
# 원본 base 이미지 : scratch (upstream 은 정적 바이너리 단독 이미지)
# 계열 매핑        : alpine -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : GOLD B (공식 릴리스 바이너리 다운로드 -> alpine)
#                   github.com/nats-io/nats-streaming-server v0.22.1 의
#                   linux-<arch>.zip(CGO_ENABLED=0 정적 바이너리) + SHA256SUMS 검증.
# =============================================================================
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/nats-io/nats-streaming-server"
LABEL org.opencontainers.image.description="NATS Streaming Server (STAN) wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 가 non-root 이므로 설치 전 root 로 전환
USER root

RUN apk add --no-cache ca-certificates wget unzip

ARG VERSION=0.22.1
ARG TARGETARCH

# 공식 릴리스 zip 다운로드 -> sha256 검증 -> 바이너리 설치
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH_SHA="87bb40f09866e34c6c7a1c559681a6dd16e7e91e40c31caab63a40d0db038b9f" ;; \
      arm64) ARCH_SHA="8f01f1bc63ecb800d85d1d583a9313d1bf5b96f8abe3a05ee78ffb85369517a6" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    ARCHIVE="nats-streaming-server-v${VERSION}-linux-${TARGETARCH}.zip"; \
    wget -q "https://github.com/nats-io/nats-streaming-server/releases/download/v${VERSION}/${ARCHIVE}"; \
    echo "${ARCH_SHA}  ${ARCHIVE}" | sha256sum -c -; \
    unzip -q "${ARCHIVE}"; \
    install -m 0755 "nats-streaming-server-v${VERSION}-linux-${TARGETARCH}/nats-streaming-server" /usr/local/bin/nats-streaming-server; \
    rm -rf "${ARCHIVE}" "nats-streaming-server-v${VERSION}-linux-${TARGETARCH}"

# upstream 공식 이미지는 root 로 동작하는 정적 단일 바이너리 이미지 (별도 USER 라인 없음).
# 동일하게 root 유지하여 동작을 보존한다.
EXPOSE 4222 8222

ENTRYPOINT ["/usr/local/bin/nats-streaming-server"]
CMD ["-m", "8222"]
