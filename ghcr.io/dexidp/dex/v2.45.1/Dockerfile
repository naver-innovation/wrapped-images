# =============================================================================
# 원본 이미지      : ghcr.io/dexidp/dex:v2.45.1
# 원본 base 이미지 : golang:1.26.0-alpine3.22 (builder) -> alpine:3.23.3 (runtime)
# 계열 매핑        : alpine -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : GOLD A (소스 빌드 -> alpine)
#                   upstream Dockerfile(v2.45.1) 재현: builder 에서 `make release-binary`
#                   로 dex / docker-entrypoint 정적 바이너리 빌드, web/ 에셋과 gomplate,
#                   config.docker.yaml 동봉. base 만 승인된 OCIR baseimage 로 교체.
# =============================================================================

# -----------------------------------------------------------------------------
# builder : dex / docker-entrypoint 정적 바이너리 빌드 (upstream make release-binary)
# -----------------------------------------------------------------------------
FROM golang:1.26.0-alpine3.22 AS builder

USER root

ARG GIT_TAG=v2.45.1
ARG VERSION=2.45.1

RUN apk add --no-cache git make ca-certificates wget gcc libc-dev bash

WORKDIR /usr/local/src
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/dexidp/dex.git dex

WORKDIR /usr/local/src/dex
RUN go mod download

# upstream Makefile release-binary 타깃 재현:
#   go build -o /go/bin/dex            ./cmd/dex
#   go build -o /go/bin/docker-entrypoint ./cmd/docker-entrypoint
RUN make release-binary

# -----------------------------------------------------------------------------
# gomplate : config.docker.yaml 템플릿 렌더링에 사용되는 정적 바이너리 다운로드
#            (upstream Dockerfile 의 gomplate 스테이지 재현)
# -----------------------------------------------------------------------------
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS gomplate

USER root

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ENV GOMPLATE_VERSION=v5.0.0

RUN apk add --no-cache ca-certificates wget \
    && wget -O /usr/local/bin/gomplate \
       "https://github.com/hairyhenderson/gomplate/releases/download/${GOMPLATE_VERSION}/gomplate_${TARGETOS:-linux}-${TARGETARCH:-amd64}${TARGETVARIANT}" \
    && chmod +x /usr/local/bin/gomplate

# -----------------------------------------------------------------------------
# runtime : 승인된 OCIR alpine baseimage
# -----------------------------------------------------------------------------
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/dexidp/dex"
LABEL org.opencontainers.image.description="dex - OpenID Connect (OIDC) and OAuth 2.0 provider wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 가 non-root 이므로 설치/계정 작업 전 root 로 전환
USER root

# dex connector(GitHub/Google 등)는 root CA 가 필요.
# 정적 바이너리 + 일부 cgo 의존(sqlite 등) 호환을 위해 gcompat 동봉 (upstream 동일).
RUN apk add --no-cache ca-certificates gcompat

# upstream 과 동일한 dex 계정/그룹(1001:1001) 보장 (idempotent)
RUN addgroup -S -g 1001 dex 2>/dev/null || true \
    && adduser -S -u 1001 -G dex dex 2>/dev/null || true \
    && mkdir -p /var/dex /etc/dex \
    && chown -R 1001:1001 /var/dex /etc/dex

# 빌드 산출물 / 에셋 배치 (upstream 경로 그대로)
COPY --from=builder /go/bin/dex /usr/local/bin/dex
COPY --from=builder /go/bin/docker-entrypoint /usr/local/bin/docker-entrypoint
COPY --from=builder /usr/local/src/dex/web /srv/dex/web
COPY --from=builder --chown=1001:1001 /usr/local/src/dex/config.docker.yaml /etc/dex/config.docker.yaml
COPY --from=gomplate /usr/local/bin/gomplate /usr/local/bin/gomplate

EXPOSE 5556

# upstream 의 nonroot USER 복원
USER 1001:1001

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["dex", "serve", "/etc/dex/config.docker.yaml"]
