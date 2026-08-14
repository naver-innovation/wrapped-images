# 원본           : docker.io/pinpointdocker/pinpoint-collector:3.1.0-metric
# 원본 Dockerfile : 없음 — jib-maven-plugin 3.4.6 으로 빌드된 이미지다
#                   (pinpoint v3.1.0 pom.xml pluginManagement + collector-starter/pom.xml).
#                   pinpoint CI 는 `mvn jib:build -pl collector-starter` 로 이 이미지를 만든다.
#                   collector-starter/pom.xml 의 jib <to><tags> 가 `${project.version}-metric`,
#                   `latest-metric` 이므로 `-metric` 태그 = collector-starter 모듈 산출물이다.
#                   (`-metric` 없는 태그는 collector 모듈이고 메인 클래스가 CollectorApp 으로 다르다.)
# 원본 base       : jib 기본 base = eclipse-temurin 17 JRE (Ubuntu 26.04 rock 기반)
#                   실측: JAVA_HOME=/opt/java/openjdk, JAVA_VERSION=jdk-17.0.19+10,
#                   config label org.opencontainers.image.title=ubuntu / version=26.04
# 계열 매핑       : ubuntu(glibc) → baseimage/ubuntu:24.04
#
# 방식 — jib 이미지는 Dockerfile 이 없어 "단계를 그대로 옮기는" 래핑이 불가능하다. 대신
#   이 이미지가 실행하는 것과 **동일한 릴리스 산출물**을 pinpoint 공식 GitHub 릴리스에서
#   받아 승인 base 에 얹는다. 동일 산출물이라는 근거(실측):
#     이미지 ENTRYPOINT : java -cp @/app/jib-classpath-file \
#                         com.navercorp.pinpoint.collector.starter.multi.application.PinpointCollectorStarter
#     릴리스 exec jar   : pinpoint-collector-starter-3.1.0-exec.jar
#                         Implementation-Title: pinpoint-collector-starter
#                         Start-Class: com.navercorp.pinpoint.collector.starter.multi.application.PinpointCollectorStarter
#   → 메인 클래스가 정확히 일치한다. 소스 재구성(maven 전체 빌드)이 아니라 벤더가 배포한
#     동일 산출물을 쓰므로 "충실한 래핑"에 해당한다. sha256 은 GitHub 릴리스 API 의 asset digest.
#
# 원본과의 차이 2건
#   1) 기동 방식이 jib 의 펼쳐진 classpath 에서 Spring Boot fat jar(JarLauncher)로 바뀐다.
#      같은 코드·같은 메인 클래스이고, 원본 이미지는 command/args 를 쓰지 않고 설정을 전부
#      환경변수(SPRING_PROFILES_ACTIVE / COLLECTOR_* / PINPOINT_* 등, pinpoint-docker
#      docker-compose-metric.yml 실측)로 주입하므로 드롭인 교체가 된다.
#   2) CVE 조치로 fat jar 안의 tomcat-embed-* 3종을 10.1.44 → 10.1.57 로 교체했다
#      (사용자 승인 2026-08-13). 아래 jarpatch 스테이지 주석 참고.
#
# 원본 런타임 계약(docker inspect 실측): User=""(=root), WorkingDir=""(=/), Cmd 없음,
#   ExposedPorts 없음(compose/helm 이 노출), ENV PATH(/opt/java/openjdk/bin 선두) ·
#   JAVA_HOME=/opt/java/openjdk · LANG/LANGUAGE/LC_ALL=en_US.UTF-8 · JAVA_VERSION
#   JAVA_VERSION 은 옮기지 않는다 — apt 로 설치하는 Temurin 패치 버전이 저장소 최신을 따라가므로
#   원본 값(jdk-17.0.19+10)을 박으면 실제와 어긋난다. 정보성 변수이고 참조하는 코드가 없다.
#
# 원본은 linux/amd64 · linux/arm64 멀티아치다(jib <from><platforms> 실측) → CI 기본 매트릭스 그대로.


