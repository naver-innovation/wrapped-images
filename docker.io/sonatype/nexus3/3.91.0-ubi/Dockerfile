# 원본: docker.io/sonatype/nexus3:3.91.0-ubi
#   https://github.com/sonatype/docker-nexus3  (Dockerfile.rh.ubi.java21, NEXUS_VERSION=3.91.0-07)
#   라이선스: Apache-2.0 (원본 Dockerfile 헤더 참조)
# 원본 base:
#   registry.access.redhat.com / redhat/ubi9-minimal   (RHEL UBI9 minimal / microdnf 계열)
# 계열 매핑:
#   RHEL(UBI9) → baseimage/navix:10.1-wasl-centos  (centos/RHEL 계열 유지)
# 보정 사항:
#   - baseimage/navix 는 기본 USER 가 비루트 → microdnf/dnf 설치·빌드 위해 USER root 로 전환,
#     원본과 동일하게 마지막에 USER nexus(uid 200) 로 복원.
#   - 원본은 ubi-minimal 의 microdnf 사용. navix 에 microdnf 가 없을 수 있으므로
#     `command -v dnf microdnf` 로 패키지 매니저를 탐지해 동일 패키지를 설치.
#   - baseimage 가 clean RHEL 이 아닐 수 있어 디렉터리/심링크 생성은 멱등(mkdir -p / ln -sfn)으로 처리.
#   - 다운로드는 HTTPS 만 사용(원본 동일). NEXUS_VERSION / SHA256 은 3.91.0-ubi 이미지에서 추출한 값으로 고정.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

LABEL name="Nexus Repository Manager" \
      maintainer="Sonatype <support@sonatype.com>" \
      vendor=Sonatype \
      version="3.91.0-07" \
      release="3.91.0" \
      url="https://sonatype.com" \
      summary="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      description="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      run="docker run -d --name NAME \
          -p 8081:8081 \
          IMAGE" \
      stop="docker stop NAME" \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image" \
      io.k8s.description="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      io.k8s.display-name="Nexus Repository Manager" \
      io.openshift.expose-services="8081:8081" \
      io.openshift.tags="Sonatype,Nexus,Repository Manager" \
      org.opencontainers.image.source=https://github.com/sonatype/docker-nexus3 \
      org.opencontainers.image.licenses=Apache-2.0

ARG NEXUS_VERSION=3.91.0-07
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip
ARG NEXUS_DOWNLOAD_SHA256_HASH=69267aa02492761fc7d9bdc61d01ab878374dbf08c5c54d1fa37c6c9f6044ca6

# baseimage/navix 는 기본 USER 가 비루트 → 설치/빌드 위해 root 로 전환 (원본은 마지막에 USER nexus 로 복원)
USER root

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work \
    DOCKER_TYPE='rh-docker'

# Install Java, tar, and unzip
# 원본 microdnf 사용. navix 에 microdnf 가 없을 수 있으므로 dnf/microdnf 탐지 후 동일 패키지 설치.
RUN set -eux; \
    if command -v microdnf >/dev/null 2>&1; then PKG=microdnf; \
    elif command -v dnf >/dev/null 2>&1; then PKG=dnf; \
    else echo "no dnf/microdnf package manager found" >&2; exit 1; fi; \
    $PKG update -y; \
    $PKG --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y \
          java-21-openjdk-headless tar procps shadow-utils gzip unzip glibc-langpack-en; \
    $PKG clean all; \
    (getent group nexus >/dev/null || groupadd --gid 200 -r nexus); \
    (getent passwd nexus >/dev/null || useradd --uid 200 -r nexus -g nexus -s /bin/false -d /opt/sonatype/nexus -c 'Nexus Repository Manager user')

# Red Hat Certified Container commands
COPY rh-docker /
RUN usermod -a -G root nexus \
    && chmod -R 0755 /licenses \
    && chmod 0755 /help.1 \
    && chmod 0755 /uid_entrypoint.sh \
    && chmod 0755 /uid_template.sh \
    && bash /uid_template.sh \
    && chmod 0664 /etc/passwd

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

WORKDIR ${SONATYPE_DIR}

# Download nexus & setup directories
# 디렉터리/심링크 생성은 멱등(mkdir -p / ln -sfn)으로 처리 — baseimage 가 clean RHEL 이 아닐 수 있음.
RUN curl -L ${NEXUS_DOWNLOAD_URL} --output sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip \
    && echo "${NEXUS_DOWNLOAD_SHA256_HASH} sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip" > sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip.sha256 \
    && sha256sum -c sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip.sha256 \
    && unzip sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip \
    && rm -f sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip sonatype-nexus-repository-${NEXUS_VERSION}-assembly.zip.sha256 \
    && mv nexus-${NEXUS_VERSION} $NEXUS_HOME \
    && chown -R nexus:nexus ${SONATYPE_WORK} \
    && mv ${SONATYPE_WORK}/nexus3 ${NEXUS_DATA} \
    && ln -sfn ${NEXUS_DATA} ${SONATYPE_WORK}/nexus3

RUN echo "#!/bin/bash" >> ${SONATYPE_DIR}/start-nexus-repository-manager.sh \
   && echo "cd /opt/sonatype/nexus" >> ${SONATYPE_DIR}/start-nexus-repository-manager.sh \
   && echo "exec ./bin/nexus run" >> ${SONATYPE_DIR}/start-nexus-repository-manager.sh \
   && chmod a+x ${SONATYPE_DIR}/start-nexus-repository-manager.sh \
   && chmod a+x ${SONATYPE_DIR}/nexus/bin/nexus \
   && sed -e '/^nexus-context/ s:$:${NEXUS_CONTEXT}:' -i ${NEXUS_HOME}/etc/nexus-default.properties

RUN if command -v microdnf >/dev/null 2>&1; then microdnf remove -y gzip shadow-utils || true; \
    else dnf remove -y gzip shadow-utils || true; fi

VOLUME ${NEXUS_DATA}

EXPOSE 8081
# 원본과 동일하게 비루트 nexus(uid 200) 로 복원
USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

ENTRYPOINT ["/uid_entrypoint.sh"]
CMD ["/opt/sonatype/nexus/bin/nexus", "run"]
