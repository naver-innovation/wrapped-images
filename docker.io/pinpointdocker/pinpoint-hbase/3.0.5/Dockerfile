# 원본: docker.io/pinpointdocker/pinpoint-hbase:3.0.5
#   https://github.com/pinpoint-apm/pinpoint (tag v3.0.5, path: hbase/Dockerfile)
# 원본 base:
#   openjdk:8u342-slim  (Debian slim + OpenJDK 8 JRE) — 단일 stage(빌드 시 HBase 다운로드, 런타임 동일 이미지)
# 계열 매핑:
#   런타임 = Java 8 + HBase → baseimage/ubuntu:24.04 로 매핑.
#   ⚠️ Ubuntu 24.04(noble) 기본 저장소에는 openjdk-8 이 없음(Java 8 제거됨).
#      → Adoptium(Temurin) 8 JRE 를 HTTPS apt 저장소로 설치하여 원본 JRE 8 동등성 유지.
# 변경점(원본 대비):
#   - FROM openjdk:8u342-slim → baseimage/ubuntu:24.04 + Temurin 8 JRE
#   - HBASE_REPOSITORY 의 죽은 HTTP 미러(apache.mirrors.pair.com)를 HTTPS archive 로 일원화
#   - baseimage/ubuntu 기본 USER 가 비루트 → apt/빌드 위해 USER root 로 전환(원본도 root 실행이라 동등)
#   - COPY 경로/ENV/VOLUME/CMD 는 원본과 동일하게 유지
# ⚠️ pinpoint 이미지는 amd64 전용 → 빌드 매트릭스를 linux/amd64 로 제한할 것.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

# baseimage/ubuntu 는 기본 USER 가 비루트 → apt/파일 설치 위해 root 로 전환
USER root

ARG HBASE_VERSION=${HBASE_VERSION:-2.2.6}

# 원본은 openjdk:8u342-slim 의 JRE 8 을 그대로 사용 → noble 에 없는 Java 8 을 Adoptium HTTPS 저장소로 보강.
# GPG 키는 HTTPS 로 수신해 keyring 에 저장(원본 정책: HTTP/GPG 키서버 대신 HTTPS).
ENV JAVA_HOME=/usr/lib/jvm/temurin-8-jre-amd64
RUN apt-get update \
    && apt-get install --no-install-recommends -y curl ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" \
        > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y temurin-8-jre \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 원본은 HTTP 1차 미러(죽음) → HTTP archive 폴백 구조. HTTPS archive 단일 소스로 변경.
ENV HBASE_REPOSITORY=https://archive.apache.org/dist/hbase
ENV HBASE_SUB_REPOSITORY=https://archive.apache.org/dist/hbase

ENV BASE_DIR=/opt/hbase
ENV HBASE_HOME=${BASE_DIR}/hbase-${HBASE_VERSION}

COPY scripts/hbase-create.hbase ${BASE_DIR}/hbase-create.hbase
COPY hbase-docker/Dockerfiles/configure-hbase.sh /usr/local/bin/configure-hbase.sh
COPY hbase-docker/Dockerfiles/check-table.sh /usr/local/bin/check-table.sh
COPY hbase-docker/Dockerfiles/initialize-hbase.sh /usr/local/bin/initialize-hbase.sh

RUN chmod a+x /usr/local/bin/initialize-hbase.sh \
    && chmod a+x /usr/local/bin/check-table.sh \
    && chmod a+x /usr/local/bin/configure-hbase.sh

RUN mkdir -p ${BASE_DIR} \
    && curl -fSL "${HBASE_REPOSITORY}/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz" -o ${BASE_DIR}/hbase.tar.gz \
       || curl -fSL "${HBASE_SUB_REPOSITORY}/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz" -o ${BASE_DIR}/hbase.tar.gz \
    && tar xfvz ${BASE_DIR}/hbase.tar.gz -C ${BASE_DIR} \
    && rm ${BASE_DIR}/hbase.tar.gz

COPY hbase-docker/Dockerfiles/hbase-site.xml ${HBASE_HOME}/conf/hbase-site.xml
COPY hbase-docker/Dockerfiles/hbase-env.sh ${HBASE_HOME}/conf/hbase-env.sh

VOLUME ["/home/pinpoint/hbase", "/home/pinpoint/zookeeper"]

CMD /usr/local/bin/initialize-hbase.sh && tail -f /dev/null