# ─────────────────────────────────────────────────────────────────────────────
# stage jarpatch — 릴리스 exec jar 를 받아 CRITICAL 유발 jar 를 교체한다 (출하되지 않는 스테이지)
#
# 왜 필요한가: 원본 exec jar 에 담긴 tomcat-embed-core 10.1.44 가 CRITICAL 3건
#   (CVE-2026-41293 / CVE-2026-43512 / CVE-2026-43515)을 안고 있다. 픽스는 10.1.55+ 에 있는데
#   pinpoint 3.1.0 이 최신 릴리스라 태그 상향으로는 해소되지 않는다. 정책 검수 조건이
#   "Critical CVE 없음"이라 jar 단위로 교체한다.
# 왜 core 만이 아니라 el·websocket 까지 올리는가: tomcat-embed-* 3 모듈은 같은 버전으로 함께
#   릴리스되고 서로 내부 API 를 참조한다. core 만 올려 버전을 섞는 쪽이 오히려 위험하다.
# 왜 안전한가: 10.1.44 → 10.1.57 은 같은 10.1.x 패치 라인이라 바이너리 호환이 유지된다
#   (Spring Boot 3.5.x 가 지원하는 Tomcat 라인). 교체 후 기동 스모크로 검증한다.
# 재패키징 제약: Boot 로더는 BOOT-INF/lib 의 nested jar 가 **무압축(Stored)** 이어야 읽는다
#   (원본 실측: 전 항목 Stored) → zip -0 으로 재패키징한다. jar 파일명은 BOOT-INF/classpath.idx 와
#   BOOT-INF/layers.idx 두 곳에만 적혀 있어 그 문자열만 치환한다. MANIFEST.MF 를 첫 엔트리로
#   넣어야 java.util.jar 가 매니페스트를 찾는다.
# ─────────────────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04 AS jarpatch

USER root

ARG PINPOINT_VERSION=3.1.0
ARG PINPOINT_JAR=pinpoint-collector-starter-3.1.0-exec.jar
ARG PINPOINT_JAR_SHA256=cf5a0b4f4f0b90dcfe5b925ab2149245ddba36efbc3d45dfe732849269049d3a

# 교체 대상 / 교체본 (sha256 은 Maven Central 산출물 실측값)
ARG TOMCAT_EMBED_OLD=10.1.44
ARG TOMCAT_EMBED_NEW=10.1.57
ARG TOMCAT_EMBED_CORE_SHA256=9e230f12579c8c7158df5cbae0479fb93c81a1f1c33c5d56e75605e2074a4fa7
ARG TOMCAT_EMBED_EL_SHA256=d0d0b86ec9d466ccaa8acf948a8c6564f09e21dcccc385805df248a053a3b449
ARG TOMCAT_EMBED_WS_SHA256=335c00fad89e389fe041cad16d22bc83e6ef746571442b3dc5e2a8f0388bad21

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl unzip zip; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /work/patch /work/exploded /patched; \
    cd /work; \
    curl -fsSL -o "${PINPOINT_JAR}" \
        "https://github.com/pinpoint-apm/pinpoint/releases/download/v${PINPOINT_VERSION}/${PINPOINT_JAR}"; \
    echo "${PINPOINT_JAR_SHA256}  ${PINPOINT_JAR}" | sha256sum -c -; \
    for spec in "core:${TOMCAT_EMBED_CORE_SHA256}" \
                "el:${TOMCAT_EMBED_EL_SHA256}" \
                "websocket:${TOMCAT_EMBED_WS_SHA256}"; do \
        a="${spec%%:*}"; sum="${spec#*:}"; \
        f="tomcat-embed-${a}-${TOMCAT_EMBED_NEW}.jar"; \
        curl -fsSL -o "patch/${f}" \
            "https://repo1.maven.org/maven2/org/apache/tomcat/embed/tomcat-embed-${a}/${TOMCAT_EMBED_NEW}/${f}"; \
        echo "${sum}  patch/${f}" | sha256sum -c -; \
    done; \
    cd /work/exploded; \
    unzip -q "/work/${PINPOINT_JAR}"; \
    for a in core el websocket; do \
        test -f "BOOT-INF/lib/tomcat-embed-${a}-${TOMCAT_EMBED_OLD}.jar"; \
        rm -f "BOOT-INF/lib/tomcat-embed-${a}-${TOMCAT_EMBED_OLD}.jar"; \
        cp "/work/patch/tomcat-embed-${a}-${TOMCAT_EMBED_NEW}.jar" BOOT-INF/lib/; \
        sed -i "s|tomcat-embed-${a}-${TOMCAT_EMBED_OLD}.jar|tomcat-embed-${a}-${TOMCAT_EMBED_NEW}.jar|g" \
            BOOT-INF/classpath.idx BOOT-INF/layers.idx; \
    done; \
    grep -q "tomcat-embed-core-${TOMCAT_EMBED_NEW}.jar" BOOT-INF/classpath.idx; \
    ! grep -q "tomcat-embed-.*-${TOMCAT_EMBED_OLD}.jar" BOOT-INF/classpath.idx BOOT-INF/layers.idx; \
    test -z "$(find BOOT-INF/lib -name "tomcat-embed-*-${TOMCAT_EMBED_OLD}.jar")"; \
    zip -q -X -0 "/patched/${PINPOINT_JAR}" META-INF/MANIFEST.MF; \
    zip -q -X -0 -r "/patched/${PINPOINT_JAR}" . -x META-INF/MANIFEST.MF; \
    unzip -v "/patched/${PINPOINT_JAR}" \
        | grep "BOOT-INF/lib/tomcat-embed-core-${TOMCAT_EMBED_NEW}.jar" | grep -q Stored


