# 원본: docker.io/clickhouse/clickhouse-server:26.3.12.3
#   https://github.com/ClickHouse/ClickHouse (tag v26.3.12.3-lts, docker/server/Dockerfile.ubuntu)
# 원본 base: FROM ubuntu:22.04  (debian/ubuntu glibc 계열)
# 계열 매핑: ubuntu → baseimage/ubuntu:24.04  (glibc 계열 유지, apt 그대로)
# 단일 런타임 이미지(빌드 전용 stage 없음) → 런타임 FROM 만 교체.
# entrypoint.sh / docker_related_config.xml 은 upstream tag 에서 그대로 벤더링.
# upstream 의 keyserver(hkp://) GPG 수신을 vendor HTTPS 키 import + 지문 고정으로 대체(HTTPS only).
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/ClickHouse/ClickHouse
LABEL org.opencontainers.image.description="ClickHouse Server - real-time analytical DBMS"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/ubuntu 기본 USER 가 비루트일 수 있음 → apt/설치 위해 root 로 전환.
# (upstream clickhouse 이미지는 entrypoint 가 chown 후 clickhouse(uid 101) 로 드롭하므로
#  최종 USER 는 root 로 유지 — upstream 동작과 동일.)
USER root

# see https://github.com/moby/moby/issues/4032#issuecomment-192327844
ARG DEBIAN_FRONTEND=noninteractive

# ARG for quick switch to a given ubuntu mirror
ARG apt_archive="http://archive.ubuntu.com"

# user/group precreated explicitly with fixed uid/gid on purpose.
# It is especially important for rootless containers: in that case entrypoint
# can't do chown and owners of mounted volumes should be configured externally.
# We do that in advance at the begining of Dockerfile before any packages will be
# installed to prevent picking those uid / gid by some unrelated software.
# The same uid / gid (101) is used both for alpine and ubuntu.
# baseimage 가 깨끗하지 않을 수 있으므로 group/user 생성은 멱등 처리(|| true).
RUN sed -i "s|http://archive.ubuntu.com|${apt_archive}|g" /etc/apt/sources.list \
    && (groupadd -r clickhouse --gid=101 || true) \
    && (useradd -r -g clickhouse --uid=101 --home-dir=/var/lib/clickhouse --shell=/bin/bash clickhouse || true) \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        busybox \
        ca-certificates \
        locales \
        tzdata \
        wget \
    && busybox --install -s \
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

ARG REPO_CHANNEL="lts"
ARG REPOSITORY="deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb ${REPO_CHANNEL} main"
ARG VERSION="26.3.12.3"
ARG PACKAGES="clickhouse-client clickhouse-server clickhouse-common-static"

# ClickHouse 공개 서명키 — upstream 은 keyserver(hkp://) 로 받지만 보안 정책상 HTTPS only.
# vendor 공식 HTTPS 키 URL 에서 받아 import 하고, upstream 이 고정하던 지문과 일치하는지 검증한다.
#   signer      : ClickHouse <packages@clickhouse.com>
#   fingerprint : 3A9EA1193A97B548BE1457D48919F6BD2B48D754
ARG CLICKHOUSE_KEY_URL="https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key"
ARG CLICKHOUSE_KEY_FINGERPRINT="3A9EA1193A97B548BE1457D48919F6BD2B48D754"

# A fallback to installation from ClickHouse repository
# It works unless the clickhouse binary already exists
RUN clickhouse local -q 'SELECT 1' >/dev/null 2>&1 && exit 0 || : \
    ; apt-get update \
    && apt-get install --yes --no-install-recommends \
        dirmngr \
        gnupg2 \
    && mkdir -p /etc/apt/sources.list.d /usr/share/keyrings \
    && GNUPGHOME=$(mktemp -d) \
    && ( set -e; \
        wget --progress=bar:force:noscroll -O "$GNUPGHOME/clickhouse.key" "${CLICKHOUSE_KEY_URL}"; \
        GNUPGHOME="$GNUPGHOME" gpg --batch --import "$GNUPGHOME/clickhouse.key"; \
        GNUPGHOME="$GNUPGHOME" gpg --batch --list-keys --with-colons --fingerprint \
            | awk -F: '/^fpr:/ {print $10}' | grep -qx "${CLICKHOUSE_KEY_FINGERPRINT}"; \
        GNUPGHOME="$GNUPGHOME" gpg --batch --no-default-keyring \
            --keyring /usr/share/keyrings/clickhouse-keyring.gpg \
            --import "$GNUPGHOME/clickhouse.key" \
    ) \
    && rm -rf "$GNUPGHOME" \
    && chmod +r /usr/share/keyrings/clickhouse-keyring.gpg \
    && echo "${REPOSITORY}" > /etc/apt/sources.list.d/clickhouse.list \
    && echo "installing from repository: ${REPOSITORY}" \
    && apt-get update \
    && for package in ${PACKAGES}; do \
        packages="${packages} ${package}=${VERSION}" \
    ; done \
    && apt-get install --yes --no-install-recommends ${packages} || exit 1 \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/cache/debconf \
        /tmp/* \
    && apt-get autoremove --purge -yq dirmngr gnupg2 \
    && chmod ugo+Xrw -R /etc/clickhouse-server /etc/clickhouse-client
# The last chmod is here to make the next one is No-op in docker official library Dockerfile

# post install
# we need to allow "others" access to clickhouse folder, because docker container
# can be started with arbitrary uid (openshift usecase)
RUN clickhouse-local -q 'SELECT * FROM system.build_options' \
    && mkdir -p /var/lib/clickhouse /var/log/clickhouse-server /etc/clickhouse-server /etc/clickhouse-client \
    && chmod ugo+Xrw -R /var/lib/clickhouse /var/log/clickhouse-server /etc/clickhouse-server /etc/clickhouse-client

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV TZ=UTC

RUN mkdir -p /docker-entrypoint-initdb.d

COPY docker_related_config.xml /etc/clickhouse-server/config.d/
COPY entrypoint.sh /entrypoint.sh

EXPOSE 9000 8123 9009
VOLUME /var/lib/clickhouse

ENV CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml

ENTRYPOINT ["/entrypoint.sh"]
