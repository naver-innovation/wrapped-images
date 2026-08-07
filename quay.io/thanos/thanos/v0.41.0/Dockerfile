# 원본 이미지·태그: quay.io/thanos/thanos:v0.41.0
# 원본 base: quay.io/prometheus/busybox (최소 busybox 이미지)
# 원본 빌드: thanos-io/thanos 의 Dockerfile.multi-stage —
#   golang:1.24.0-alpine3.20 builder 에서 make build(promu) 후 /go/bin/thanos 복사
# 계열 매핑: busybox → baseimage/alpine
# 원본 런타임 계약(docker inspect 실측): USER 1001(thanos), WORKDIR /,
#   ENTRYPOINT ["/bin/thanos"], CMD 없음
ARG GIT_TAG=v0.41.0

# 빌드 전용 stage (출하 안 됨). 원본 Dockerfile.multi-stage 는 golang:1.24.0-alpine3.20 을
# 핀하지만 v0.41.0 의 go.mod 가 go >= 1.25.0 을 요구해 빌드 불가
# (golang 공식 이미지는 GOTOOLCHAIN=local 이라 자동 상향도 안 됨) → 1.25 로 상향
FROM docker.io/library/golang:1.25-alpine AS builder
WORKDIR $GOPATH/src/github.com/thanos-io/thanos
RUN apk update && apk add --no-cache alpine-sdk
# 원본은 COPY . (로컬 빌드 컨텍스트) — 컨텍스트 없이 재현하도록 태그 핀 git clone 으로 대체
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/thanos-io/thanos.git .
# 이하 원본 Dockerfile.multi-stage 와 동일
RUN git update-index --refresh; make build

# -----------------------------------------------------------------------------

# 런타임 stage(출하): 원본 quay.io/prometheus/busybox → baseimage/alpine 교체
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL maintainer="The Thanos Authors"
LABEL org.opencontainers.image.source=https://github.com/thanos-io/thanos
LABEL org.opencontainers.image.description="Wrapped quay.io/thanos/thanos:v0.41.0 (thanos on approved alpine base)"
LABEL org.opencontainers.image.licenses=Apache-2.0
USER root

# base 선탑재 패키지 구버전 CVE 보정(bind/c-ares/curl 등 Trivy HIGH) — apk upgrade 필수.
# 기본 apk 미러는 사내망 밖 빌드에서 타임아웃 → 공식 CDN 을 repositories-file 로 지정
# (chainguard-bash·kafka-ui 래핑과 동일 패턴)
RUN set -eux; \
    printf '%s\n' \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" \
        > /tmp/apk.repositories; \
    apk upgrade --no-cache --repositories-file /tmp/apk.repositories; \
    rm -f /tmp/apk.repositories

COPY --from=builder /go/bin/thanos /bin/thanos

# 원본과 동일한 uid 1001 thanos 유저 생성 (base 에 1001 미선점 — 실측 확인)
RUN adduser -D -H -u 1001 thanos && chown thanos /bin/thanos

# 원본 런타임 계약 복원: USER 1001 + WORKDIR /
# (baseimage 기본 WORKDIR /root(0700) 는 uid 1001 이 traverse 불가 → 명시 필수)
WORKDIR /
USER 1001
ENTRYPOINT ["/bin/thanos"]
