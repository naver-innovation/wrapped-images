# 원본: docker.io/jenkins/inbound-agent:3355.v388858a_47b_33-18
#   https://github.com/jenkinsci/docker-agent (tag 3355.v388858a_47b_33-18, debian/Dockerfile)
# 원본 base: debian:trixie-20260406-slim
# 계열 매핑: debian -> baseimage/ubuntu:24.04 (glibc 계열 유지)
# 보정 사항:
#   - baseimage/ubuntu 는 기본 USER 가 비루트 -> 패키지 설치/유저 생성 위해 USER root 로 전환.
#   - baseimage/ubuntu 의 apt source 는 사내 Nexus 로 고정되어 있어, multi-arch 공식 Ubuntu mirror 로 재설정.
#   - upstream 이 jlink 로 구성하던 Java 21 런타임은 Ubuntu openjdk-21-jre-headless 로 보정 설치한다.
#   - remoting jar 는 upstream VERSION 고정 URL에서 받고 sha256 을 검증한다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

USER root

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG AGENT_WORKDIR=/home/${user}/agent
ARG VERSION=3355.v388858a_47b_33
ARG GIT_LFS_VERSION=3.7.1
ARG DOCKER_AGENT_COMMIT=a89f7369b8a108767751998e2c49791c4b7229d5
ARG JENKINS_AGENT_SCRIPT_SHA256=c44d481a94b35f05ea1aca4200a22e365564e610c24c76acfa23625c8133f8f9

ENV TZ=Etc/UTC \
    LANG=C.UTF-8 \
    JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    . /etc/os-release; \
    if [ "$arch" = "amd64" ]; then \
        mirror="http://archive.ubuntu.com/ubuntu"; \
        security="http://security.ubuntu.com/ubuntu"; \
    else \
        mirror="http://ports.ubuntu.com/ubuntu-ports"; \
        security="http://ports.ubuntu.com/ubuntu-ports"; \
    fi; \
    printf 'Types: deb\nURIs: %s\nSuites: %s %s-updates %s-backports\nComponents: main universe\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\nTypes: deb\nURIs: %s\nSuites: %s-security\nComponents: main universe\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
        "$mirror" "$VERSION_CODENAME" "$VERSION_CODENAME" "$VERSION_CODENAME" "$security" "$VERSION_CODENAME" \
        > /etc/apt/sources.list.d/ubuntu.sources; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        fontconfig \
        git \
        less \
        netbase \
        openjdk-21-jre-headless \
        openssh-client \
        patch \
        tzdata; \
    java_home="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"; \
    mkdir -p /opt/java; \
    ln -s "$java_home" "$JAVA_HOME"; \
    rm -rf /var/lib/apt/lists/*

# baseimage/ubuntu:24.04 는 uid/gid 1000 을 기본 ubuntu 유저/그룹이 선점한다.
RUN set -eux; \
    (userdel -r ubuntu 2>/dev/null || true); \
    (groupdel ubuntu 2>/dev/null || true); \
    groupadd -g "${gid}" "${group}"; \
    useradd -l -c "Jenkins user" -d "/home/${user}" -u "${uid}" -g "${gid}" -m "${user}"; \
    mkdir -p /usr/share/jenkins "/home/${user}/.jenkins" "${AGENT_WORKDIR}"; \
    chown -R "${user}:${group}" /usr/share/jenkins "/home/${user}"

RUN set -eux; \
    agent_url="https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar"; \
    curl -fsSL "$agent_url" -o /usr/share/jenkins/agent.jar; \
    echo "$(curl -fsSL "${agent_url}.sha256")  /usr/share/jenkins/agent.jar" | sha256sum -c -; \
    chmod 0644 /usr/share/jenkins/agent.jar; \
    ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar; \
    chown "${user}:${group}" /usr/share/jenkins/agent.jar

RUN set -eux; \
    arch="$(uname -m | sed -e 's/x86_64/amd64/g' -e 's/aarch64/arm64/g' -e 's/armv7l/arm/g')"; \
    curl -fsSL -o git-lfs.tgz "https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${arch}-v${GIT_LFS_VERSION}.tar.gz"; \
    tar xzf git-lfs.tgz; \
    bash git-lfs-*/install.sh; \
    git lfs install --skip-repo --system; \
    rm -rf git-lfs*

RUN set -eux; \
    curl -fsSL "https://raw.githubusercontent.com/jenkinsci/docker-agent/${DOCKER_AGENT_COMMIT}/jenkins-agent" -o /usr/local/bin/jenkins-agent; \
    echo "${JENKINS_AGENT_SCRIPT_SHA256}  /usr/local/bin/jenkins-agent" | sha256sum -c -; \
    chmod +x /usr/local/bin/jenkins-agent; \
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

USER "${user}"

ENV AGENT_WORKDIR=${AGENT_WORKDIR} \
    USER=${user}

VOLUME /home/${user}/.jenkins
VOLUME ${AGENT_WORKDIR}

WORKDIR /home/${user}

LABEL \
    org.opencontainers.image.vendor="Jenkins project" \
    org.opencontainers.image.title="Official Jenkins Inbound Agent Base Docker image" \
    org.opencontainers.image.description="This is an image for Jenkins agents using TCP or WebSockets to establish inbound connection to the Jenkins controller" \
    org.opencontainers.image.version="${VERSION}" \
    org.opencontainers.image.url="https://www.jenkins.io/" \
    org.opencontainers.image.source="https://github.com/jenkinsci/docker-agents" \
    org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