# ─────────────────────────────────────────────────────────────────────────────
# 런타임 스테이지 (출하)
# ─────────────────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

# baseimage/ubuntu 기본 USER 는 비루트 → 설치 단계 위해 root 로 전환
USER root

# 원본 base(eclipse-temurin:17-jre)의 ENV 와 동일한 로케일
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# 원본 base 와 같은 벤더(Adoptium)의 JRE 17 을 HTTPS apt 저장소로 설치한다.
# fontconfig/tzdata/locales 는 eclipse-temurin base 가 선탑재하던 것과 동일 목적.
# GPG 키는 키서버가 아니라 벤더 HTTPS 로 받아 keyring 에 저장한다.
# 설치 경로는 아키텍처마다 다르므로(temurin-17-jre-amd64 / -arm64) java 실체 경로를 역추적해
# 원본 JAVA_HOME 값인 /opt/java/openjdk 로 링크한다 — ln -sfn 으로 idempotent.
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        fontconfig \
        locales \
        tzdata; \
    locale-gen en_US.UTF-8; \
    install -d /etc/apt/keyrings; \
    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" \
        > /etc/apt/sources.list.d/adoptium.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends temurin-17-jre; \
    JVM_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"; \
    install -d /opt/java; \
    ln -sfn "${JVM_DIR}" /opt/java/openjdk; \
    /opt/java/openjdk/bin/java -version; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=/opt/java/openjdk/bin:${PATH}

# jarpatch 스테이지가 검증·재패키징한 exec jar 만 가져온다.
# ENTRYPOINT 는 ARG 를 전개하지 못하므로 버전 무관 심볼릭 링크를 만들어 그것을 가리킨다.
COPY --from=jarpatch /patched/ /app/
RUN set -eux; \
    jar="$(find /app -maxdepth 1 -name 'pinpoint-collector-starter-*-exec.jar')"; \
    test -n "${jar}"; \
    ln -sfn "${jar}" /app/pinpoint-collector-starter.jar

# 원본 런타임 계약 복원: USER root(=0) + WORKDIR / + Cmd 없음
WORKDIR /
USER root
ENTRYPOINT ["java", "-jar", "/app/pinpoint-collector-starter.jar"]
