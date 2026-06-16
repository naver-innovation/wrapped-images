# 원본: docker.io/pinpointdocker/pinpoint-collector:3.0.5-metric
#   https://github.com/pinpoint-apm/pinpoint (tag v3.0.5, module: collector-starter)
#
# ⚠️ 원본 이미지에는 공개 Dockerfile 이 없다.
#   pinpoint 3.x collector 이미지는 Spring Boot Cloud Native Buildpacks(Paketo)로 빌드된다.
#   (pinpoint/.github/workflows/create-dockerfiles.yml):
#     mvn -pl collector-starter clean package spring-boot:build-image ...
#   즉 FROM 기반 Dockerfile 이 존재하지 않으므로, 동일 산출물(collector-starter 부트 실행 jar)을
#   동일하게 기동하는 멀티스테이지 Dockerfile 로 재구성한다.
#
# `-metric` 변이:
#   collector-starter pom 의 spring-boot-maven-plugin <image><tags> 가
#   pinpoint-collector:${version}-metric / latest-metric 로 태깅한다.
#   collector-starter 모듈이 pinpoint-metric / pinpoint-otlpmetric-collector 를
#   직접 의존하므로, 이 모듈을 빌드하면 곧 metric 변이다 (별도 프로파일 플래그 없음).
#
# 원본 base 계열:
#   builder  : (Paketo 빌드) — Java 17 (JAVA_17_HOME) 로 Maven 리액터 빌드
#   runtime  : Paketo run image (Ubuntu Jammy + BellSoft Liberica JRE) — Java 기반
# 계열 매핑:
#   builder  : build-only → 업스트림 공식 maven:eclipse-temurin-17 (JDK17) 유지
#   runtime  : Ubuntu 기반 JRE 런타임 → baseimage/ubuntu:24.04 (JRE 17 apt 설치)
ARG GIT_TAG=v3.0.5
ARG PINPOINT_VERSION=3.0.5

# ── builder (collector-starter 부트 실행 jar 빌드) ──────────────────────────────
# build-only 단계이므로 업스트림 공식 maven(JDK17) 이미지를 그대로 사용한다.
FROM maven:3.9-eclipse-temurin-17 AS builder
ARG GIT_TAG
WORKDIR /build
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/pinpoint-apm/pinpoint.git .
# collector-starter 와 그 리액터 의존 모듈만 빌드(-am). 부트 실행 jar 산출:
#   collector-starter/target/deploy/pinpoint-collector-starter-<ver>-exec.jar
RUN mvn -B -pl collector-starter -am clean package -DskipTests=true

# ── runtime (Paketo run image 대체: Ubuntu + JRE 17) ───────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
ARG PINPOINT_VERSION
LABEL org.opencontainers.image.source=https://github.com/pinpoint-apm/pinpoint
LABEL org.opencontainers.image.description="Pinpoint Collector (metric variant) - APM collector"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/ubuntu 는 기본 USER 가 비루트 → apt 설치 위해 root 로 전환
USER root
# Paketo run image 가 제공하던 JRE 17 을 apt 로 설치 (HTTPS 미러). ca-certificates 포함.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /pinpoint
# 부트 실행 jar 만 런타임으로 복사 (buildpack 산출물과 동일한 단일 실행 아티팩트).
# classifier=exec / outputDirectory=target/deploy (collector-starter pom 설정).
# 버전 문자열 의존을 피하려 와일드카드로 복사하고 UID 1000 소유로 고정한다.
COPY --from=builder --chown=1000:1000 /build/collector-starter/target/deploy/pinpoint-collector-starter-*-exec.jar /pinpoint/pinpoint-collector-starter.jar

# 비루트 실행 (원본 buildpack 런타임도 비루트 cnb 유저로 기동).
# 이름 해석 의존을 피하려 숫자 UID(1000, ubuntu 기본 비루트) 로 지정한다.
USER 1000

ENTRYPOINT ["java", "-jar", "/pinpoint/pinpoint-collector-starter.jar"]
