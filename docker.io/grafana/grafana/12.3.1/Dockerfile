# 원본: docker.io/grafana/grafana:12.3.1  (Grafana OSS)
#   https://github.com/grafana/grafana (tag v12.3.1)
# 원본 base:
#   alpine-base (runtime) : alpine:3.23.0          (alpine / musl 계열)
#   go-builder-base       : golang:1.25.5-alpine
#   js-builder-base       : node:24-alpine
# 계열 매핑:
#   runtime : alpine → baseimage/alpine  (musl 유지 — 원본 런타임이 musl alpine)
#   builder : 빌드 전용 throwaway stage 이므로 upstream pinned base(golang/node) 유지.
#             (출하되는 레이어가 아니라 정책 대상 아님 — argoexec 래핑과 동일한 판단)
# 원본 Dockerfile 은 final stage 가 `FROM ${BASE_IMAGE}` 로 파라미터화되어 있고
# apk 설치를 `grep -i alpine /etc/issue` 로 분기한다. 본 래핑은 그 final stage 를
# baseimage/alpine 위에 그대로 충실히 재현한다(패키지/UID472/glibc shim/ENV/EXPOSE/ENTRYPOINT 보존).
# 소스는 벤더링 대신 빌더에서 v12.3.1 태그를 git clone 후 upstream Makefile 로 빌드.
ARG GIT_TAG=v12.3.1

# ── builder (upstream go+js 빌드: throwaway, upstream pinned base 유지) ──────────
FROM golang:1.25.5-alpine AS go-builder
RUN apk add --no-cache git make bash gcc g++ musl-dev nodejs npm yarn python3
ARG GIT_TAG
WORKDIR /tmp/grafana
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/grafana/grafana.git .
# upstream Makefile 전체 빌드 (go 바이너리 + 프론트엔드 public/). 실패 시 build-go / build-js 분리.
RUN make build

# go-src / js-src 통합 alias (원본 final stage 의 COPY 출처와 동일 디렉터리 보유)
FROM go-builder AS go-src
FROM go-builder AS js-src

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

# glibc support for alpine x86_64 only (원본과 동일)
# 일부 백엔드/플러그인이 glibc 를 필요로 하여 compat blob 를 /lib64 에 심는다.
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
