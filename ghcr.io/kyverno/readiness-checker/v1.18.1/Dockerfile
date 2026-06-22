# 원본 이미지·태그: ghcr.io/kyverno/readiness-checker:v1.18.1
# 원본 base: distroless/static nonroot (ko 로 빌드된 정적 Go 바이너리)
# 계열 매핑: 정적 Go(CGO 비활성) 단일 바이너리 → alpine 런타임
# 소스: git clone v1.18.1 후 go build ./cmd/readiness-checker (kyverno helm test/uninstall hook 용 readiness checker)
ARG GIT_TAG=v1.18.1
FROM docker.io/library/golang:1.26 AS builder
WORKDIR /go/src/github.com/kyverno/kyverno
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kyverno/kyverno.git .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X github.com/kyverno/kyverno/pkg/version.BuildVersion=${GIT_TAG}" \
    -o /out/readiness-checker ./cmd/readiness-checker

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
RUN apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source=https://github.com/kyverno/kyverno
LABEL org.opencontainers.image.description="Kyverno readiness-checker (v1.18.1)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/readiness-checker /bin/readiness-checker
# 원본 distroless nonroot 와 동일한 uid 65532 로 실행 (이전 65534 는 원본과 불일치)
USER 65532
ENTRYPOINT ["/bin/readiness-checker"]
