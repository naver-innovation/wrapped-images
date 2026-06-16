# 원본: docker.io/apache/kafka:4.0.0  (issue #5 의 bitnamilegacy/kafka:4.0.0-debian-12-r10 공개 대체 이미지)
#   https://github.com/apache/kafka (tag 4.0.0, docker/jvm/Dockerfile)
# 원본 base:
#   build-jsa : eclipse-temurin:21-jre-alpine   (alpine / musl 계열, JRE 21)
#   runtime   : eclipse-temurin:21-jre-alpine   (alpine / musl 계열, JRE 21)
# 계열 매핑: alpine → baseimage/alpine  (musl 유지 — glibc 계열로 교체 불가)
#   ※ 본 4.0.0 의 공식 jvm Dockerfile 은 (작업지시의 ubuntu 추정과 달리) 실제로 alpine 기반이므로
#     원본 계열에 충실히 alpine 으로 매핑한다.
#   baseimage/alpine 에는 JRE 가 없으므로(temurin base 가 제공하던 것) apk 로 openjdk21-jre-headless 보정 설치.
#   build-jsa stage 는 빌드 전용(.jsa CDS 산출)이라 원본 pinned base(temurin) 를 그대로 유지한다(원본 충실 + .jsa 생성 안정).
#   build 컨텍스트 = 본 디렉터리. 원본 docker/ 빌드컨텍스트 레이아웃을 그대로 벤더링:
#     jsa_launch, launch, server.properties, resources/common-scripts/{bash-config,configure,configureDefaults,run}
#   원본은 kafka_url 을 --build-arg 로 주입받지만, 본 레포 CI 는 build-arg 없이 **/Dockerfile 을 빌드하므로
#   (telegraf/grafana 와 동일하게) 4.0.0 고정 아티팩트 URL 을 ARG 기본값으로 박아 self-contained 하게 만든다.
#   서명검증은 원본 흐름 그대로: downloads.apache.org/kafka/KEYS(HTTPS) import 후 gpg --batch --verify.
ARG kafka_url=https://archive.apache.org/dist/kafka/4.0.0/kafka_2.13-4.0.0.tgz

###############################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

# ── build-jsa (빌드 전용 stage — 원본 pinned base 유지) ──────────────────────────
FROM eclipse-temurin:21-jre-alpine AS build-jsa

USER root

# Get kafka from https://archive.apache.org/dist/kafka and pass the url through build arguments
ARG kafka_url

COPY jsa_launch /etc/kafka/docker/jsa_launch
COPY server.properties /etc/kafka/docker/server.properties

RUN set -eux ; \
    apk update ; \
    apk upgrade ; \
    apk add --no-cache wget gcompat gpg gpg-agent procps bash; \
    mkdir opt/kafka; \
    wget -nv -O kafka.tgz "$kafka_url"; \
    wget -nv -O kafka.tgz.asc "$kafka_url.asc"; \
    tar xfz kafka.tgz -C /opt/kafka --strip-components 1; \
    wget -nv -O KEYS https://downloads.apache.org/kafka/KEYS; \
    gpg --import KEYS; \
    gpg --batch --verify kafka.tgz.asc kafka.tgz

# Generate jsa files using dynamic CDS for kafka server start command and kafka storage format command
RUN /etc/kafka/docker/jsa_launch


# ── runtime (원본 runtime stage 의 FROM 만 baseimage/alpine 로 교체) ──────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

# exposed ports
EXPOSE 9092

# baseimage/alpine 은 기본 USER 가 비루트 → apk/시스템 편집 위해 root 로 전환 (런타임은 마지막에 appuser 로 복귀)
USER root

# Get kafka from https://archive.apache.org/dist/kafka and pass the url through build arguments
ARG kafka_url
ARG build_date


LABEL org.label-schema.name="kafka" \
      org.label-schema.description="Apache Kafka" \
      org.label-schema.build-date="${build_date}" \
      org.label-schema.vcs-url="https://github.com/apache/kafka" \
      maintainer="Apache Kafka"
LABEL org.opencontainers.image.source=https://github.com/apache/kafka
LABEL org.opencontainers.image.description="Apache Kafka (wrapped onto baseimage/alpine; bitnami/kafka 대체 — issue #5)"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/alpine 에는 JRE 가 없으므로 temurin base 가 제공하던 JRE 21 을 apk 로 보정 설치한다.
# openjdk21-jre-headless 는 런타임 내내 유지(아래 apk del 대상에서 제외).
RUN set -eux ; \
    apk update ; \
    apk upgrade ; \
    apk add --no-cache openjdk21-jre-headless gcompat procps bash; \
    apk add --no-cache --virtual .kafka-fetch wget gpg gpg-agent; \
    mkdir -p /opt/kafka; \
    wget -nv -O kafka.tgz "$kafka_url"; \
    wget -nv -O kafka.tgz.asc "$kafka_url.asc"; \
    tar xfz kafka.tgz -C /opt/kafka --strip-components 1; \
    wget -nv -O KEYS https://downloads.apache.org/kafka/KEYS; \
    gpg --import KEYS; \
    gpg --batch --verify kafka.tgz.asc kafka.tgz; \
    mkdir -p /var/lib/kafka/data /etc/kafka/secrets; \
    mkdir -p /etc/kafka/docker /usr/logs /mnt/shared/config; \
    adduser -h /home/appuser -D --shell /bin/bash appuser 2>/dev/null || true; \
    chown appuser:appuser -R /usr/logs /opt/kafka /mnt/shared/config; \
    chown appuser:root -R /var/lib/kafka /etc/kafka/secrets /etc/kafka; \
    chmod -R ug+w /etc/kafka /var/lib/kafka /etc/kafka/secrets; \
    cp /opt/kafka/config/log4j2.yaml /etc/kafka/docker/log4j2.yaml; \
    cp /opt/kafka/config/tools-log4j2.yaml /etc/kafka/docker/tools-log4j2.yaml; \
    rm kafka.tgz kafka.tgz.asc KEYS; \
    apk del .kafka-fetch; \
    apk cache clean;

COPY server.properties /etc/kafka/docker/server.properties
COPY --from=build-jsa kafka.jsa /opt/kafka/kafka.jsa
COPY --from=build-jsa storage.jsa /opt/kafka/storage.jsa
COPY --chown=appuser:appuser resources/common-scripts /etc/kafka/docker
COPY --chown=appuser:appuser launch /etc/kafka/docker/launch

USER appuser

VOLUME ["/etc/kafka/secrets", "/var/lib/kafka/data", "/mnt/shared/config"]

CMD ["/etc/kafka/docker/run"]
