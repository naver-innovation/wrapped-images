# 원본: docker.io/library/zookeeper:3.9.3  (Apache ZooKeeper 공식 라이브러리 이미지)
#   https://github.com/31z4/zookeeper-docker (tag 3.9.3, 3.9.3/Dockerfile)
# 원본 base: FROM eclipse-temurin:17-jre-jammy  (Ubuntu 22.04 jammy + Temurin JRE 17, glibc 계열)
# 계열 매핑: ubuntu(jammy) → baseimage/ubuntu:24.04  (glibc/Debian 계열 유지)
#   - baseimage/ubuntu 에는 JRE 가 없으므로 apt 로 openjdk-17-jre-headless 를 보정 설치한다.
#   - 단일 stage 이므로 런타임 FROM 만 교체한다(상위 stage 없음).
# bitnamilegacy/zookeeper:3.9.3-debian-12-r21 대체용 (issue #8).
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

# baseimage/ubuntu 는 기본 USER 가 비루트 → apt/빌드 위해 root 로 전환 (런타임은 마지막에 zookeeper 로 복귀)
USER root

ENV ZOO_CONF_DIR=/conf \
    ZOO_DATA_DIR=/data \
    ZOO_DATA_LOG_DIR=/datalog \
    ZOO_LOG_DIR=/logs \
    ZOO_TICK_TIME=2000 \
    ZOO_INIT_LIMIT=5 \
    ZOO_SYNC_LIMIT=2 \
    ZOO_AUTOPURGE_PURGEINTERVAL=0 \
    ZOO_AUTOPURGE_SNAPRETAINCOUNT=3 \
    ZOO_MAX_CLIENT_CNXNS=60 \
    ZOO_STANDALONE_ENABLED=true \
    ZOO_ADMINSERVER_ENABLED=true

# Add a user with an explicit UID/GID and create necessary directories
# baseimage/ubuntu:24.04 는 uid/gid 1000 을 기본 'ubuntu' 유저/그룹이 선점하고 있어
# zookeeper 를 1000 으로 만들면 useradd 가 실패하고 이후 chown 도 깨진다(로컬 빌드로 확인).
# → 충돌하는 ubuntu 유저/그룹을 먼저 제거해 1000 을 비운 뒤 zookeeper(1000) 생성. 멱등 처리.
RUN set -eux; \
    (userdel -r ubuntu 2>/dev/null || true); \
    (groupdel ubuntu 2>/dev/null || true); \
    (getent group zookeeper >/dev/null || groupadd -r zookeeper --gid=1000); \
    (getent passwd zookeeper >/dev/null || useradd -r -g zookeeper --uid=1000 zookeeper); \
    mkdir -p "$ZOO_DATA_LOG_DIR" "$ZOO_DATA_DIR" "$ZOO_CONF_DIR" "$ZOO_LOG_DIR"; \
    chown zookeeper:zookeeper "$ZOO_DATA_LOG_DIR" "$ZOO_DATA_DIR" "$ZOO_CONF_DIR" "$ZOO_LOG_DIR"

# Install required packges
#   - 원본 eclipse-temurin 베이스가 기본 제공하던 JRE 를 baseimage/ubuntu 에는 직접 설치(openjdk-17-jre-headless).
#   - netcat 은 ubuntu 24.04 에서 netcat-openbsd 로 제공.
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        dirmngr \
        gosu \
        gnupg \
        netcat-openbsd \
        openjdk-17-jre-headless \
        wget; \
    rm -rf /var/lib/apt/lists/*; \
# Verify that gosu binary works
    gosu nobody true

ARG GPG_KEY=3F7A1D16FA4217B1DC75E1C9FFE35B7F15DFA1BA
ARG SHORT_DISTRO_NAME=zookeeper-3.9.3
ARG DISTRO_NAME=apache-zookeeper-3.9.3-bin

# Download Apache Zookeeper, verify its PGP signature, untar and clean up
#   - GPG: 키서버 recv 는 CI 에서 차단/불안정하므로, Apache ZooKeeper 공식 KEYS 를 HTTPS 로 받아 import 한다.
#     서명자 키 지문(GPG_KEY)을 import 후 명시적으로 신뢰/검증한다(원본과 동일 fingerprint).
#   - tarball/asc 는 원본 ddist 다중 미러 폴백을 유지하되, 3.9.3 은 current 미러에서 내려갔으므로
#     실제로는 archive.apache.org 폴백으로 확정 다운로드된다.
RUN set -eux; \
    ddist() { \
        local f="$1"; shift; \
        local distFile="$1"; shift; \
        local success=; \
        local distUrl=; \
        for distUrl in \
            'https://www.apache.org/dyn/closer.cgi?action=download&filename=' \
            https://downloads.apache.org/ \
            https://archive.apache.org/dist/ \
        ; do \
            if wget -q -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
                success=1; \
                break; \
            fi; \
        done; \
        [ -n "$success" ]; \
    }; \
    ddist "$DISTRO_NAME.tar.gz" "zookeeper/$SHORT_DISTRO_NAME/$DISTRO_NAME.tar.gz"; \
    ddist "$DISTRO_NAME.tar.gz.asc" "zookeeper/$SHORT_DISTRO_NAME/$DISTRO_NAME.tar.gz.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    wget -qO "$GNUPGHOME/KEYS" https://downloads.apache.org/zookeeper/KEYS; \
    gpg --batch --import "$GNUPGHOME/KEYS"; \
    gpg --batch --list-keys "$GPG_KEY"; \
    gpg --batch --verify "$DISTRO_NAME.tar.gz.asc" "$DISTRO_NAME.tar.gz"; \
    tar -zxf "$DISTRO_NAME.tar.gz"; \
    mv "$DISTRO_NAME/conf/"* "$ZOO_CONF_DIR"; \
    rm -rf "$GNUPGHOME" "$DISTRO_NAME.tar.gz" "$DISTRO_NAME.tar.gz.asc"; \
    chown -R zookeeper:zookeeper "/$DISTRO_NAME"

WORKDIR $DISTRO_NAME
VOLUME ["$ZOO_DATA_DIR", "$ZOO_DATA_LOG_DIR", "$ZOO_LOG_DIR"]

EXPOSE 2181 2888 3888 8080

ENV PATH=$PATH:/$DISTRO_NAME/bin \
    ZOOCFGDIR=$ZOO_CONF_DIR

COPY docker-entrypoint.sh /

# 원본 이미지는 root 로 entrypoint 를 실행하여 chown 후 gosu 로 zookeeper 로 강등한다.
# baseimage 정책상 기본 USER 는 비루트여야 하므로 zookeeper(uid 1000)로 복귀한다.
# 이 경우 entrypoint 의 root 분기(chown→gosu)는 건너뛰고 zookeeper 권한으로 직접 구동되며,
# 데이터 디렉터리는 위에서 이미 zookeeper 소유로 생성되어 정상 동작한다.
USER zookeeper

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["zkServer.sh", "start-foreground"]
