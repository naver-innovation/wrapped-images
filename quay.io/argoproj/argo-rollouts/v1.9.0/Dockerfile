# 원본: quay.io/argoproj/argo-rollouts:v1.9.0
#   https://github.com/argoproj/argo-rollouts (tag v1.9.0, target stage: 최종 이미지 = rollouts-controller)
#   cmd/rollouts-controller 단일 Go 바이너리. UI 는 컨트롤러에 임베드되지 않음
#   (원본 build stage 는 UI dist 마커만 생성해 make 가 UI 재빌드를 시도하지 않게 함).
# 원본 base:
#   builder  : golang:1.24                   (debian / glibc 계열)
#   runtime  : gcr.io/distroless/static-debian12  (정적 바이너리 base)
# 계열 매핑:
#   builder  : 컨트롤러 바이너리는 CGO_ENABLED=0 완전 정적 → musl/glibc 무관.
#              baseimage/alpine 빌더로 통일(허용 base, go 툴체인 제공).
#   runtime  : distroless/static 는 정적 Go 바이너리 base → baseimage/alpine 로 통일.
# 소스는 벤더링 대신 빌더에서 v1.9.0 태그를 git clone (태그 고정).
ARG GIT_TAG=v1.9.0

# ── builder ───────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS builder
# baseimage/alpine 은 기본 USER 가 비루트 → apk/빌드 위해 root 로 전환
USER root
RUN apk add --no-cache \
    git \
    make \
    ca-certificates \
    wget \
    curl \
    gcc \
    libc-dev \
    bash \
    go

ARG GIT_TAG
WORKDIR /go/src/github.com/argoproj/argo-rollouts
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-rollouts.git .
RUN go mod download
# 원본 argo-rollouts-build stage: make 가 UI 를 재빌드하지 않도록 UI dist 마커 생성.
# (컨트롤러 바이너리는 UI 를 임베드하지 않으므로 yarn UI 빌드 불필요)
RUN touch ui/dist/node_modules.marker && \
    mkdir -p ui/dist/app && \
    touch ui/dist/app/index.html
# 정적 빌드 (make controller → CGO_ENABLED=0 go build ./cmd/rollouts-controller) — 원본과 동일.
RUN make controller

# ── runtime (원본 최종 이미지 stage) ────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/argoproj/argo-rollouts
LABEL org.opencontainers.image.description="argo-rollouts - Argo Rollouts controller (rollouts-controller)"
LABEL org.opencontainers.image.licenses=Apache-2.0

# 원본 runtime 이 distroless 위에 올리던 ca-certificates.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 원본 런타임 stage 의 비루트 UID(999) 유지 (runAsNonRoot).
USER 999
WORKDIR /home/argo-rollouts
COPY --chown=999 --from=builder /go/src/github.com/argoproj/argo-rollouts/dist/rollouts-controller /bin/

ENTRYPOINT [ "/bin/rollouts-controller" ]
