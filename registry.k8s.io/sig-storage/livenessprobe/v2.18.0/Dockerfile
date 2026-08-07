# 원본: registry.k8s.io/sig-storage/livenessprobe:v2.18.0
# 원본 base: gcr.io/distroless/static:latest (USER=0 / root 실행, WORKDIR=/, ENTRYPOINT=/livenessprobe)
# 계열 매핑: distroless/static → baseimage/alpine:3.23 (정적 CGO_ENABLED=0 바이너리)
# 소스 방식: 공식 릴리스 바이너리 미배포 → 멀티스테이지 소스 빌드
#   - 빌더: golang:1.25 (go.mod go 1.25.0), git clone --branch v2.18.0
#   - main 패키지: ./cmd/livenessprobe (release-tools/build.make CMDS_DIR=cmd, CMDS=livenessprobe)
#   - 빌드 플래그: CGO_ENABLED=0 GOOS=linux, ldflags '-X main.version=<tag> -extldflags "-static"'
ARG GIT_TAG=v2.18.0

FROM docker.io/library/golang:1.25 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-csi/livenessprobe.git .
# CVE 보정 — v2.18.0 go.mod 의존성의 Trivy CRITICAL 1 / HIGH 7 을 모듈 상향으로 해결
# (앱 버전 유지, thanos v0.41.0 보정과 동일 전략):
#   grpc 1.82.1       (CVE-2026-33186 CRITICAL — fixed 1.79.3, GHSA-hrxh-6v49-42gf — fixed 1.82.1)
#   otel·otel/sdk 1.43.0 (CVE-2026-29181 — fixed 1.41.0)
#   x/net 0.56.0      (CVE-2026-25681, 27136, 33814, 39821 — fixed 0.55.0,
#                      x/text 0.39.0 이 0.56.0 요구해 상향)
#   x/text 0.39.0     (CVE-2026-56852)
#   x/crypto 0.53.0   (x/net 0.56.0 이 요구 — 모듈 그래프 정합)
RUN go get \
        google.golang.org/grpc@v1.82.1 \
        go.opentelemetry.io/otel@v1.43.0 \
        go.opentelemetry.io/otel/sdk@v1.43.0 \
        golang.org/x/crypto@v0.53.0 \
        golang.org/x/net@v0.56.0 \
        golang.org/x/text@v0.39.0 && \
    go mod tidy && go mod vendor
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags "-X main.version=${GIT_TAG} -extldflags \"-static\"" \
    -o /out/livenessprobe ./cmd/livenessprobe

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본은 distroless/static 기반 root 실행 → baseimage 기본 non-root 를 root 로 복귀
USER root
WORKDIR /
# baseimage/alpine:3.23 유래 OS 패키지 CVE(bind-libs/bind-tools/c-ares/curl/libcurl) 보정
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source=https://github.com/kubernetes-csi/livenessprobe
LABEL org.opencontainers.image.description="CSI livenessprobe (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/livenessprobe /livenessprobe
ENTRYPOINT ["/livenessprobe"]
