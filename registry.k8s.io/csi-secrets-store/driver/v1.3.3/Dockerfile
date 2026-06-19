# 원본: registry.k8s.io/csi-secrets-store/driver:v1.3.3
# 원본 base: registry.k8s.io/build-image/debian-base:bullseye (USER 없음 / root 실행, ENTRYPOINT=/secrets-store-csi)
# 계열 매핑: debian-base → baseimage/alpine:3.23 (정적 CGO_ENABLED=0 바이너리)
#   - 원본은 런타임에 `ca-certificates mount` 설치 → alpine 에서 ca-certificates + util-linux(mount/umount) 로 대응
# 소스 방식: 공식 릴리스 바이너리 미배포 → 멀티스테이지 소스 빌드
#   - 빌더: golang:1.19 (go.mod go 1.19), git clone --branch v1.3.3
#   - main 패키지: ./cmd/secrets-store-csi-driver (Makefile build: -o _output/secrets-store-csi)
#   - 빌드 플래그: CGO_ENABLED=0 GOOS=linux, ldflags '-X .../version.BuildVersion=<tag>'
ARG GIT_TAG=v1.3.3

FROM docker.io/library/golang:1.19 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-sigs/secrets-store-csi-driver.git .
RUN go mod download
# 원본 Makefile LDFLAGS: -X .../pkg/version.BuildVersion=<IMAGE_VERSION>
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags "-X sigs.k8s.io/secrets-store-csi-driver/pkg/version.BuildVersion=${GIT_TAG}" \
    -o /out/secrets-store-csi ./cmd/secrets-store-csi-driver

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본은 debian-base 기반 root 실행 → baseimage 기본 non-root 를 root 로 복귀
USER root
# 원본 런타임 의존성: ca-certificates + mount/umount (debian: clean-install ca-certificates mount → alpine: util-linux)
RUN apk add --no-cache ca-certificates util-linux
LABEL org.opencontainers.image.source=https://github.com/kubernetes-sigs/secrets-store-csi-driver
LABEL org.opencontainers.image.description="Secrets Store CSI Driver (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/secrets-store-csi /secrets-store-csi
ENTRYPOINT ["/secrets-store-csi"]
