# 원본: docker.io/curlimages/curl:7.85.0
#   https://github.com/curl/curl-docker (commit 57413e2 "bump to curl 7.85.0", alpine/latest/Dockerfile)
#   ※ curl-docker 리포는 git tag 를 두지 않으므로 7.85.0 릴리스 커밋(57413e2)이 기준.
#     Docker Hub 퍼블리시 이미지(curlimages/curl:7.85.0) config/layer 와 동작 일치 확인.
# 원본 base:
#   builder  : alpine:3.15.4  (alpine / musl 계열)
#   runtime  : alpine:3.15.4  (alpine / musl 계열)
# 계열 매핑: alpine → baseimage/alpine  (musl 유지 — curl 바이너리/libcurl.so 가 musl ABI 링크, glibc 계열 교체 불가)
# 원본은 curl 을 소스 빌드(curl-7_85_0 태그)하여 libcurl.so + curl 바이너리만 런타임에 복사한다.
#   원본 builder 의 vendored 소스 트리(COPY "curl" /src/curl)를 태그 고정 git clone 으로 대체(벤더링 회피).
# entrypoint.sh 는 원본과 동일 내용을 인라인(추가 벤더 파일 불필요).
ARG CURL_RELEASE_TAG=curl-7_85_0
ARG CURL_RELEASE_VERSION=7_85_0
ARG CURL_GIT_REPO=https://github.com/curl/curl.git

# ── builder ───────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS builder
# baseimage/alpine 은 기본 USER 가 비루트 → apk/빌드 위해 root 로 전환
USER root

ARG CURL_RELEASE_TAG
ARG CURL_GIT_REPO
ARG CURL_CONFIGURE_OPTION

# 원본 builder 패키지 + git(clone 용). 나머지는 원본과 동일.
RUN apk add --no-cache \
        git \
        libssh2 libssh2-dev libssh2-static \
        autoconf automake build-base \
        groff openssl curl-dev \
        python3 python3-dev \
        libtool curl stunnel perl \
        nghttp2 brotli brotli-dev

# 태그 고정 소스 체크아웃 (원본의 vendored COPY "curl" 대체)
RUN git clone --depth 1 --branch ${CURL_RELEASE_TAG} ${CURL_GIT_REPO} /src/curl
WORKDIR /src/curl

# 원본과 동일: curl.se 의 CA 번들 취득
RUN curl https://curl.haxx.se/ca/cacert.pem -L -o /cacert.pem

# 원본과 동일한 빌드 경로 (make test 는 원본에서 주석 처리됨)
RUN ./buildconf && \
    autoreconf -vif && \
    ./configure ${CURL_CONFIGURE_OPTION} && \
    make -j"$(nproc)" && \
    make DESTDIR="/alpine/" install -j"$(nproc)"

# ── runtime ─────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/curl/curl-docker
LABEL org.opencontainers.image.description="curl - command line tool and library for transferring data with URLs"
LABEL org.opencontainers.image.licenses=MIT
# 원본 LABEL 보존
LABEL Maintainer="James Fuller <jim.fuller@webcomposite.com>"
LABEL Name="curl"

ARG CURL_RELEASE_TAG
ARG CURL_RELEASE_VERSION
ARG CURL_GIT_REPO
ENV CURL_VERSION=${CURL_RELEASE_VERSION}
ENV CURL_RELEASE_TAG=${CURL_RELEASE_TAG}
ENV CURL_GIT_REPO=${CURL_GIT_REPO}

# baseimage/alpine 은 기본 USER 가 비루트 → apk/유저생성/심볼릭링크 위해 root 로 전환 (런타임은 마지막에 curl_user 로 복귀)
USER root

# 원본 런타임 의존 패키지
RUN apk upgrade && \
    apk add --no-cache brotli brotli-dev libssh2 nghttp2-dev && \
    rm -fr /var/cache/apk/*

# 원본과 동일: 비루트 curl_user / curl_group (adduser -S 시스템 계정)
RUN addgroup -S curl_group && adduser -S curl_user -G curl_group

# builder 에서 빌드한 curl 설치물 복사 (원본과 동일 경로)
COPY --from=builder /alpine/usr/local/lib/libcurl.so.4.8.0 /usr/lib/
COPY --from=builder /alpine/usr/local/bin/curl /usr/bin/curl
COPY --from=builder /alpine/usr/local/include/curl /usr/include/curl

# 원본과 동일한 명시적 심볼릭 링크 (libcurl.so.4.8.0 == curl 7.85.0 soname)
RUN ln -s /usr/lib/libcurl.so.4.8.0 /usr/lib/libcurl.so.4 && \
    ln -s /usr/lib/libcurl.so.4 /usr/lib/libcurl.so

# CA 번들
COPY --from=builder /cacert.pem /cacert.pem
ENV CURL_CA_BUNDLE="/cacert.pem"

# 원본 entrypoint.sh 동일 내용 인라인 (MIT, James Fuller)
RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -e' \
    'if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ]; then' \
    '  set -- curl "$@"' \
    'fi' \
    'exec "$@"' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

USER curl_user
CMD ["curl"]
ENTRYPOINT ["/entrypoint.sh"]
