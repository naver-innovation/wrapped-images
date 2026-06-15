# 원본: quay.io/argoproj/argoexec:v4.0.3
#   https://github.com/argoproj/argo-workflows (tag v4.0.3, target stage: argoexec)
# 원본 base:
#   builder  : golang:1.25.7-alpine3.23        (alpine / musl 계열)
#   runtime  : gcr.io/distroless/static-debian13  (정적 바이너리 base)
# 계열 매핑:
#   builder  : alpine → baseimage/alpine  (musl 유지)
#   runtime  : distroless/static 는 CGO_ENABLED=0 정적 Go 바이너리 base → 허용 base 아무거나 가능.
#              빌더가 alpine 이고 바이너리가 완전 정적이므로 baseimage/alpine 로 통일(최소 크기·musl 일관성).
# 소스는 벤더링 대신 빌더에서 v4.0.3 태그를 git clone (모노레포 전체 벤더링 회피, 태그 고정).
ARG GIT_TAG=v4.0.3

# ── builder ───────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS builder
# baseimage/alpine 은 기본 USER 가 비루트 → apk/빌드 위해 root 로 전환
USER root
# 원본 builder 패키지 + 빌드 도구. mailcap 은 런타임 /etc/mime.types 제공용.
RUN apk add --no-cache \
    git \
    make \
    ca-certificates \
    wget \
    curl \
    gcc \
    libc-dev \
    bash \
    mailcap \
    go

ARG GIT_TAG
WORKDIR /go/src/github.com/argoproj/argo-workflows
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-workflows.git .
RUN go mod download
# 정적 빌드 (CGO_ENABLED=0 -extldflags -static) — 원본 Makefile 의 linux 빌드 경로와 동일.
RUN make dist/argoexec \
    GIT_COMMIT="$(git rev-parse HEAD)" \
    GIT_TAG="${GIT_TAG}" \
    GIT_TREE_STATE=clean

# ── runtime (원본 argoexec-base + argoexec stage 통합) ──────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/argoproj/argo-workflows
LABEL org.opencontainers.image.description="argoexec - Argo Workflows executor"
LABEL org.opencontainers.image.licenses=Apache-2.0

# 원본 argoexec-base 가 distroless 위에 올리던 부가 파일들.
COPY --from=builder /etc/mime.types /etc/mime.types
COPY --from=builder /go/src/github.com/argoproj/argo-workflows/hack/ssh_known_hosts /etc/ssh/
COPY --from=builder /go/src/github.com/argoproj/argo-workflows/hack/nsswitch.conf /etc/

# 원본 런타임 stage 의 비루트 UID(8737) 유지 (MustRunAsNonRoot).
USER 8737
COPY --chown=8737 --from=builder /go/src/github.com/argoproj/argo-workflows/dist/argoexec /bin/

ENTRYPOINT [ "argoexec" ]
