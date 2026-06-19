# 원본: registry.k8s.io/sig-storage/livenessprobe:v2.9.0
# 원본 base: gcr.io/distroless/static (USER 없음 / root 실행, ENTRYPOINT=/livenessprobe)
# 계열 매핑: distroless/static → baseimage/alpine:3.23 (정적 CGO_ENABLED=0 바이너리)
# 소스 방식: 공식 릴리스 바이너리 미배포 → 멀티스테이지 소스 빌드
#   - 빌더: golang:1.19 (go.mod go 1.19), git clone --branch v2.9.0
#   - main 패키지: ./cmd/livenessprobe (release-tools/build.make CMDS_DIR=cmd, CMDS=livenessprobe)
#   - 빌드 플래그: CGO_ENABLED=0 GOOS=linux, ldflags '-X main.version=<tag> -extldflags "-static"'
ARG GIT_TAG=v2.9.0

FROM docker.io/library/golang:1.19 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-csi/livenessprobe.git .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags "-X main.version=${GIT_TAG} -extldflags \"-static\"" \
    -o /out/livenessprobe ./cmd/livenessprobe

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본은 distroless/static 기반 root 실행 → baseimage 기본 non-root 를 root 로 복귀
USER root
RUN apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source=https://github.com/kubernetes-csi/livenessprobe
LABEL org.opencontainers.image.description="CSI livenessprobe (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/livenessprobe /livenessprobe
ENTRYPOINT ["/livenessprobe"]
