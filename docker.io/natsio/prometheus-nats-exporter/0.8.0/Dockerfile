# =============================================================================
# 원본 이미지      : docker.io/natsio/prometheus-nats-exporter:0.8.0
# 원본 base 이미지 : scratch (upstream goreleaser/distroless 계열 정적 바이너리)
# 계열 매핑        : alpine -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : GOLD B (공식 릴리스 바이너리 다운로드 -> alpine)
#                   github.com/nats-io/prometheus-nats-exporter v0.8.0 의
#                   linux-<arch>.tar.gz 정적 바이너리 + checksums 검증.
# =============================================================================
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/nats-io/prometheus-nats-exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for NATS server metrics wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 가 non-root 이므로 설치 전 root 로 전환
USER root

RUN apk add --no-cache ca-certificates wget

ARG VERSION=0.8.0
ARG TARGETARCH

# 공식 릴리스 tar.gz 다운로드 -> sha256 검증 -> 바이너리 설치
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH_SHA="b0c6ccd7c2d7873a9dd650107856f442f7f15b52d9505b8b0f3f09950d4bb9d4" ;; \
      arm64) ARCH_SHA="556ee1ce339e7e24070ad5571929dc7e04ef2ce76f1202727aacc3af72cc574d" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    ARCHIVE="prometheus-nats-exporter-v${VERSION}-linux-${TARGETARCH}.tar.gz"; \
    wget -q "https://github.com/nats-io/prometheus-nats-exporter/releases/download/v${VERSION}/${ARCHIVE}"; \
    echo "${ARCH_SHA}  ${ARCHIVE}" | sha256sum -c -; \
    tar -xzf "${ARCHIVE}"; \
    install -m 0755 "prometheus-nats-exporter-v${VERSION}-linux-${TARGETARCH}/prometheus-nats-exporter" /usr/local/bin/prometheus-nats-exporter; \
    rm -rf "${ARCHIVE}" "prometheus-nats-exporter-v${VERSION}-linux-${TARGETARCH}"

# upstream 은 root 로 동작하는 정적 단일 바이너리 이미지 (별도 nonroot 계정 없음)
EXPOSE 7777

ENTRYPOINT ["/usr/local/bin/prometheus-nats-exporter"]
