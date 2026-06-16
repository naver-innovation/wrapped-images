# 원본: docker.io/altinity/metrics-exporter:0.27.0
#   https://github.com/Altinity/clickhouse-operator (tag 0.27.0, dockerfile/metrics-exporter/Dockerfile, target stage: image-prod)
# 원본 base:
#   builder    : golang:${GO_VERSION:-latest}          (debian / glibc 계열)
#   image-base : gcr.io/distroless/static-debian13     (정적 Go 바이너리 base)
# 계열 매핑:
#   builder    : golang(debian) 유지 — 원본 빌드 스크립트(bash ./dev/...)·go.mod(go 1.26.2) 그대로 사용.
#   runtime    : distroless/static 는 CGO_ENABLED=0 정적 Go 바이너리 base → 허용 base 아무거나 가능.
#                최소 크기로 baseimage/alpine 로 통일.
# 원본은 빌드 컨텍스트(레포)를 ADD . . 로 넣지만, CI 는 **/Dockerfile 만 빌드(레포 컨텍스트 없음)
#   → 빌더에서 0.27.0 태그를 git clone 하여 소스를 재구성한다.
# 원본 builder 가 정적 bash/curl(glibc) 을 받아 distroless 로 COPY 하던 부분은 musl 인 alpine 과 호환되지 않으므로
#   런타임에서 apk(bash, curl)로 대체한다. (yq 는 원본에서도 런타임 이미지에 포함되지 않음 → 생략)
ARG GIT_TAG=0.27.0
# 원본 go.mod 의 go 1.26.2 에 맞춤. 원본 golang(debian) 계열 유지.
ARG GO_VERSION=1.26.2

# ── builder (원본 golang builder 유지) ──────────────────────────────────────────
FROM golang:${GO_VERSION} AS builder

# 원본 builder 패키지 (bash 빌드 스크립트 실행 + git clone 용).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        bash \
        gettext-base \
        wget \
        xz-utils && \
    rm -rf /var/lib/apt/lists/*

ARG GIT_TAG
# 원본은 ADD . . 로 컨텍스트를 넣지만, 레포 컨텍스트가 없으므로 태그를 직접 clone.
WORKDIR /clickhouse-operator
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/Altinity/clickhouse-operator.git .
RUN go mod download

# 원본과 동일하게 정적 바이너리(/tmp/metrics-exporter) 빌드.
RUN METRICS_EXPORTER_BIN=/tmp/metrics-exporter bash -xe ./dev/go_build_metrics_exporter.sh

# ── runtime (원본 image-base + image-prod 통합) ─────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/Altinity/clickhouse-operator
LABEL org.opencontainers.image.description="Metrics exporter for Altinity ClickHouse operator"
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL name="ClickHouse operator. Metrics exporter" \
      maintainer="Altinity <support@altinity.com>" \
      vendor="Altinity" \
      summary="Metrics exporter" \
      description="Metrics exporter for Altinity ClickHouse operator"

# baseimage/alpine 은 기본 USER 가 비루트 → apk/배치 위해 root 로 전환 (마지막에 nobody 로 복귀).
USER root
# 원본이 distroless 로 COPY 하던 정적 bash/curl(glibc) 대신 musl 호환 패키지로 대체.
RUN apk add --no-cache bash curl

# 원본 image-base: 라이선스 + 기본 config 를 이미지에 포함.
COPY --from=builder /clickhouse-operator/LICENSE /licenses/
COPY --from=builder /clickhouse-operator/config /etc/clickhouse-operator/

WORKDIR /
# 원본과 동일하게 바이너리를 / 에 배치.
COPY --from=builder /tmp/metrics-exporter /metrics-exporter

# 원본 image-prod 의 비루트 USER(nobody=65534, MustRunAsNonRoot) 유지.
USER nobody

# Run /metrics-exporter -logtostderr=true -v=1
ENTRYPOINT ["/metrics-exporter"]
CMD ["-logtostderr=true", "-v=1"]
