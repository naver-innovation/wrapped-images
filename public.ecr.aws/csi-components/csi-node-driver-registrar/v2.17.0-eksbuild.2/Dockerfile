# ============================================================
# csi-node-driver-registrar v2.17.0 — BaseImage(navix) 래핑
# ------------------------------------------------------------
# 원본: public.ecr.aws/csi-components/csi-node-driver-registrar:v2.17.0-eksbuild.2
#   (upstream: github.com/kubernetes-csi/node-driver-registrar v2.17.0,
#    gcr.io/distroless/static + 정적 바이너리 COPY — USER 미지정=root)
# 정책: distroless 원본 → 소스에서 CGO_ENABLED=0 정적 빌드 후 승인 base 에 COPY
#   (release 바이너리 다운로드 대신 소스 빌드 — musl/glibc 무관, baseimage-oci 원칙 9)
#
# 빌드 (컨텍스트 무관 — 빈 디렉토리면 됨):
#   docker build -t <tag> -f mountpoint-s3/wrap/Dockerfile.csi-node-driver-registrar mountpoint-s3/wrap
# ============================================================

# 빌드 전용 stage: 언어 전용 base 유지 (출하 안 됨)
# go.mod 가 go >= 1.26 요구 (golang 이미지는 GOTOOLCHAIN=local 이라 자동 업그레이드 안 됨)
FROM golang:1.26 AS builder
ARG REGISTRAR_VERSION=v2.17.0
WORKDIR /src
RUN git clone --branch "${REGISTRAR_VERSION}" --depth 1 \
        https://github.com/kubernetes-csi/node-driver-registrar . && \
    make build   # release-tools: CGO_ENABLED=0 정적 빌드 → bin/csi-node-driver-registrar

# 출하 stage: 승인 base 교체 (정적 바이너리 — 추가 패키지 불필요)
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos
COPY --from=builder /src/bin/csi-node-driver-registrar /csi-node-driver-registrar
# 원본 distroless/static = USER 미지정(root), WORKDIR=/ — 명시 복원 (navix 기본 비루트 함정 방지)
USER root
WORKDIR /
ENTRYPOINT ["/csi-node-driver-registrar"]
