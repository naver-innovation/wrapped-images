# 원본: docker.io/altinity/clickhouse-operator:0.27.0
#   https://github.com/Altinity/clickhouse-operator (tag 0.27.0, Dockerfile: dockerfile/operator/Dockerfile, target stage: image-prod)
# 원본 base:
#   builder      : golang:${GO_VERSION}              (debian / glibc 계열, apt 사용 — build-only)
#   delve-builder: golang:${GO_VERSION}              (debug 이미지 전용, image-prod 와 무관 → 미사용)
#   image-base   : gcr.io/distroless/static-debian13 (정적 바이너리용 distroless base)
# 계열 매핑:
#   builder    : golang (debian/glibc) → 그대로 유지 (build-only, apt 의존).
#   runtime    : distroless/static-debian13 (debian 계열) → baseimage/ubuntu:24.04 로 교체.
#                원본은 distroless(셸 없음)에 정적 bash/curl 을 COPY 해 넣었으나,
#                ubuntu base 는 셸을 이미 포함하므로 정적 bash/sh COPY 는 제거하고
#                정적 curl 만 유지(원본 호환). 운영 진입점(image-prod)만 래핑.
# 소스는 벤더링 대신 빌더에서 0.27.0 태그를 git clone (CI 가 Dockerfile 단독으로 빌드 → 레포 컨텍스트 부재).
ARG GIT_TAG=0.27.0
ARG GO_VERSION=1.26.2

# ===================
# ===== Builder =====
# ===================
FROM --platform=${BUILDPLATFORM} golang:${GO_VERSION} AS builder

ARG TARGETOS
ARG TARGETARCH
ARG GCFLAGS

# Install required packages
RUN apt-get update && \
    apt-get install -y apt-utils && \
    apt-get install -y gettext-base wget xz-utils git ca-certificates
RUN wget -O /usr/bin/yq --progress=bar:force:noscroll "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/bin/yq
RUN PLATFORM="x86_64" && if [ "${TARGETARCH}" = "arm64" ]; then PLATFORM="aarch64"; fi && \
    CURL_VERSION=$(wget -qO- https://github.com/stunnel/static-curl/releases/latest 2>&1 | grep -oE 'tag/[0-9.]+' | head -n1 | cut -d'/' -f2) && \
    wget -O /tmp/curl.tar.xz --progress=bar:force:noscroll "https://github.com/stunnel/static-curl/releases/download/${CURL_VERSION}/curl-linux-${PLATFORM}-glibc-${CURL_VERSION}.tar.xz" && \
    tar -xf /tmp/curl.tar.xz -C /tmp/ && \
    chmod +x /tmp/curl && \
    rm -f /tmp/curl.tar.xz

# Reconstruct source tree inside docker (레포 컨텍스트 부재 → 태그 고정 git clone 으로 대체)
ARG GIT_TAG
WORKDIR /clickhouse-operator
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/Altinity/clickhouse-operator.git .
RUN go mod download
ENV GOOS="${TARGETOS}"
ENV GOARCH="${TARGETARCH}"
ENV GCFLAGS="${GCFLAGS}"

# Build operator binary with explicitly specified output
RUN OPERATOR_BIN=/tmp/clickhouse-operator bash -xe ./dev/go_build_operator.sh

# ======================
# ===== Image Prod =====
# ======================
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04 AS image-prod
ARG VERSION

LABEL name="ClickHouse operator" \
      maintainer="Altinity <support@altinity.com>" \
      vendor="Altinity" \
      version="${VERSION:-unspecified_version}" \
      summary="ClickHouse operator" \
      description="ClickHouse operator operates ClickHouse clusters in kubernetes"
LABEL org.opencontainers.image.source=https://github.com/Altinity/clickhouse-operator
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/ubuntu 는 기본 USER 가 비루트 → 파일 배치 위해 root 로 전환
USER root

COPY --from=builder /clickhouse-operator/LICENSE /licenses/

WORKDIR /

# Add config files from cloned source into image
COPY --from=builder /clickhouse-operator/config /etc/clickhouse-operator/

# Copy clickhouse-operator binary into operator image from builder.
# (ubuntu base 는 셸 내장 → 정적 bash/sh COPY 생략, 원본의 정적 curl 만 유지)
COPY --from=builder /tmp/clickhouse-operator .
COPY --from=builder /tmp/curl /bin/curl

# 원본 image-prod 의 비루트 USER(nobody) 유지
USER nobody

# Run /clickhouse-operator -alsologtostderr=true -v=1
# We can specify additional options, such as:
#   --config=/path/to/config
#   --kube-config=/path/to/kubeconf
ENTRYPOINT ["/clickhouse-operator"]
CMD ["-logtostderr=true", "-v=1"]
