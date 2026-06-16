# 원본: docker.io/clickhouse/clickhouse-keeper:26.3.12.3
#   https://github.com/ClickHouse/ClickHouse (tag v26.3.12.3-lts, docker/keeper/Dockerfile)
# 원본 base:
#   upstream 의 canonical keeper Dockerfile 은 glibc-donor(ubuntu:22.04) → 최종 FROM alpine 구조다.
#   alpine 최종 stage 에 ubuntu 의 glibc(.so) 를 COPY 해 넣어 동작시키는 방식.
# 계열 매핑:
#   alpine 최종 stage 의 glibc-donor shim 은 "alpine 위에서 glibc 바이너리를 돌리기 위한" 장치이므로,
#   glibc 계열 base 인 baseimage/ubuntu:24.04 로 매핑하면 donor stage 가 불필요/유해(우분투 자체 glibc 덮어쓰기)해진다.
#   따라서 glibc-donor stage 는 제거하고 단일 런타임 stage 로 매핑한다(형제 PR clickhouse-server 와 동일 base).
#   alpine 전용 명령(addgroup -S / adduser -S / apk add su-exec)은 ubuntu 등가물로 보정한다.
# clickhouse-keeper 패키지는 upstream 그대로 packages.clickhouse.com/tgz 에서 HTTPS 로 받고 sha512 로 검증한다
# (deb repo + GPG 가 아니라 tgz + sha512 검증 방식 → 별도 keyserver/GPG import 단계 없음, HTTPS only 충족).
# entrypoint.sh 는 upstream tag 에서 그대로 벤더링한다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/ClickHouse/ClickHouse
LABEL org.opencontainers.image.description="ClickHouse Keeper - coordination service (ZooKeeper-compatible)"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/ubuntu 기본 USER 가 비루트일 수 있음 → apt/설치/chown 위해 root 로 전환.
# (upstream keeper 이미지는 entrypoint 가 chown 후 gosu/su-exec 로 clickhouse(uid 101) 로 드롭하므로
#  최종 USER 는 root 로 유지 — upstream 동작과 동일.)
USER root

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml

ARG DEBIAN_FRONTEND=noninteractive

COPY entrypoint.sh /entrypoint.sh

# lts / testing / prestable / etc
ARG REPO_CHANNEL="lts"
ARG REPOSITORY="https://packages.clickhouse.com/tgz/${REPO_CHANNEL}"
ARG VERSION="26.3.12.3"
ARG PACKAGES="clickhouse-keeper"
ARG DIRECT_DOWNLOAD_URLS=""

# upstream 이 tgz 설치에 쓰던 도구(wget/tar/sha512sum)와 런타임 의존(tzdata, su-exec 대체 gosu, bash)을
# ubuntu apt 로 설치. su-exec 은 ubuntu 에 없으므로 gosu 로 대체(entrypoint.sh 가 둘 다 지원).
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        wget \
        tar \
        gzip \
        coreutils \
        bash \
        tzdata \
        gosu \
        locales \
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

# user/group precreated explicitly with fixed uid/gid on purpose.
# It is especially important for rootless containers: in that case entrypoint
# can't do chown and owners of mounted volumes should be configured externally.
# We do that in advance at the begining of Dockerfile before any packages will be
# installed to prevent picking those uid / gid by some unrelated software.
# The same uid / gid (101) is used both for alpine and ubuntu.
# baseimage 가 깨끗하지 않을 수 있으므로 group/user 생성은 멱등 처리(|| true).
# (upstream alpine 의 addgroup -S / adduser -S 를 ubuntu 의 groupadd -r / useradd -r 로 보정.)
ARG DEFAULT_UID="101"
ARG DEFAULT_GID="101"
RUN (groupadd -r -g "${DEFAULT_GID}" clickhouse || true) \
    && (useradd -r -g clickhouse -u "${DEFAULT_UID}" -d /var/lib/clickhouse -s /bin/bash -c "ClickHouse keeper" clickhouse || true)

ARG TARGETARCH
RUN arch=${TARGETARCH:-amd64} \
    && cd /tmp && rm -f /tmp/*tgz && rm -f /tmp/*tgz.sha512 |: \
    && if [ -n "${DIRECT_DOWNLOAD_URLS}" ]; then \
        echo "installing from provided urls with tgz packages: ${DIRECT_DOWNLOAD_URLS}" \
        && for url in $DIRECT_DOWNLOAD_URLS; do \
            echo "Get ${url}" \
            && wget -c -q "$url" \
        ; done \
    else \
        for package in ${PACKAGES}; do \
            cd /tmp \
            && echo "Get ${REPOSITORY}/${package}-${VERSION}-${arch}.tgz" \
            && wget -c -q "${REPOSITORY}/${package}-${VERSION}-${arch}.tgz" \
            && wget -c -q "${REPOSITORY}/${package}-${VERSION}-${arch}.tgz.sha512" \
        ; done \
    fi \
    && cat *.tgz.sha512 | sha512sum -c \
    && for file in *.tgz; do \
        if [ -f "$file" ]; then \
            echo "Unpacking $file"; \
            tar xvzf "$file" --strip-components=1 -C /; \
        fi \
    ; done \
    && rm /tmp/*.tgz /install -r \
    && chmod +x /entrypoint.sh \
    && cp /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "UTC" > /etc/timezone

RUN locale-gen en_US.UTF-8

ARG DEFAULT_CONFIG_DIR="/etc/clickhouse-keeper"
ARG DEFAULT_DATA_DIR="/var/lib/clickhouse-keeper"
ARG DEFAULT_LOG_DIR="/var/log/clickhouse-keeper"
# baseimage 가 깨끗하지 않을 수 있으므로 mkdir -p 로 멱등 처리(upstream 도 -p 사용).
RUN clickhouse-keeper --version \
    && mkdir -p "${DEFAULT_DATA_DIR}" "${DEFAULT_LOG_DIR}" "${DEFAULT_CONFIG_DIR}" \
    && chown clickhouse:clickhouse "${DEFAULT_DATA_DIR}" \
    && chown root:clickhouse "${DEFAULT_LOG_DIR}" \
    && chmod ugo+Xrw -R "${DEFAULT_DATA_DIR}" "${DEFAULT_LOG_DIR}" "${DEFAULT_CONFIG_DIR}"

# /var/lib/clickhouse is necessary due to the current default configuration for Keeper
VOLUME "${DEFAULT_DATA_DIR}" /var/lib/clickhouse
EXPOSE 2181 10181 44444 9181

ENTRYPOINT ["/entrypoint.sh"]
