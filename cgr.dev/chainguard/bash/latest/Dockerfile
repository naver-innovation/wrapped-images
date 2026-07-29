# 원본 이미지·태그: cgr.dev/chainguard/bash:latest
#   (Chainguard 무료 트랙은 latest 태그만 제공 — 래핑 시점 2026-07-29 기준 bash 5.3.0,
#    digest sha256:ef0932ef7e33b63fe8afd0db73a52013f250c27baa891d1168d7c2066740ff17)
# 원본 base: Wolfi (glibc, apko 빌드 — Dockerfile 없음. 공개 apko 구성:
#   https://github.com/chainguard-images/images/tree/main/images/bash)
# 원본 구성: bash + busybox + curl + ca-certificates,
#   USER root(0), WORKDIR /, ENTRYPOINT ["/bin/bash","-c"], CMD 없음
# 계열 매핑: apk 계열 최소 이미지 → baseimage/alpine
#   (busybox 는 base 에 이미 포함, bash·curl·ca-certificates 만 추가.
#    바이너리 COPY 가 없고 전부 apk 로 설치하므로 musl/glibc 차이 무관)
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root

# baseimage/alpine 기본 apk 미러는 사내망 밖 빌드에서 타임아웃 → 공식 CDN 을
# repositories-file 로 지정해 설치 (kafka-ui 래핑과 동일 패턴)
RUN set -eux; \
    printf '%s\n' \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" \
        > /tmp/apk.repositories; \
    apk add --no-cache --repositories-file /tmp/apk.repositories \
        bash curl ca-certificates; \
    rm -f /tmp/apk.repositories

LABEL org.opencontainers.image.source=https://github.com/chainguard-images/images/tree/main/images/bash
LABEL org.opencontainers.image.description="Wrapped cgr.dev/chainguard/bash:latest (bash 5.x on approved alpine base)"
LABEL org.opencontainers.image.licenses=GPL-3.0-or-later

# 원본과 동일한 런타임 계약: root 실행 + WORKDIR / + SSL_CERT_FILE + bash -c entrypoint
# (baseimage 기본은 비루트 uid 500 / WORKDIR /root — 원본이 root 이므로 명시 복원)
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
WORKDIR /
USER root
ENTRYPOINT ["/bin/bash", "-c"]
