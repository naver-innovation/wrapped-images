#
# Copyright 2017-2019 Confluent Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ─────────────────────────────────────────────────────────────────────────────
# 원본: docker.io/confluentinc/cp-kafka:7.4.0
#   source: https://github.com/confluentinc/kafka-images        (tag v7.4.0, kafka/Dockerfile.ubi8)
#   원본 cp-kafka 는 FROM confluentinc/cp-base-new:7.4.0 (UBI8-minimal / RHEL·dnf 계열) 위에 빌드된다.
#   cp-base-new 자체 소스: https://github.com/confluentinc/common-docker (tag v7.4.0, base/Dockerfile.ubi8)
#
# 계열 매핑:
#   cp-base-new = registry.access.redhat.com/ubi8/ubi-minimal  → RHEL 계열
#   runtime base 를 허용된 baseimage/navix:10.1-wasl-centos (RHEL/CentOS 계열) 로 교체한다.
#
# ⚠️ 하드 케이스 (PR 본문 리스크 참고):
#   cp-kafka 는 prebuilt 베이스 cp-base-new 의 환경(appuser, /etc/confluent/docker, zulu JDK11,
#   confluent-docker-utils 의 ub/cub 도구)을 전제한다. 허용 base 에는 cp-base-new 가 없으므로
#   이 Dockerfile 은 ①cp-base-new 셋업을 navix 위에 재구성하고 ②그 위에 cp-kafka 패키지(confluent-kafka)
#   설치를 적층하는 방식으로 원본 두 Dockerfile 을 충실히 합성한 것이다.
#   - 멀티스테이지(원본은 단일 FROM 체인)는 그대로 단일 최종 이미지로 유지한다.
#   - dnf 가 없을 수 있어 dnf→microdnf→yum 순으로 가용 패키지 매니저를 자동 선택한다.
#   - /etc/confluent/docker/run(=CMD) 및 configure/ensure 스크립트는 confluent-kafka RPM 이 직접 설치한다.
# ─────────────────────────────────────────────────────────────────────────────

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

# ── 원본 cp-base-new / cp-kafka 의 빌드 인자 (주입형 ARG, 기본값으로 7.4.0 고정) ──────────────
ARG PROJECT_VERSION="7.4.0"
ARG ARTIFACT_ID="cp-kafka"
ARG GIT_COMMIT="v7.4.0"
ARG BUILD_NUMBER=-1

# cp-kafka 패키지 버전 및 confluent RPM 저장소 (HTTPS 만 사용)
ARG CONFLUENT_VERSION="7.4.0"
ARG CONFLUENT_PACKAGES_REPO="https://packages.confluent.io/rpm/7.4"
ARG CONFLUENT_PLATFORM_LABEL=""

# cp-base-new 가 git 에서 받아오던 confluent-docker-utils (ub/cub 도구). HTTPS 고정.
ARG PYTHON_CONFLUENT_DOCKER_UTILS_VERSION="v7.4.0"
ARG PYTHON_CONFLUENT_DOCKER_UTILS_INSTALL_SPEC="git+https://github.com/confluentinc/confluent-docker-utils@${PYTHON_CONFLUENT_DOCKER_UTILS_VERSION}"

# ── cp-base-new 라벨/환경 ─────────────────────────────────────────────────────
LABEL io.confluent.docker.git.repo="confluentinc/kafka-images"
LABEL io.confluent.docker.git.id=$GIT_COMMIT
LABEL io.confluent.docker.build.number=$BUILD_NUMBER
LABEL maintainer="partner-support@confluent.io"
LABEL vendor="Confluent"
LABEL version=$GIT_COMMIT
LABEL release=$PROJECT_VERSION
LABEL name=$ARTIFACT_ID
LABEL summary="Confluent platform Kafka."
LABEL description="Confluent platform Kafka (wrapped onto baseimage/navix)."
LABEL io.confluent.docker=true

# UTF-8 (원본 cp-base-new: 자바 클래스 문자열 해석에 필요)
ENV LANG="C.UTF-8"
# cub 가 참조하는 cp-base-new JAR classpath (원본 동일)
ENV CUB_CLASSPATH='"/usr/share/java/cp-base-new/*"'

# 원본 cp-kafka 의 컴포넌트/포트/주입형 env
ENV COMPONENT=kafka
ARG KAFKA_ZOOKEEPER_CONNECT
ENV KAFKA_ZOOKEEPER_CONNECT=${KAFKA_ZOOKEEPER_CONNECT}
ARG KAFKA_ADVERTISED_LISTENERS
ENV KAFKA_ADVERTISED_LISTENERS=${KAFKA_ADVERTISED_LISTENERS}
ARG CLUSTER_ID
ENV CLUSTER_ID=${CLUSTER_ID}

# primary (원본 cp-kafka)
EXPOSE 9092

# baseimage/navix 의 기본 USER 는 비루트일 수 있음 → 패키지 설치 위해 root 로 전환
# (원본 cp-base-new 는 마지막에 appuser 로, cp-kafka 도 설치 구간은 USER root)
USER root

