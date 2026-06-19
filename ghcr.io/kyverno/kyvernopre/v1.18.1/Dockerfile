# 원본 이미지·태그: ghcr.io/kyverno/kyvernopre:v1.18.1
# 원본 base: distroless/static nonroot (ko 로 빌드된 정적 Go 바이너리)
# 계열 매핑: 정적 Go(CGO 비활성) 단일 바이너리 → alpine 런타임
# 소스: git clone v1.18.1 후 go build ./cmd/kyverno-init (kyvernopre init container)
ARG GIT_TAG=v1.18.1
FROM docker.io/library/golang:1.26 AS builder
WORKDIR /go/src/github.com/kyverno/kyverno
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kyverno/kyverno.git .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X github.com/kyverno/kyverno/pkg/version.BuildVersion=${GIT_TAG}" \
    -o /out/kyvernopre ./cmd/kyverno-init

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
RUN apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source=https://github.com/kyverno/kyverno
LABEL org.opencontainers.image.description="Kyverno init container kyvernopre (v1.18.1)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/kyvernopre /bin/kyvernopre
USER 65534
ENTRYPOINT ["/bin/kyvernopre"]
