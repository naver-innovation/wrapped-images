# 원본          : registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.18.0
# 원본 base      : gcr.io/distroless/static-debian12 (USER nobody) — 원본은 자체 빌드한 "정적" Go 바이너리를 담는다.
# 계열 매핑      : 정적 Go(CGO 비활성) 단일 바이너리 → baseimage/alpine 런타임
#   - 이전 방식은 GitHub release(GoReleaser) tarball 바이너리를 받았는데 그건 glibc 동적 링크라
#     musl 인 baseimage/alpine 에서 loader(/lib64/ld-linux-*) 부재로
#     `exec /kube-state-metrics: no such file or directory` 로 죽었다.
#   - 원본과 동일하게 소스에서 CGO_ENABLED=0 정적 빌드하면 loader 가 불필요하므로 alpine 에서 그대로 실행된다.
#     (repo 내 kyverno wrap 들과 동일한 정적-빌드 패턴)
# 소스          : git clone v2.18.0 후 go build (main 패키지는 repo 루트, module k8s.io/kube-state-metrics/v2)
ARG GIT_TAG=v2.18.0

FROM docker.io/library/golang:1.26 AS builder
WORKDIR /go/src/k8s.io/kube-state-metrics
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes/kube-state-metrics.git .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/kube-state-metrics .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# baseimage/alpine 기본 USER 는 non-root → ca-certificates 설치를 위해 root 로 전환
USER root
RUN apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source=https://github.com/kubernetes/kube-state-metrics
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.version=v2.18.0
COPY --from=builder /out/kube-state-metrics /kube-state-metrics

# 원본은 metrics(8080), telemetry(8081) 포트를 노출
EXPOSE 8080 8081

# 원본 distroless 와 동일하게 비루트(nobody, uid 65534) 로 실행
USER 65534
ENTRYPOINT ["/kube-state-metrics"]
