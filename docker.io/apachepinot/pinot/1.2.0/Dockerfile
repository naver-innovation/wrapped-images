#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# 원본: docker.io/apachepinot/pinot:1.2.0
#   https://github.com/apache/pinot (tag release-1.2.0)
#   원본 Dockerfile: docker/images/pinot/Dockerfile
# 원본 base:
#   builder  : apachepinot/pinot-base-build:11-amazoncorretto    (외부 app-specific prebuilt, 공개 Dockerfile 없음)
#   runtime  : apachepinot/pinot-base-runtime:11-amazoncorretto  (Amazon Linux 2 / glibc, JDK11 런타임)
# 계열 매핑:
#   builder  : 원본은 외부 불투명 prebuilt(pinot-base-build)를 빌드 환경으로 쓰지만, 빌드 전용 stage 라도
#              CI 가 미승인 외부 이미지를 pull 하게 되어 정책상 부적절 → 동등한 표준 공식 base
#              maven:3.9-eclipse-temurin-11 (maven + JDK11) 로 교체. 프론트엔드 node 는 frontend-maven-plugin 이 자체 다운로드.
#   runtime  : amazoncorretto runtime(glibc + JDK11) → glibc 계열인 baseimage/ubuntu:24.04 로 교체.
#              amazoncorretto 가 제공하던 JDK 와 부가 유틸은 apt 로 보정 설치한다.
# 주의: 원본 runtime stage 의 COPY bin/etc/examples 는 빌드 컨텍스트(=레포의 docker/images/pinot/ 디렉터리)에서
#       복사한다. CI 빌드 컨텍스트는 wrapped-images 레포이므로, 빌더에서 release-1.2.0 을 git clone 한 뒤
#       해당 디렉터리를 builder stage 에서 COPY --from 으로 가져온다(태그 고정).

# ── builder (표준 공식 maven+JDK11 base — 외부 prebuilt 대체) ────────────────────
FROM maven:3.9-eclipse-temurin-11 AS pinot_build_env

LABEL MAINTAINER=dev@pinot.apache.org

# 원본은 PINOT_BRANCH=master 기본 → 태그 고정을 위해 release-1.2.0 으로 지정.
ARG PINOT_BRANCH=release-1.2.0
ARG JDK_VERSION=11
ARG PINOT_GIT_URL="https://github.com/apache/pinot.git"
ARG CI=true

# git: clone 용 (maven 공식 이미지에 git 미포함).
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

ENV PINOT_HOME=/opt/pinot
ENV PINOT_BUILD_DIR=/opt/pinot-build

# 무거운 maven 빌드 — 상류와 동일 경로. 태그(release-1.2.0)를 얕게 클론하여 재현성 확보.
RUN git clone --depth 1 --branch ${PINOT_BRANCH} ${PINOT_GIT_URL} ${PINOT_BUILD_DIR} && \
    cd ${PINOT_BUILD_DIR} && \
    mvn install package -DskipTests -Pbin-dist -Pbuild-shaded-jar -Djdk.version=${JDK_VERSION} -T1C && \
    rm -rf /root/.m2 && \
    mkdir -p ${PINOT_HOME}/configs && \
    mkdir -p ${PINOT_HOME}/data && \
    cp -r build/* ${PINOT_HOME}/. && \
    chmod +x ${PINOT_HOME}/bin/*.sh

# ── runtime (amazoncorretto → baseimage/ubuntu 교체) ────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/apache/pinot
LABEL org.opencontainers.image.description="Apache Pinot - realtime distributed OLAP datastore"
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL MAINTAINER=dev@pinot.apache.org

# baseimage/ubuntu 는 기본 USER 가 비루트일 수 있어 apt 설치 위해 root 로 전환.
USER root

# amazoncorretto runtime 이 제공하던 JDK11 + 런타임 유틸(wget/curl/git/procps/less/zstd 등)을 apt 로 보정.
# wget 은 아래 jmx_prometheus_javaagent 다운로드에 필요. ca-certificates 는 HTTPS 다운로드용.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openjdk-11-jdk-headless \
      ca-certificates \
      wget \
      curl \
      git \
      procps \
      less \
      vim \
      sysstat \
      zstd \
    && rm -rf /var/lib/apt/lists/*

ENV PINOT_HOME=/opt/pinot
# PINOT_BUILD_DIR 는 빌더 stage 의 ENV 라 런타임 stage 에서는 정의되지 않는다.
# 아래 COPY --from 의 ${PINOT_BUILD_DIR} 경로가 빈 값으로 풀려 깨지므로 런타임 stage 에도 정의한다.
ENV PINOT_BUILD_DIR=/opt/pinot-build
ENV JAVA_OPTS="-Xms4G -Xmx4G -Dpinot.admin.system.exit=false"

VOLUME ["${PINOT_HOME}/configs", "${PINOT_HOME}/data"]

# 상류 빌드 산출물.
COPY --from=pinot_build_env ${PINOT_HOME} ${PINOT_HOME}
# 원본은 빌드 컨텍스트(docker/images/pinot/{bin,etc,examples})에서 복사 → 동일 태그를 clone 한 빌더에서 가져온다.
COPY --from=pinot_build_env ${PINOT_BUILD_DIR}/docker/images/pinot/bin ${PINOT_HOME}/bin
COPY --from=pinot_build_env ${PINOT_BUILD_DIR}/docker/images/pinot/etc ${PINOT_HOME}/etc
COPY --from=pinot_build_env ${PINOT_BUILD_DIR}/docker/images/pinot/examples ${PINOT_HOME}/examples

RUN wget -O ${PINOT_HOME}/etc/jmx_prometheus_javaagent/jmx_prometheus_javaagent-0.18.0.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.18.0/jmx_prometheus_javaagent-0.18.0.jar && \
    ln -sf ${PINOT_HOME}/etc/jmx_prometheus_javaagent/jmx_prometheus_javaagent-0.18.0.jar ${PINOT_HOME}/etc/jmx_prometheus_javaagent/jmx_prometheus_javaagent.jar

# expose ports for controller/broker/server/admin
EXPOSE 9000 8099 8098 8097 8096

WORKDIR ${PINOT_HOME}

ENTRYPOINT ["./bin/pinot-admin.sh"]

CMD ["-help"]
