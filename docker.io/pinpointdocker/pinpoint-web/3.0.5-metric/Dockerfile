# 원본: docker.io/pinpointdocker/pinpoint-web:3.0.5-metric
#   https://github.com/pinpoint-apm/pinpoint (tag v3.0.5, module: web-starter)
#
# ⚠️ 공개 Dockerfile 없음:
#   pinpoint-web 이미지는 Spring Boot Maven plugin 의 build-image(Paketo Buildpacks)로
#   생성됨 — 손으로 쓴 Dockerfile 도, 명시적 FROM 도 존재하지 않음(pinpoint-docker repo 의
#   pinpoint-web/Dockerfile 없음, 메인 pinpoint repo 도 buildpack 빌드).
#   따라서 buildpack 산출물과 동등한 다단계 Dockerfile 을 소스(v3.0.5)에서 재구성한다.
#
# -metric 변형 (3.0.5-metric 태그):
#   web-starter 모듈 = web 기본 모듈 + pinpoint-metric / pinpoint-otlpmetric-web 의존성 포함.
#   mainClass: com.navercorp.pinpoint.web.starter.multi.PinpointWebStarter
#   (기본 3.0.5 태그는 web 모듈, mainClass com.navercorp.pinpoint.web.WebApp)
#   web-starter/pom.xml 의 spring-boot build-image 가 pinpoint-web:${version}-metric 로 태깅.
#
# 원본 base (buildpack 산출):
#   builder  : Paketo builder (Ubuntu Jammy) — Maven + JDK
#   runtime  : Paketo run image (Ubuntu Jammy) + JRE
# 계열 매핑:
#   builder  : 빌드 전용 → upstream 유지 (eclipse-temurin JDK 17, Spring Boot 3.5.5 요구)
#   runtime  : Ubuntu 계열 → baseimage/ubuntu:24.04 (JRE 는 apt 로 설치)
#
# Spring Boot 3.5.5 → JDK 17+ 필요. buildpack 기본(Spring Boot 3.x)도 Java 17.
#
# ⚠️ amd64 전용:
#   원본 3.0.5-metric 매니페스트는 linux/amd64 단일 아키텍처만 제공.
#   빌드 매트릭스를 amd64 로 제한해야 함(arm64 미지원).
ARG GIT_TAG=v3.0.5

# ── builder (소스에서 web-starter exec jar 빌드) ────────────────────────────────
FROM eclipse-temurin:17-jdk-jammy AS builder

# git clone 및 mvnw 실행을 위한 도구
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG GIT_TAG
WORKDIR /build
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/pinpoint-apm/pinpoint.git .

# web-starter(=-metric 변형) 와 그 reactor 의존 모듈만 빌드. 테스트는 스킵.
# Maven Wrapper 사용(저장소 고정 버전), build-image(buildpack) 단계는 제외하고 jar 만 생성.
RUN ./mvnw -B -ntp install -pl web-starter -am -DskipTests=true

# spring-boot-maven-plugin 산출물: web-starter/target/deploy/*-exec.jar
RUN cp "$(ls web-starter/target/deploy/pinpoint-web-starter-*-exec.jar | head -n 1)" /pinpoint-web-boot.jar

# ── runtime ─────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/pinpoint-apm/pinpoint
LABEL org.opencontainers.image.description="pinpoint-web (3.0.5-metric) - Pinpoint APM Web UI, metric-enabled variant"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/ubuntu 기본 USER 가 비루트 → apt 설치 위해 root 로 전환
USER root

# 런타임 JRE 설치 (Spring Boot 3.5.5 → JDK 17). buildpack run image 와 동등.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openjdk-17-jre-headless ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /pinpoint-web-boot.jar /pinpoint-web-boot.jar

# 원본 web-starter application.yml 기본값
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/pinpoint-web-boot.jar"]
