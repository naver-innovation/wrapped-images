# 원본: ghcr.io/apache/flink-kubernetes-operator:1.14.0
#   https://github.com/apache/flink-kubernetes-operator (tag release-1.14.0, Dockerfile)
# 원본 base: eclipse-temurin:17-jre-jammy (ubuntu 22.04)
# 계열 매핑: debian/ubuntu -> baseimage/ubuntu:24.04 (glibc 계열 유지)
# 보정 사항:
#   - 원본은 repo 전체를 빌드 컨텍스트로 COPY . . -> 빌더 stage 에서 git clone --branch release-1.14.0 로 대체.
#   - baseimage/ubuntu 의 apt source 는 사내 Nexus 로 고정되어 있어, multi-arch 공식 Ubuntu mirror 로 재설정.
#   - upstream 의 eclipse-temurin JRE17 은 Ubuntu openjdk-17-jre-headless 로 보정 설치한다.
#   - baseimage/ubuntu 기본 USER 는 비루트 -> 설치 단계 USER root, 런타임은 원본과 동일한 flink(uid 9999) 복원.
#   - CI 는 build-arg 없이 빌드하므로 원본 ARG 기본값(SKIP_TESTS/HTTP_CLIENT/DISABLE_JEMALLOC)을 그대로 명시.
#   - CVE 조치: 원본의 SKIP_OS_UPDATE 분기 대신 apt-get upgrade 를 항상 수행.
# Build
ARG JAVA_VERSION=17
FROM docker.io/library/maven:3.8.8-eclipse-temurin-${JAVA_VERSION} AS build
ARG GIT_TAG=release-1.14.0
ARG SKIP_TESTS=true
ARG HTTP_CLIENT=okhttp

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/apache/flink-kubernetes-operator.git .

# CVE 조치: jackson-bom 2.15.0 -> 2.18.8 (CVE-2026-54512, CVE-2026-54513, GHSA-r7wm-3cxj-wff9)
#   upstream 은 main 에서 2.21.5 로 상향했으나 릴리스(1.15.0 포함)에는 미반영 -> 소스 패치로 선반영.
#   pom.xml 에서 2.15.0 은 jackson-bom 버전 단 1회만 등장 — 검증 후 치환.
RUN [ "$(grep -c '<version>2.15.0</version>' pom.xml)" = "1" ] && \
    sed -i 's|<version>2.15.0</version>|<version>2.18.8</version>|' pom.xml

RUN mvn -ntp clean install -pl flink-kubernetes-standalone,flink-kubernetes-operator-api,flink-kubernetes-operator,flink-autoscaler,flink-kubernetes-webhook -DskipTests=$SKIP_TESTS -Dfabric8.httpclient.impl="$HTTP_CLIENT"

RUN cd /app/tools/license; mkdir -p jars; cd jars; \
    cp /app/flink-kubernetes-operator/target/flink-kubernetes-operator-*-shaded.jar . && \
    cp /app/flink-kubernetes-webhook/target/flink-kubernetes-webhook-*-shaded.jar . && \
    cp /app/flink-kubernetes-standalone/target/flink-kubernetes-standalone-*.jar . && \
    cp -r /app/flink-kubernetes-operator/target/plugins ./plugins && \
    cd ../ && ./collect_license_files.sh ./jars ./licenses-output

# stage
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

USER root

ENV FLINK_HOME=/opt/flink
ENV FLINK_PLUGINS_DIR=$FLINK_HOME/plugins
ENV OPERATOR_VERSION=1.14.0
ENV OPERATOR_JAR=flink-kubernetes-operator-$OPERATOR_VERSION-shaded.jar
ENV WEBHOOK_JAR=flink-kubernetes-webhook-$OPERATOR_VERSION-shaded.jar
ENV KUBERNETES_STANDALONE_JAR=flink-kubernetes-standalone-$OPERATOR_VERSION.jar

ENV OPERATOR_LIB=$FLINK_HOME/operator-lib
RUN mkdir -p $OPERATOR_LIB

# apt mirror 재설정(사내 Nexus -> 공식 mirror) + JRE17/jemalloc 설치 + OS 패키지 업그레이드
ARG DISABLE_JEMALLOC=false
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
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless; \
    if [ "$DISABLE_JEMALLOC" = "false" ]; then \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libjemalloc-dev; \
    fi; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /flink-kubernetes-operator
RUN groupadd --system --gid=9999 flink && \
    useradd --system --home-dir $FLINK_HOME --uid=9999 --gid=flink flink

RUN chown -R flink:flink $FLINK_HOME

COPY --chown=flink:flink --from=build /app/flink-kubernetes-operator/target/$OPERATOR_JAR .
COPY --chown=flink:flink --from=build /app/flink-kubernetes-webhook/target/$WEBHOOK_JAR .
COPY --chown=flink:flink --from=build /app/flink-kubernetes-standalone/target/$KUBERNETES_STANDALONE_JAR .
COPY --chown=flink:flink --from=build /app/flink-kubernetes-operator/target/plugins $FLINK_HOME/plugins
COPY --chown=flink:flink --from=build /app/tools/license/licenses-output/NOTICE .
COPY --chown=flink:flink --from=build /app/tools/license/licenses-output/licenses ./licenses
COPY --chown=flink:flink --from=build /app/LICENSE ./LICENSE
COPY --chown=flink:flink --from=build /app/docker-entrypoint.sh /

USER flink
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
