# 원본 이미지·태그 : quay.io/prometheus/prometheus:v3.10.0
# 원본 base        : quay.io/prometheus/busybox-linux-<arch>:latest (Prometheus busybox 변형)
# 계열 매핑 근거   : 원본은 busybox(musl) 단일 정적 바이너리 런타임 → musl 계열인 alpine 으로 매핑
# 소스 확보 방식   : upstream 이 amd64/arm64 정적 release 바이너리 + sha256 을 GitHub Releases 로 공식 배포 → 다운로드 후 sha256 검증 (빌드 불필요)
#                   tarball 에 prometheus, promtool, prometheus.yml, LICENSE, NOTICE 포함 (3.x 는 consoles/ 미포함). upstream Dockerfile 레이아웃 그대로 재현.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source="https://github.com/prometheus/prometheus"
LABEL org.opencontainers.image.description="The Prometheus monitoring system and time series database"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 는 non-root → 설치/다운로드/디렉터리 생성 위해 root 로 전환
USER root
RUN apk add --no-cache ca-certificates wget

ARG TARGETARCH
ARG PROMETHEUS_VERSION=3.10.0
# upstream release 페이지의 per-arch sha256 (linux amd64/arm64)
ARG SHA256_amd64=41c50d97bb6a181623fc89d3fe61d0cc68ee69cc93da9091b8bba005f9690122
ARG SHA256_arm64=f6fc81c7955b6e1ddd532c62b55896f7e7a61d997a3817ac3534114f2dd33ab1
RUN set -eux; \
    eval "SHA256=\${SHA256_${TARGETARCH}}"; \
    DIR="prometheus-${PROMETHEUS_VERSION}.linux-${TARGETARCH}"; \
    TARBALL="${DIR}.tar.gz"; \
    wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${TARBALL}" -O "${TARBALL}"; \
    echo "${SHA256}  ${TARBALL}" | sha256sum -c -; \
    tar -xzf "${TARBALL}"; \
    install -m 0755 "${DIR}/prometheus" /bin/prometheus; \
    install -m 0755 "${DIR}/promtool"   /bin/promtool; \
    mkdir -p /etc/prometheus; \
    cp "${DIR}/prometheus.yml" /etc/prometheus/prometheus.yml; \
    cp "${DIR}/LICENSE" /LICENSE; \
    cp "${DIR}/NOTICE"  /NOTICE; \
    rm -rf "${TARBALL}" "${DIR}"

# 원본 런타임 재현: 데이터 디렉터리 + nobody 소유권 (upstream: chown -R nobody:nobody /etc/prometheus /prometheus && chmod g+w /prometheus)
WORKDIR /prometheus
RUN mkdir -p /prometheus && chown -R nobody:nobody /etc/prometheus /prometheus && chmod g+w /prometheus

USER nobody
EXPOSE 9090
VOLUME [ "/prometheus" ]
ENTRYPOINT [ "/bin/prometheus" ]
CMD [ "--config.file=/etc/prometheus/prometheus.yml", \
      "--storage.tsdb.path=/prometheus" ]
