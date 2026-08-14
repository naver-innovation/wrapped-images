# 원본           : docker.io/pinpointdocker/pinpoint-hbase:3.1.0
# 원본 Dockerfile : https://github.com/pinpoint-apm/pinpoint (tag v3.1.0, path: hbase/Dockerfile)
#                   pinpoint CI(.github/workflows/create-dockerfiles.yml)의
#                   `mvn docker:build -pl hbase` 로 빌드된다.
# 원본 base       : openjdk:8u342-slim (Debian slim + OpenJDK 8) — builder / 런타임 2 스테이지
# 계열 매핑       : debian(glibc) → baseimage/ubuntu:24.04
#                   ⚠️ noble 기본 저장소에는 Java 8 이 없다(제거됨) → Adoptium(Temurin) 8 JRE 를
#                   HTTPS apt 저장소로 설치해 원본 JRE 8 동등성을 유지한다.
# 원본 런타임 계약(docker inspect 실측):
#                   User=""(=root), WorkingDir=/opt/hbase, ENTRYPOINT 없음,
#                   Cmd=["/bin/sh","-c","/usr/local/bin/initialize-hbase.sh && tail -f /dev/null"],
#                   Volumes=/home/pinpoint/hbase · /home/pinpoint/zookeeper, ExposedPorts 없음,
#                   ENV JAVA_HOME=/usr/local/openjdk-8, LANG=C.UTF-8,
#                       BASE_DIR=/opt/hbase, HBASE_HOME=/opt/hbase/hbase-2.2.6
#
# 변경점(원본 대비)
#   - 두 스테이지의 FROM 을 모두 승인 base 로 교체. builder 는 curl/tar 만 쓰고 Java 가 필요 없어
#     openjdk:8u342-slim 을 끌어올 이유가 없다.
#   - Java 8 = Temurin 8 JRE(Adoptium HTTPS apt). 설치 경로를 /usr/local/openjdk-8 로 링크해
#     원본 JAVA_HOME/PATH 를 글자 그대로 유지한다. 아키텍처별 경로를 박지 않는다
#     — 3.0.5 래핑은 /usr/lib/jvm/temurin-8-jre-amd64 를 하드코딩해 arm64 빌드에서 JAVA_HOME 이 깨졌다.
#   - HBASE_REPOSITORY 1차 미러(http://apache.mirrors.pair.com — 죽은 HTTP 미러) 제거,
#     HTTPS archive 단일 소스로 일원화.
#   - tarball sha512 검증 추가(Apache 공식 .sha512). 원본은 검증하지 않는다.
#   - baseimage 기본 USER 가 비루트 → USER root 로 전환(원본도 root 실행이라 동등).
#   - 원본 v3.1.0 은 컨텍스트 경로가 hbase-docker/Dockerfiles/ → hbase-docker/ 로 바뀌었다(3.0.5 대비).
#   - ⚠️ **HBase 서버를 2.2.6 → 2.5.14-hadoop3 으로 상향**(CVE 조치, 사용자 승인 2026-08-13).
#     근거: pinpoint v3.1.0 의 pom.xml 이 클라이언트를 `hbase.shaded.client.version=2.5.14-hadoop3`
#     으로 핀하는데 이미지가 싣는 서버만 2.2.6(2020-09 빌드)에 멈춰 있었다. 서버를 클라이언트 핀에 맞춘다.
#     효과(Trivy 실측, arm64): CRITICAL 116 → 1, HIGH 253 → 183.
#     2.2.6 의 CRITICAL 116 은 그 배포본이 안고 있는 jackson-databind 2.4.0(95건)·hadoop-common 2.8.5·
#     log4j 1.2.17·zookeeper 3.4.10 등으로, 이미지 레이어에서는 손댈 수 없는 항목이었다.
#   - 남은 CRITICAL 1건(lib/trace/opentelemetry-javaagent)은 삭제한다 — 아래 RUN 주석 참고.
#     결과 CRITICAL 0. 잔존 HIGH 는 CVE-NOTES.md 참고.

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04 AS builder

# baseimage/ubuntu 기본 USER 는 비루트 → apt/다운로드 위해 root 로 전환
USER root

