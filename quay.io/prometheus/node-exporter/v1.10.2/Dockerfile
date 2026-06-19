# 원본 이미지·태그 : quay.io/prometheus/node-exporter:v1.10.2
# 원본 base        : quay.io/prometheus/busybox-linux-<arch>:latest (Prometheus busybox 변형)
# 계열 매핑 근거   : 원본은 busybox(musl) 단일 정적 바이너리 런타임 → musl 계열인 alpine 으로 매핑
# 소스 확보 방식   : upstream 이 amd64/arm64 정적 release 바이너리 + sha256 을 GitHub Releases 로 공식 배포 → 다운로드 후 sha256 검증 (빌드 불필요)
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source="https://github.com/prometheus/node_exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for hardware and OS metrics exposed by *NIX kernels"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 는 non-root → 설치/다운로드 위해 root 로 전환
USER root
RUN apk add --no-cache ca-certificates wget

ARG TARGETARCH
ARG NODE_EXPORTER_VERSION=1.10.2
# upstream release 페이지의 per-arch sha256 (linux amd64/arm64)
ARG SHA256_amd64=c46e5b6f53948477ff3a19d97c58307394a29fe64a01905646f026ddc32cb65b
ARG SHA256_arm64=de69ec8341c8068b7c8e4cfe3eb85065d24d984a3b33007f575d307d13eb89a6
RUN set -eux; \
    eval "SHA256=\${SHA256_${TARGETARCH}}"; \
    TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-${TARGETARCH}.tar.gz"; \
    wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${TARBALL}" -O "${TARBALL}"; \
    echo "${SHA256}  ${TARBALL}" | sha256sum -c -; \
    tar -xzf "${TARBALL}"; \
    install -m 0755 "node_exporter-${NODE_EXPORTER_VERSION}.linux-${TARGETARCH}/node_exporter" /bin/node_exporter; \
    rm -rf "${TARBALL}" "node_exporter-${NODE_EXPORTER_VERSION}.linux-${TARGETARCH}"

# 원본 런타임 재현: USER nobody / EXPOSE 9100 / ENTRYPOINT
EXPOSE 9100
USER nobody
ENTRYPOINT [ "/bin/node_exporter" ]
