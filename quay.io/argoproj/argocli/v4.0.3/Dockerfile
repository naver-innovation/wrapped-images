# 원본: quay.io/argoproj/argocli:v4.0.3
#   https://github.com/argoproj/argo-workflows (tag v4.0.3, target stage: argocli)
#   argocli 는 argo CLI/server 이미지로, 정적 UI 자산(yarn build)을 go 바이너리에 임베드한다.
# 원본 base:
#   ui builder  : node:20-alpine            (alpine 계열)
#   go builder  : golang:1.25.7-alpine3.23  (alpine / musl 계열)
#   runtime     : gcr.io/distroless/static-debian13  (정적 바이너리 base)
# 계열 매핑:
#   go builder : alpine → baseimage/alpine  (musl 유지)
#   ui builder : node:20-alpine 는 yarn UI 빌드 전용 → 원본 그대로 유지(자산 빌드만 수행, 런타임 미반영).
#   runtime    : distroless/static 는 CGO_ENABLED=0 정적 Go 바이너리 base → baseimage/alpine 로 통일.
# 소스는 벤더링 대신 빌더에서 v4.0.3 태그를 git clone (모노레포 전체 벤더링 회피, 태그 고정).
ARG GIT_TAG=v4.0.3

# ── ui builder (원본 argo-ui stage: yarn 으로 UI 정적 자산 생성) ──────────────────
FROM node:20-alpine AS argo-ui
RUN apk update && apk add --no-cache git
ARG GIT_TAG
WORKDIR /go/src/github.com/argoproj/argo-workflows
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-workflows.git .
RUN YARN_CACHE_FOLDER=/root/.yarn JOBS=max \
    yarn --cwd ui install --network-timeout 1000000
RUN NODE_OPTIONS="--max-old-space-size=2048" JOBS=max \
    yarn --cwd ui build

# ── go builder ──────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS builder
# baseimage/alpine 은 기본 USER 가 비루트 → apk/빌드 위해 root 로 전환
USER root
# 원본 builder 패키지 + 빌드 도구.
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
WORKDIR /go/src/github.com/argoproj/argo-workflows
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-workflows.git .
RUN go mod download
# 원본 argocli-build stage: UI 정적 자산을 임베드 경로에 배치 후 빌드.
RUN mkdir -p ui/dist
COPY --from=argo-ui /go/src/github.com/argoproj/argo-workflows/ui/dist/app ui/dist/app
# make 가 UI 를 재빌드하지 않도록 타임스탬프 갱신 (원본과 동일).
RUN touch ui/dist/app/index.html
# 정적 빌드 (STATIC_FILES=true 로 UI 임베드, CGO_ENABLED=0) — 원본 Makefile 경로와 동일.
RUN STATIC_FILES=true make dist/argo \
    GIT_COMMIT="$(git rev-parse HEAD)" \
    GIT_TAG="${GIT_TAG}" \
    GIT_TREE_STATE=clean

# ── runtime (원본 argocli stage) ─────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/argoproj/argo-workflows
LABEL org.opencontainers.image.description="argocli - Argo Workflows CLI/server (argo)"
LABEL org.opencontainers.image.licenses=Apache-2.0

# 원본 argocli stage 가 distroless 위에 올리던 부가 파일들.
COPY --from=builder /go/src/github.com/argoproj/argo-workflows/hack/ssh_known_hosts /etc/ssh/
COPY --from=builder /go/src/github.com/argoproj/argo-workflows/hack/nsswitch.conf /etc/

# 원본 런타임 stage 의 비루트 UID(8737) 유지 (MustRunAsNonRoot).
USER 8737
WORKDIR /home/argo
COPY --chown=8737 --from=builder /go/src/github.com/argoproj/argo-workflows/dist/argo /bin/

ENTRYPOINT [ "argo" ]
