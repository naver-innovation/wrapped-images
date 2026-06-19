# =============================================================================
# 원본 이미지      : ghcr.io/jkroepke/kube-webhook-certgen:1.8.0
# 원본 base 이미지 : golang:1.26.1 (builder, go.mod 기준) -> scratch (runtime)
# 계열 매핑        : scratch(정적 Go 바이너리) -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : GOLD A (소스 빌드 -> alpine)
#                   upstream Dockerfile(v1.8.0) 은 `COPY <bin> /` 후 scratch 위에
#                   단일 정적 바이너리만 올림(바이너리는 goreleaser 산출물).
#                   main.go 는 repo 루트 → `go build .` 로 동일 바이너리 재현.
#                   CGO_ENABLED=0 정적 링크 (k8s client-go 만 의존, cgo 없음).
#                   scratch 대신 승인된 OCIR alpine baseimage 로 교체.
# =============================================================================

ARG GIT_TAG=v1.8.0

# -----------------------------------------------------------------------------
# builder : kube-webhook-certgen 정적 바이너리 빌드 (upstream Makefile build 재현)
#           upstream go.mod 의 go 1.26.1 에 맞춰 golang 빌더 base 핀 고정
# -----------------------------------------------------------------------------
FROM golang:1.26.1-alpine3.22 AS builder

USER root

RUN apk add --no-cache git make ca-certificates bash

ARG GIT_TAG
WORKDIR /usr/local/src
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/jkroepke/kube-webhook-certgen.git .
RUN go mod download

# main 패키지는 repo 루트의 main.go (cmd/ 는 cobra 서브커맨드 패키지) → 빌드 경로는 `.`.
# scratch runtime 대응 위해 CGO_ENABLED=0 정적 링크로 명시.
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -o /go/bin/kube-webhook-certgen \
    .

# -----------------------------------------------------------------------------
# runtime : 승인된 OCIR alpine baseimage (upstream scratch 교체)
# -----------------------------------------------------------------------------
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/jkroepke/kube-webhook-certgen"
LABEL org.opencontainers.image.description="kube-webhook-certgen - admission webhook 인증서 생성/패치 도구 wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="MIT"

# baseimage 기본 USER 가 non-root 이므로 설치 작업 전 root 로 전환
USER root

# k8s API 통신(TLS) 용 root CA. baseimage 는 clean 보장 없으므로 idempotent 하게 설치.
RUN apk add --no-cache ca-certificates

# 정적 바이너리 배치 (upstream Dockerfile: COPY <bin> /)
COPY --from=builder /go/bin/kube-webhook-certgen /kube-webhook-certgen

# upstream scratch 이미지는 USER 미지정(root)이나, certgen 은 admission webhook
# patch Job 으로 nonroot(runAsNonRoot)로 구동되는 것이 관례 → distroless nonroot uid 65532 복원.
USER 65532:65532

ENTRYPOINT ["/kube-webhook-certgen"]