# ─────────────────────────────────────────────────────────────────────────────
# (1) cp-base-new 재구성: zulu JDK11 + python39 + 런타임 도구 + appuser + confluent-docker-utils
#     baseimage 가 깨끗하지 않을 수 있어 mkdir -p / useradd ||true 로 멱등 처리한다.
# ─────────────────────────────────────────────────────────────────────────────
RUN set -eux; \
    if command -v dnf >/dev/null 2>&1; then PKG="dnf"; \
    elif command -v microdnf >/dev/null 2>&1; then PKG="microdnf"; \
    else PKG="yum"; fi; \
    echo "===> using package manager: ${PKG}"; \
    # Azul Zulu OpenJDK 저장소 (HTTPS 키 + HTTPS repo rpm)
    rpm --import https://www.azul.com/files/0xB1998361219BD9C9.txt; \
    "${PKG}" --nodocs -y install https://cdn.azul.com/zulu/bin/zulu-repo-1.0.0-1.noarch.rpm || \
        "${PKG}" -y install https://cdn.azul.com/zulu/bin/zulu-repo-1.0.0-1.noarch.rpm; \
    # 원본 cp-base-new 패키지 집합 (RHEL 계열 dnf/yum) — 버전 미지정=가용 최신(원본 ARG 기본값과 동일)
    "${PKG}" --nodocs install -y --setopt=install_weak_deps=False \
        openssl \
        wget \
        nmap-ncat \
        python39 \
        python39-pip \
        tar \
        procps-ng \
        krb5-workstation \
        iputils \
        hostname \
        xz-libs \
        glibc \
        glibc-common \
        glibc-minimal-langpack \
        curl \
        libcurl \
        zulu11-ca-jdk-headless zulu11-ca-jre-headless \
    || "${PKG}" install -y \
        openssl wget nmap-ncat python39 python39-pip tar procps-ng \
        krb5-workstation iputils hostname xz-libs glibc glibc-common \
        glibc-minimal-langpack curl libcurl zulu11-ca-jdk-headless zulu11-ca-jre-headless; \
    # python3 기본 alternatives (baseimage 가 깨끗하지 않을 수 있어 실패 무시)
    (alternatives --set python /usr/bin/python3 || true); \
    # 원본 cp-base-new: setuptools 업그레이드 + confluent-docker-utils(ub/cub) 설치
    python3 -m pip install --upgrade setuptools; \
    python3 -m pip install --prefer-binary --prefix=/usr/local --upgrade "${PYTHON_CONFLUENT_DOCKER_UTILS_INSTALL_SPEC}"; \
    "${PKG}" clean all; \
    rm -rf /tmp/*; \
    # 원본 cp-base-new 디렉터리/계정 (멱등)
    mkdir -p /etc/confluent/docker /usr/logs; \
    (getent passwd appuser >/dev/null 2>&1 || useradd --no-log-init --create-home --shell /bin/bash appuser); \
    chown appuser:appuser -R /etc/confluent/ /usr/logs

# ─────────────────────────────────────────────────────────────────────────────
# (2) cp-kafka 패키지 설치: confluent yum 저장소(HTTPS) → confluent-kafka-${CONFLUENT_VERSION}
#     이 RPM 이 /etc/confluent/docker/{run,configure,ensure} 및 kafka 바이너리를 설치한다.
#     원본 kafka/Dockerfile.ubi8 의 RUN 블록을 그대로 재현한다.
# ─────────────────────────────────────────────────────────────────────────────
RUN set -eux; \
    if command -v dnf >/dev/null 2>&1; then PKG="dnf"; \
    elif command -v microdnf >/dev/null 2>&1; then PKG="microdnf"; \
    else PKG="yum"; fi; \
    echo "===> Installing ${COMPONENT}..."; \
    echo "===> Adding confluent repository...${CONFLUENT_PACKAGES_REPO}"; \
    rpm --import ${CONFLUENT_PACKAGES_REPO}/archive.key; \
    printf '[Confluent.dist]\nname=Confluent repository (dist)\nbaseurl=%s/$releasever\ngpgcheck=1\ngpgkey=%s/archive.key\nenabled=1\n\n[Confluent]\nname=Confluent repository\nbaseurl=%s/\ngpgcheck=1\ngpgkey=%s/archive.key\nenabled=1\n' \
        "${CONFLUENT_PACKAGES_REPO}" "${CONFLUENT_PACKAGES_REPO}" "${CONFLUENT_PACKAGES_REPO}" "${CONFLUENT_PACKAGES_REPO}" \
        > /etc/yum.repos.d/confluent.repo; \
    "${PKG}" install -y confluent-kafka-${CONFLUENT_VERSION}; \
    echo "===> clean up ..."; \
    "${PKG}" clean all; \
    rm -rf /tmp/* /etc/yum.repos.d/confluent.repo; \
    echo "===> Setting up ${COMPONENT} dirs"; \
    mkdir -p /var/lib/${COMPONENT}/data /etc/${COMPONENT}/secrets /var/log/kafka /var/log/confluent /var/lib/kafka /var/lib/zookeeper /etc/kafka; \
    chown appuser:root -R /etc/kafka /var/log/kafka /var/log/confluent /var/lib/kafka /var/lib/zookeeper /etc/${COMPONENT}/secrets /var/lib/${COMPONENT} /etc/${COMPONENT}; \
    chmod -R ug+w /etc/kafka /var/log/kafka /var/log/confluent /var/lib/kafka /var/lib/zookeeper /var/lib/${COMPONENT} /etc/${COMPONENT}/secrets /etc/${COMPONENT}

VOLUME ["/var/lib/kafka/data", "/etc/kafka/secrets"]

# 원본 cp-base-new 의 비루트 런타임 사용자(appuser) 로 복귀
USER appuser
WORKDIR /home/appuser

CMD ["/etc/confluent/docker/run"]
