# 원본: docker.io/grafana/grafana:12.3.1  (Grafana OSS)
#   https://github.com/grafana/grafana (tag v12.3.1, repo 루트 Dockerfile)
# 원본 base:
#   alpine-base (runtime) : alpine:3.23.0          (alpine / musl 계열)
#   go-builder-base       : golang:1.25.5-alpine
#   js-builder-base       : node:24-alpine
# 계열 매핑:
#   runtime : alpine → baseimage/alpine  (musl 유지 — 원본 런타임이 musl alpine)
#   builder : 빌드 전용 throwaway stage 이므로 upstream pinned base(golang/node) 유지.
#             (출하 레이어가 아니라 정책 대상 아님 — argoexec 래핑과 동일한 판단)
# 원본은 js-builder(node) 와 go-builder(golang) 를 분리해서 빌드한다:
#   - js-builder : `yarn install --immutable` 후 `yarn build` → public/ (프론트엔드, arch 무관)
#   - go-builder : `make build-go` → bin/ (백엔드 바이너리, musl)
#   런타임은 디스크의 public/ 을 서빙하므로 바이너리에 임베드되지 않는다(go/js 독립).
# 소스는 벤더링 대신 source stage 에서 v12.3.1 태그를 1회 git clone 후 두 빌더에 COPY.
ARG GIT_TAG=v12.3.1

# ── source (태그 고정 clone 1회) ─────────────────────────────────────────────────
FROM golang:1.25.5-alpine AS source
RUN apk add --no-cache git
ARG GIT_TAG
WORKDIR /tmp/grafana
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/grafana/grafana.git .

# ── js-builder (원본과 동일: node:24-alpine, yarn install → yarn build) ───────────
FROM node:24-alpine AS js-builder
ENV NODE_OPTIONS=--max_old_space_size=8000
ENV NODE_ENV=production
WORKDIR /tmp/grafana
RUN apk add --no-cache make build-base python3
COPY --from=source /tmp/grafana /tmp/grafana
# berry(yarn 4) — 원본과 동일하게 install 후 build. install 없이 build 하면 node_modules 부재로 실패.
RUN yarn install --immutable
RUN yarn build

# ── go-builder (원본과 동일: golang:1.25.5-alpine, make build-go) ─────────────────
FROM golang:1.25.5-alpine AS go-builder
# arm64 빌드용 binutils-gold (golang/go#22040) + 빌드 도구
RUN apk add --no-cache binutils-gold bash gcc g++ make git
WORKDIR /tmp/grafana
COPY --from=source /tmp/grafana /tmp/grafana
RUN go mod download
RUN make build-go GO_BUILD_TAGS=oss WIRE_TAGS=oss

# helpers for COPY --from (원본 go-src / js-src alias)
FROM go-builder AS go-src
FROM js-builder AS js-src

# ── runtime (원본 final stage 를 baseimage/alpine 으로 재현) ─────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL maintainer="Grafana Labs <hello@grafana.com>"
LABEL org.opencontainers.image.source="https://github.com/grafana/grafana"
LABEL org.opencontainers.image.description="Grafana OSS 12.3.1 wrapped onto baseimage/alpine"
LABEL org.opencontainers.image.licenses=AGPL-3.0-only

# baseimage/alpine 은 기본 USER 가 비루트 → apk/디렉터리 생성 위해 root 로 전환 (런타임은 마지막에 472 로 복귀)
USER root

ARG GF_UID="472"
ARG GF_GID="0"

ENV PATH="/usr/share/grafana/bin:$PATH" \
  GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
  GF_PATHS_DATA="/var/lib/grafana" \
  GF_PATHS_HOME="/usr/share/grafana" \
  GF_PATHS_LOGS="/var/log/grafana" \
  GF_PATHS_PLUGINS="/var/lib/grafana/plugins" \
  GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

WORKDIR $GF_PATHS_HOME

# 원본 alpine 분기 패키지 (12.3.1: bubblewrap 없음)
RUN apk add --no-cache ca-certificates bash curl tzdata musl-utils && \
  apk info -vv | sort

# glibc support for alpine x86_64 only (원본과 동일 — 일부 플러그인이 glibc 필요)
ARG GLIBC_VERSION=2.40
RUN if [ `arch` = "x86_64" ]; then \
  wget -qO- "https://dl.grafana.com/glibc/glibc-bin-$GLIBC_VERSION.tar.gz" | tar zxf - -C / \
  usr/glibc-compat/lib/ld-linux-x86-64.so.2 \
  usr/glibc-compat/lib/libc.so.6 \
  usr/glibc-compat/lib/libdl.so.2 \
  usr/glibc-compat/lib/libm.so.6 \
  usr/glibc-compat/lib/libpthread.so.0 \
  usr/glibc-compat/lib/librt.so.1 \
  usr/glibc-compat/lib/libresolv.so.2 && \
  mkdir -p /lib64 && \
  ln -sf /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /lib64; \
  fi

COPY --from=go-src /tmp/grafana/conf ./conf

RUN if [ ! $(getent group "$GF_GID") ]; then \
  addgroup -S -g $GF_GID grafana; \
  fi && \
  GF_GID_NAME=$(getent group $GF_GID | cut -d':' -f1) && \
  mkdir -p "$GF_PATHS_HOME/.aws" && \
  adduser -S -u $GF_UID -G "$GF_GID_NAME" grafana && \
  mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
  "$GF_PATHS_PROVISIONING/dashboards" \
  "$GF_PATHS_PROVISIONING/notifiers" \
  "$GF_PATHS_PROVISIONING/plugins" \
  "$GF_PATHS_PROVISIONING/access-control" \
  "$GF_PATHS_PROVISIONING/alerting" \
  "$GF_PATHS_LOGS" \
  "$GF_PATHS_PLUGINS" \
  "$GF_PATHS_DATA" && \
  cp conf/sample.ini "$GF_PATHS_CONFIG" && \
  cp conf/ldap.toml /etc/grafana/ldap.toml && \
  chown -R "grafana:$GF_GID_NAME" "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" "$GF_PATHS_PROVISIONING" && \
  chmod -R 777 "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" "$GF_PATHS_PROVISIONING"

COPY --from=go-src /tmp/grafana/bin/grafana* /tmp/grafana/bin/*/grafana* ./bin/
COPY --from=js-src /tmp/grafana/public ./public
COPY --from=js-src /tmp/grafana/LICENSE ./

EXPOSE 3000

COPY --from=go-src /tmp/grafana/packaging/docker/run.sh /run.sh

USER "$GF_UID"
ENTRYPOINT [ "/run.sh" ]
