# 원본: docker.io/jenkins/jenkins:2.577-jdk25
#   https://github.com/jenkinsci/docker (tag 2.577, debian/Dockerfile)
# 원본 base: debian:trixie-20260803-slim
# 계열 매핑: debian -> baseimage/ubuntu:24.04 (glibc 계열 유지)
# 보정 사항:
#   - baseimage/ubuntu 는 기본 USER 가 비루트 -> 패키지 설치/유저 생성 위해 USER root 로 전환.
#   - baseimage/ubuntu 의 apt source 는 사내 Nexus 로 고정되어 있어, multi-arch 공식 Ubuntu mirror 로 재설정.
#   - upstream 이 jlink 로 구성하던 JDK25 런타임은 Ubuntu openjdk-25-jre-headless 로 보정 설치한다.
#   - jenkins.war 는 upstream 과 동일하게 Jenkins signing key 로 asc 서명을 검증한다.
#   - 2.577 은 weekly 라인이라 war 경로가 war-stable 이 아니라 war 다.
#   - git-lfs 3.7.1 release binary 의 취약한 Go stdlib 대신 같은 소스를 보안 수정된 Go 로 빌드한다.
FROM docker.io/library/golang:1.25.12-bookworm AS git-lfs

ARG GIT_LFS_VERSION=3.7.1
ARG GIT_LFS_SOURCE_SHA256=8f56058622edfea1d111e50e9844ef2f5ce670b2dbe4d55d48e765c943af4351

RUN set -eux; \
    curl -fsSL -o git-lfs.tar.gz "https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-v${GIT_LFS_VERSION}.tar.gz"; \
    echo "${GIT_LFS_SOURCE_SHA256}  git-lfs.tar.gz" | sha256sum -c -; \
    tar xzf git-lfs.tar.gz; \
    cd "git-lfs-${GIT_LFS_VERSION}"; \
    make bin/git-lfs VERSION="v${GIT_LFS_VERSION}" GIT_LFS_SHA="v${GIT_LFS_VERSION}"; \
    mkdir -p /out; \
    cp bin/git-lfs /out/git-lfs

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04 AS war

USER root

ARG JENKINS_VERSION=2.577
ARG WAR_URL=https://get.jenkins.io/war/${JENKINS_VERSION}/jenkins.war
ARG DOCKER_COMMIT=ae960660ebcfc3cc73a638d1b4a384d9098274e2
ARG JENKINS_PUB_SHA256=d3b7e4096fed593eebdba3a2554c8cb9aafebe736910584e69e924b143e7b3d4

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
        ca-certificates \
        curl \
        gnupg; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /war; \
    curl -fsSL "https://raw.githubusercontent.com/jenkinsci/docker/${DOCKER_COMMIT}/jenkins.io-2026.key" -o /war/jenkins-key.pub; \
    echo "${JENKINS_PUB_SHA256}  /war/jenkins-key.pub" | sha256sum -c -; \
    curl -fsSL "${WAR_URL}" -o /war/jenkins.war; \
    curl -fsSL "${WAR_URL}.asc" -o /war/jenkins.war.asc; \
    gpg --batch --import /war/jenkins-key.pub; \
    gpg --batch --verify --trust-model direct /war/jenkins.war.asc /war/jenkins.war

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04 AS controller

USER root

ARG JENKINS_VERSION=2.577
ARG DOCKER_COMMIT=ae960660ebcfc3cc73a638d1b4a384d9098274e2
ARG COMMIT_SHA=ae960660ebcfc3cc73a638d1b4a384d9098274e2
ARG PLUGIN_CLI_VERSION=2.15.0
ARG PLUGIN_CLI_URL=https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PLUGIN_CLI_VERSION}/jenkins-plugin-manager-${PLUGIN_CLI_VERSION}.jar
ARG JENKINS_SUPPORT_SHA256=a1b91705b08541cca2cf458bbbc4214b7dd7177e179ffd8da30623d443c6191c
ARG JENKINS_SH_SHA256=f7dbd4d96661e1395daa6d2065c00c82eb48e5a38e8c3a794adf8622a2ea3ca7
ARG JENKINS_PLUGIN_CLI_SH_SHA256=b80b9ea9ae86c37f28a0aef757664be08fd22951043b18e70b2cb2c270a648fa

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home
ARG REF=/usr/share/jenkins/ref

ENV JENKINS_HOME=${JENKINS_HOME} \
    JENKINS_SLAVE_AGENT_PORT=${agent_port} \
    REF=${REF} \
    JENKINS_UC=https://updates.jenkins.io \
    JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental \
    JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals \
    COPY_REFERENCE_FILE_LOG=${JENKINS_HOME}/copy_reference_file.log \
    TZ=Etc/UTC \
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
        git \
        libfontconfig1 \
        libfreetype6 \
        libharfbuzz0b \
        openjdk-25-jre-headless \
        procps \
        ssh-client \
        tini \
        unzip \
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
    useradd -d "${JENKINS_HOME}" -u "${uid}" -g "${gid}" -l -m -s /bin/bash "${user}"; \
    mkdir -p "${JENKINS_HOME}" "${REF}/init.groovy.d" /usr/share/jenkins; \
    chown -R "${user}:${group}" "${JENKINS_HOME}" "${REF}"

RUN set -eux; \
    curl -fsSL "${PLUGIN_CLI_URL}" -o /opt/jenkins-plugin-manager.jar; \
    echo "$(curl -fsSL "${PLUGIN_CLI_URL}.sha256")  /opt/jenkins-plugin-manager.jar" | sha256sum -c -

COPY --from=git-lfs /out/git-lfs /usr/local/bin/git-lfs

RUN git lfs install --skip-repo --system

RUN set -eux; \
    curl -fsSL "https://raw.githubusercontent.com/jenkinsci/docker/${DOCKER_COMMIT}/jenkins-support" -o /usr/local/bin/jenkins-support; \
    echo "${JENKINS_SUPPORT_SHA256}  /usr/local/bin/jenkins-support" | sha256sum -c -; \
    curl -fsSL "https://raw.githubusercontent.com/jenkinsci/docker/${DOCKER_COMMIT}/jenkins.sh" -o /usr/local/bin/jenkins.sh; \
    echo "${JENKINS_SH_SHA256}  /usr/local/bin/jenkins.sh" | sha256sum -c -; \
    curl -fsSL "https://raw.githubusercontent.com/jenkinsci/docker/${DOCKER_COMMIT}/jenkins-plugin-cli.sh" -o /bin/jenkins-plugin-cli; \
    echo "${JENKINS_PLUGIN_CLI_SH_SHA256}  /bin/jenkins-plugin-cli" | sha256sum -c -; \
    chmod +x /usr/local/bin/jenkins-support /usr/local/bin/jenkins.sh /bin/jenkins-plugin-cli

COPY --from=war /war/jenkins.war /usr/share/jenkins/jenkins.war

VOLUME ${JENKINS_HOME}

EXPOSE ${http_port}
EXPOSE ${agent_port}

USER "${user}"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

LABEL \
    org.opencontainers.image.vendor="Jenkins project" \
    org.opencontainers.image.title="Official Jenkins Docker image" \
    org.opencontainers.image.description="The Jenkins Continuous Integration and Delivery server" \
    org.opencontainers.image.version="${JENKINS_VERSION}" \
    org.opencontainers.image.url="https://www.jenkins.io/" \
    org.opencontainers.image.source="https://github.com/jenkinsci/docker" \
    org.opencontainers.image.revision="${COMMIT_SHA}" \
    org.opencontainers.image.licenses="MIT"
