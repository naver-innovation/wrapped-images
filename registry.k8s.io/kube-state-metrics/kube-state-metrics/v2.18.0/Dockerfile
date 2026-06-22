# 원본          : registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.18.0
# 원본 base      : gcr.io/distroless/static-debian12 (USER nobody, debian/glibc 계열)
# 계열 매핑(정정): GitHub release(GoReleaser) tarball 바이너리는 glibc 동적 링크다.
#   - 원본 공식 이미지는 자체 빌드한 "정적" 바이너리를 distroless/static 에 담지만,
#     이 wrap 은 release tarball 바이너리를 받아 쓴다. 그 바이너리는 /lib64/ld-linux-x86-64.so.2
#     (glibc loader)를 요구하므로 musl 인 baseimage/alpine 에서는 loader 부재로
#     `exec /kube-state-metrics: no such file or directory` 로 죽는다.
#   - 따라서 원본 debian 계열과 동일한 glibc base 인 baseimage/ubuntu 로 교체한다.
# 소스 방식      : 공식 release 바이너리 다운로드 (GoReleaser tarball + checksums.txt sha256 검증)
#
# upstream(github.com/kubernetes/kube-state-metrics v2.18.0) release 자산:
#   kube-state-metrics_Linux_x86_64.tar.gz  (amd64)
#   kube-state-metrics_Linux_arm64.tar.gz   (arm64)
#   kube-state-metrics_2.18.0_checksums.txt (sha256)
# 주의: amd64 의 release 아키텍처 접미사는 amd64 가 아닌 x86_64 이다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

ARG VERSION=2.18.0
ARG TARGETARCH
# baseimage/ubuntu 기본 USER 는 non-root → 설치를 위해 root 로 전환
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget tar \
    && rm -rf /var/lib/apt/lists/*

# TARGETARCH(amd64/arm64) → release 접미사(x86_64/arm64) 매핑 후
# tarball + checksums.txt 다운로드 → sha256 검증 → 바이너리 설치
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) REL_ARCH="x86_64" ;; \
        arm64) REL_ARCH="arm64" ;; \
        *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    BASE="https://github.com/kubernetes/kube-state-metrics/releases/download/v${VERSION}"; \
    TARBALL="kube-state-metrics_Linux_${REL_ARCH}.tar.gz"; \
    wget -q "${BASE}/${TARBALL}"; \
    wget -q "${BASE}/kube-state-metrics_${VERSION}_checksums.txt"; \
    grep " ${TARBALL}\$" "kube-state-metrics_${VERSION}_checksums.txt" | sha256sum -c -; \
    tar -xzf "${TARBALL}"; \
    install -m 0755 kube-state-metrics /kube-state-metrics; \
    rm -rf "${TARBALL}" "kube-state-metrics_${VERSION}_checksums.txt" kube-state-metrics

LABEL org.opencontainers.image.source=https://github.com/kubernetes/kube-state-metrics
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.version=v2.18.0

# 원본은 metrics(8080), telemetry(8081) 포트를 노출
EXPOSE 8080 8081

# 원본 distroless 와 동일하게 비루트(nobody, uid 65534) 로 실행 (ubuntu 에 65534 기본 존재)
USER 65534
ENTRYPOINT ["/kube-state-metrics"]