ARG HBASE_VERSION=2.5.14-hadoop3
# tarball 체크섬은 버전과 짝이므로 같이 ARG 로 둔다 (Apache 공식 .sha512 값).
# 버전을 올릴 때 두 ARG 를 함께 바꾼다 — 한쪽만 바꾸면 빌드가 검증 단계에서 멈춘다.
ARG HBASE_SHA512=53ce212599c42610d99b01180b971218ec43be330017088c51cd10b434084a6e6eda89b384270c0179ab9ad6c4104fe93610f6a03077e560becf1ea68092c435
# 원본의 1차 HTTP 미러는 죽어 있어 HTTPS archive 로 일원화.
# 2.5.x 이상의 hadoop3 배포본은 파일명에만 -hadoop3 가 붙고 배포 디렉터리에는 안 붙는다
# → 경로용 버전과 파일명용 버전을 분리해 조립한다.
ENV HBASE_REPOSITORY=https://archive.apache.org/dist/hbase
ENV BASE_DIR=/opt/hbase

WORKDIR ${BASE_DIR}
RUN set -eux; \
    HBASE_DIST_VERSION="${HBASE_VERSION%-hadoop3}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    curl -fSL "${HBASE_REPOSITORY}/${HBASE_DIST_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz" -o hbase.tar.gz; \
    echo "${HBASE_SHA512}  hbase.tar.gz" \
        | sha512sum -c -; \
    tar xfz hbase.tar.gz -C ${BASE_DIR}; \
    rm hbase.tar.gz; \
    rm -rf "${BASE_DIR}/hbase-${HBASE_VERSION}/lib/trace"; \
    rm -rf /var/lib/apt/lists/*
# lib/trace 삭제 근거: 그 안의 opentelemetry-javaagent 는 `bin/hbase` 가
# HBASE_OTEL_TRACING_ENABLED=true 일 때만 -javaagent 로 붙인다(2.5.14 기준 bin/hbase:807).
# pinpoint 의 hbase-env.sh 는 이 변수를 설정하지 않아 실행되지 않는 경로이고,
# 이 jar 하나가 이미지의 유일한 CRITICAL 이었다. classpath 에는 들어가지 않으므로 제거해도 기동에 영향 없다.


FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

USER root

# builder 의 ARG 와 반드시 같은 값이어야 한다 — 다르면 HBASE_HOME 이 추출 경로와 어긋난다.
ARG HBASE_VERSION=2.5.14-hadoop3
ENV BASE_DIR=/opt/hbase
ENV HBASE_HOME=${BASE_DIR}/hbase-${HBASE_VERSION}
# 원본 openjdk:8u342-slim 의 ENV 와 동일
ENV LANG=C.UTF-8

# 원본이 쓰던 JRE 8 을 Adoptium HTTPS apt 저장소로 설치한다(noble 에는 Java 8 패키지가 없음).
# GPG 키는 키서버가 아니라 벤더 HTTPS 로 받아 keyring 에 저장한다.
# 설치 경로는 아키텍처마다 다르므로(temurin-8-jre-amd64 / -arm64) java 실체 경로를 역추적해
# 원본 JAVA_HOME 값인 /usr/local/openjdk-8 로 링크한다 — ln -sfn 으로 idempotent.
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    install -d /etc/apt/keyrings; \
    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" \
        > /etc/apt/sources.list.d/adoptium.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends temurin-8-jre; \
    JVM_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"; \
    install -d /usr/local; \
    ln -sfn "${JVM_DIR}" /usr/local/openjdk-8; \
    /usr/local/openjdk-8/bin/java -version; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/local/openjdk-8
ENV PATH=/usr/local/openjdk-8/bin:${PATH}

WORKDIR ${BASE_DIR}
COPY --from=builder ${BASE_DIR}/hbase-${HBASE_VERSION} ${BASE_DIR}/hbase-${HBASE_VERSION}
COPY scripts/hbase-create.hbase ${BASE_DIR}/hbase-create.hbase
COPY hbase-docker/configure-hbase.sh hbase-docker/check-table.sh hbase-docker/initialize-hbase.sh /usr/local/bin/
COPY hbase-docker/hbase-site.xml ${HBASE_HOME}/conf/hbase-site.xml
COPY hbase-docker/hbase-env.sh ${HBASE_HOME}/conf/hbase-env.sh
RUN chmod a+x /usr/local/bin/*.sh

VOLUME ["/home/pinpoint/hbase", "/home/pinpoint/zookeeper"]

# 원본 런타임 계약 복원: USER root + WORKDIR /opt/hbase + ENTRYPOINT 없음 + 동일 CMD
CMD /usr/local/bin/initialize-hbase.sh && tail -f /dev/null
