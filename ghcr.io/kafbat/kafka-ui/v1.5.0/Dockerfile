# 원본: ghcr.io/kafbat/kafka-ui:v1.5.0
#   https://github.com/kafbat/kafka-ui (tag v1.5.0, api/Dockerfile)
# 원본 base:
#   azul/zulu-openjdk-alpine:25.0.2-jre-headless@sha256:ff319ed64315a5deed026bb6c8d78b8c446d2de2a9f525b4cf6f819b847fc709
# 계열 매핑: alpine -> baseimage/alpine
# 보정 사항:
#   - baseimage/alpine 은 기본 USER 가 비루트 -> apk/설치 위해 USER root 로 전환.
#   - upstream release jar(api-v1.5.0.jar)를 tag 고정 URL에서 받아 sha256 검증 후 /api.jar 로 배치.
#   - 원본의 gcompat/tzdata, kafkaui 유저, /etc/kafkaui, JAVA_OPTS, CMD 를 유지.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source=https://github.com/kafbat/kafka-ui
LABEL org.opencontainers.image.description="Open-Source Web UI for managing Apache Kafka clusters"
LABEL org.opencontainers.image.licenses=Apache-2.0

ARG KAFKA_UI_VERSION=v1.5.0
ARG KAFKA_UI_JAR_SHA256=8bebff7b21ddb084b5b647e271136f7d97f46da6c7bc70f9cd47775dfbd3c10e

USER root

RUN set -eux; \
    printf '%s\n' \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" \
        > /tmp/apk.repositories; \
    apk add --no-cache --repositories-file /tmp/apk.repositories \
        ca-certificates gcompat openjdk25-jre-headless tzdata wget; \
    addgroup -S kafkaui 2>/dev/null || true; \
    adduser -S kafkaui -G kafkaui 2>/dev/null || true; \
    wget -qO /api.jar "https://github.com/kafbat/kafka-ui/releases/download/${KAFKA_UI_VERSION}/api-${KAFKA_UI_VERSION}.jar"; \
    echo "${KAFKA_UI_JAR_SHA256}  /api.jar" | sha256sum -c -; \
    mkdir -p /etc/kafkaui; \
    chown -R kafkaui:kafkaui /etc/kafkaui /api.jar; \
    rm -f /tmp/apk.repositories

USER kafkaui

ENV JAVA_OPTS=

EXPOSE 8080

CMD java --add-opens java.rmi/javax.rmi.ssl=ALL-UNNAMED $JAVA_OPTS -jar /api.jar
