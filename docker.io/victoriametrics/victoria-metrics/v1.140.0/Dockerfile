# 원본: docker.io/victoriametrics/victoria-metrics:v1.140.0
#   https://github.com/VictoriaMetrics/VictoriaMetrics (tag v1.140.0)
# 원본 base:
#   multiarch Dockerfile: alpine + ca-certificates → runtime 에 binary copy
# 계열 매핑: alpine → baseimage/alpine
# 보정 사항:
#   - 원본은 빌드 시스템이 victoria-metrics-linux-${TARGETARCH}-prod 바이너리를 주입한다.
#     본 repo CI 는 Dockerfile 디렉터리만 빌드하므로 공식 release tarball 을 arch 별로 다운로드한다.
#   - release checksums 파일로 tarball 과 victoria-metrics-prod 바이너리를 모두 검증한다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/VictoriaMetrics/VictoriaMetrics"
LABEL org.opencontainers.image.description="VictoriaMetrics single-node time series database"
LABEL org.opencontainers.image.licenses="Apache-2.0"

USER root

ARG TARGETARCH
ARG VM_VERSION=1.140.0

RUN set -eux; \
    apk add --no-cache ca-certificates tar wget; \
    case "${TARGETARCH:-amd64}" in \
      amd64) VM_ARCH=amd64 ;; \
      arm64) VM_ARCH=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    asset="victoria-metrics-linux-${VM_ARCH}-v${VM_VERSION}.tar.gz"; \
    checksums="victoria-metrics-linux-${VM_ARCH}-v${VM_VERSION}_checksums.txt"; \
    base_url="https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v${VM_VERSION}"; \
    wget -qO "/tmp/${asset}" "${base_url}/${asset}"; \
    wget -qO "/tmp/${checksums}" "${base_url}/${checksums}"; \
    (cd /tmp && grep "  ${asset}$" "${checksums}" | sha256sum -c -); \
    tar -xzf "/tmp/${asset}" -C /tmp victoria-metrics-prod; \
    (cd /tmp && grep "  victoria-metrics-prod$" "${checksums}" | sha256sum -c -); \
    install -m 0755 /tmp/victoria-metrics-prod /victoria-metrics-prod; \
    rm -f "/tmp/${asset}" "/tmp/${checksums}" /tmp/victoria-metrics-prod

EXPOSE 8428
ENTRYPOINT ["/victoria-metrics-prod"]
