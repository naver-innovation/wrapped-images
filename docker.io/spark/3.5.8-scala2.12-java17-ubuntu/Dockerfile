#
# Apache Spark 3.5.8 (scala2.12-java17-ubuntu) — WASL OCIR wrap.
#
# 원본: docker.io/spark:3.5.8-scala2.12-java17-ubuntu
#   (apache/spark-docker 3.5.8/scala2.12-java17-ubuntu/Dockerfile, FROM eclipse-temurin:17-jammy)
# 정책: 외부 이미지 직접 사용 금지 → 허용 BaseImage(ubuntu 계열)로 FROM 교체 후 OCIR push.
#
# 변경점 (원본 대비):
#   1. FROM eclipse-temurin:17-jammy  → baseimage/ubuntu:24.04 (동일 ubuntu/apt 계열)
#   2. baseimage/ubuntu 기본 USER 가 비루트 → 설치 위해 USER root 명시
#   3. eclipse-temurin 이 제공하던 JDK 가 baseimage/ubuntu 엔 없음 → openjdk-17-jre-headless 설치
#      (JAVA_HOME 은 entrypoint.sh 가 PATH 의 java 로 자동탐지하므로 ENV 불필요 — 원본 동작 유지)
#   4. mkdir → mkdir -p (baseimage 선존재 대비 idempotent)
# 나머지(spark 다운로드·GPG 검증·레이아웃·USER spark·ENTRYPOINT)는 원본 그대로.
#
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

ARG spark_uid=185

USER root

RUN groupadd --system --gid=${spark_uid} spark && \
    useradd --system --uid=${spark_uid} --gid=spark -d /nonexistent spark

# openjdk-17-jre-headless: 원본 eclipse-temurin 이 내장하던 Java 17 을 ubuntu base 에 설치.
RUN set -ex; \
    apt-get update; \
    apt-get install -y openjdk-17-jre-headless gnupg2 wget bash tini libc6 libpam-modules krb5-user libnss3 procps net-tools gosu libnss-wrapper; \
    mkdir -p /opt/spark; \
    mkdir -p /opt/spark/python; \
    mkdir -p /opt/spark/examples; \
    mkdir -p /opt/spark/work-dir; \
    chmod g+w /opt/spark/work-dir; \
    touch /opt/spark/RELEASE; \
    chown -R spark:spark /opt/spark; \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su; \
    rm -rf /var/lib/apt/lists/*

# Install Apache Spark
# https://downloads.apache.org/spark/KEYS
ENV SPARK_TGZ_URL=https://www.apache.org/dyn/closer.lua/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3.tgz?action=download \
    SPARK_TGZ_ASC_URL=https://www.apache.org/dyn/closer.lua/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3.tgz.asc?action=download \
    GPG_KEY=F28C9C925C188C35E345614DEDA00CE834F0FC5C

RUN set -ex; \
    export SPARK_TMP="$(mktemp -d)"; \
    cd $SPARK_TMP; \
    wget -nv -O spark.tgz "$SPARK_TGZ_URL"; \
    wget -nv -O spark.tgz.asc "$SPARK_TGZ_ASC_URL"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-key "$GPG_KEY" || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$GPG_KEY"; \
    gpg --batch --verify spark.tgz.asc spark.tgz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" spark.tgz.asc; \
    \
    tar -xf spark.tgz --strip-components=1; \
    chown -R spark:spark .; \
    mv jars /opt/spark/; \
    mv RELEASE /opt/spark/; \
    mv bin /opt/spark/; \
    mv sbin /opt/spark/; \
    mv kubernetes/dockerfiles/spark/decom.sh /opt/; \
    mv examples /opt/spark/; \
    ln -s "$(basename /opt/spark/examples/jars/spark-examples_*.jar)" /opt/spark/examples/jars/spark-examples.jar; \
    mv kubernetes/tests /opt/spark/; \
    mv data /opt/spark/; \
    mv python/pyspark /opt/spark/python/pyspark/; \
    mv python/lib /opt/spark/python/lib/; \
    mv R /opt/spark/; \
    chmod a+x /opt/decom.sh; \
    cd ..; \
    rm -rf "$SPARK_TMP";

COPY entrypoint.sh /opt/

ENV SPARK_HOME=/opt/spark

WORKDIR /opt/spark/work-dir

USER spark

ENTRYPOINT [ "/opt/entrypoint.sh" ]
