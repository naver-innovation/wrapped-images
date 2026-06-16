# 원본: docker.io/bats/bats:1.13.0
#   https://github.com/bats-core/bats-core (tag v1.13.0, Dockerfile)
# 원본 base:
#   bash:latest  (현재 docker.io/bash 는 alpine/musl 계열이며 bats 1.13.0 이미지도 Alpine 3.23 기반)
# 계열 매핑: alpine → baseimage/alpine
# 보정 사항:
#   - baseimage/alpine 은 기본 USER 가 비루트 → apk/설치 위해 USER root 로 전환.
#   - 원본의 COPY . /opt/bats 는 tag 고정 release tarball 다운로드로 대체.
#   - 원본이 설치하는 bats-support/file/assert/detik 버전과 tini/parallel/ncurses 동작을 유지.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL maintainer="Bats-core Team"
LABEL org.opencontainers.image.authors="Bats-core Team"
LABEL org.opencontainers.image.title="Bats"
LABEL org.opencontainers.image.description="Bash Automated Testing System"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/bats/bats"
LABEL org.opencontainers.image.source="https://github.com/bats-core/bats-core"
LABEL org.opencontainers.image.licenses=MIT

ARG BATS_VERSION=1.13.0
ARG LIBS_VER_SUPPORT=0.3.0
ARG LIBS_VER_FILE=0.4.0
ARG LIBS_VER_ASSERT=2.1.0
ARG LIBS_VER_DETIK=1.3.2

USER root

RUN set -eux; \
    apk add --no-cache bash ca-certificates ncurses parallel tar tini wget; \
    mkdir -p /code /opt /usr/lib/bats "$HOME/.parallel"; \
    touch "$HOME/.parallel/will-cite"; \
    wget -qO /tmp/bats-core.tar.gz "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz"; \
    tar -xzf /tmp/bats-core.tar.gz -C /opt; \
    mv "/opt/bats-core-${BATS_VERSION}" /opt/bats; \
    rm -f /tmp/bats-core.tar.gz; \
    for item in \
        "support:${LIBS_VER_SUPPORT}" \
        "file:${LIBS_VER_FILE}" \
        "assert:${LIBS_VER_ASSERT}" \
        "detik:${LIBS_VER_DETIK}"; do \
      name="${item%%:*}"; \
      version="${item#*:}"; \
      tmp="/tmp/bats-${name}"; \
      mkdir -p "$tmp"; \
      wget -qO "/tmp/bats-${name}.tar.gz" "https://github.com/bats-core/bats-${name}/archive/refs/tags/v${version}.tar.gz"; \
      tar -xzf "/tmp/bats-${name}.tar.gz" -C "$tmp" --strip-components 1; \
      if [ "$name" = "detik" ]; then \
        mkdir -p "/usr/lib/bats/bats-${name}"; \
        cp "$tmp"/lib/*.bash "/usr/lib/bats/bats-${name}/"; \
      else \
        mkdir -p "/usr/lib/bats/bats-${name}/src"; \
        cp "$tmp/load.bash" "/usr/lib/bats/bats-${name}/load.bash"; \
        cp "$tmp"/src/*.bash "/usr/lib/bats/bats-${name}/src/"; \
      fi; \
      rm -rf "$tmp" "/tmp/bats-${name}.tar.gz"; \
    done; \
    ln -sf /opt/bats/bin/bats /usr/local/bin/bats; \
    ln -sf "$(command -v tini)" /tini

WORKDIR /code/

ENTRYPOINT ["/tini", "--", "/bin/bash", "/usr/local/bin/bats"]
