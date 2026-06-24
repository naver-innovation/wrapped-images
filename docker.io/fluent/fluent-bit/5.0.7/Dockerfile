# syntax=docker/dockerfile:1
# fluent-bit v5.0.7 — 소스 빌드 wrapper.
#   upstream: https://github.com/fluent/fluent-bit  (tag v5.0.7)
# 계열 매핑: RHEL/dnf 계열 → baseimage/navix:10.1-wasl-centos  (CentOS Stream 10 / el10)
#
# 공식 RPM 은 librdkafka 가 zlib 없이 빌드되어 Kafka gzip 압축을 지원하지 않으므로,
# zlib 를 링크한 fluent-bit 을 소스에서 빌드한다. 아래 부가 도구를 함께 동봉한다:
#   - kafka-preflight : kcat 으로 Kafka broker 접속/인증을 사전 검증
#   - metrics-proxy   : fluent-bit HTTP_Server 의 고정 metrics path 를 커스텀 path 로 alias
#   - prestop.sh      : preStop 시 메인 컨테이너 종료 후 sidecar 를 drain
#   - parsers.conf    : json 파서
# 설정(fluent-bit.conf)·CA 인증서·자격증명은 런타임 외부 주입(이미지 미포함).
#
# el10(navix) 빌드 보정 (로컬 빌드로 검증):
#   1) navix 기본 USER 는 비루트 → 설치/빌드 위해 USER root.
#   2) c10s 는 zlib → zlib-ng 로 교체. zlib-devel/zlib → zlib-ng-compat-devel/zlib-ng-compat
#      (pkgconfig(zlib)·libz.so.1 을 동일 제공하므로 fluent-bit 빌드/런타임 호환).
#   3) libyaml-devel 은 CRB 에만 존재하나 navix 는 CRB repo 미정의 → CRB repo 를 추가
#      (base 의 centos-stream-10.repo 와 동일 정책: mirror.stream.centos.org, gpgcheck=0).
#   4) kcat 은 EPEL 에만 존재 → epel-release(el10) 를 Fedora HTTPS RPM 으로 설치.
#   5) cyrus-sasl-devel·cyrus-sasl-scram·openssl-devel·cmake 등은 el10 appstream/baseos 에 존재.
#   6) jq 보정 설치. curl/bash/python3/tar/gzip 은 navix 기본 포함.
ARG FLB_VERSION=5.0.7

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos AS builder

ARG FLB_VERSION

# navix 기본 USER 는 비루트 → dnf/빌드 위해 root 로 전환.
USER root

# 빌드 의존 설치. CRB(libyaml-devel)는 navix 에 미정의이므로 base 와 동일 정책으로 repo 추가.
# $basearch 는 dnf 가 치환하도록 리터럴로 기록한다(single-quote 로 셸 확장 방지).
RUN set -eux; \
    printf '%s\n' \
      '[crb]' \
      'name=CentOS Stream 10 - CRB' \
      'baseurl=https://mirror.stream.centos.org/10-stream/CRB/$basearch/os/' \
      'gpgcheck=0' \
      'enabled=1' \
      > /etc/yum.repos.d/centos-crb.repo; \
    dnf -y install \
      cmake gcc gcc-c++ flex bison make \
      zlib-ng-compat-devel openssl-devel libyaml-devel cyrus-sasl-devel \
      tar gzip; \
    dnf clean all

WORKDIR /build
RUN curl -fsSL "https://github.com/fluent/fluent-bit/archive/refs/tags/v${FLB_VERSION}.tar.gz" | tar xz

WORKDIR /build/fluent-bit-${FLB_VERSION}/build
RUN cmake .. \
      -DCMAKE_INSTALL_PREFIX=/opt/fluent-bit \
      -DFLB_RELEASE=On \
      -DFLB_TRACE=Off \
      -DFLB_TESTS_INTERNAL=Off \
      -DFLB_TESTS_RUNTIME=Off \
  && make -j"$(nproc)" \
  && make install


FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

LABEL org.opencontainers.image.source="https://github.com/fluent/fluent-bit"
LABEL org.opencontainers.image.description="Fluent Bit v5.0.7 (zlib/gzip source build) with kafka preflight + metrics path-alias tooling, wrapped onto baseimage/navix"
LABEL org.opencontainers.image.licenses="Apache-2.0"

USER root

# 런타임 의존:
#   zlib-ng-compat            : libz.so.1 (Kafka gzip)         — c10s zlib 대체
#   cyrus-sasl, cyrus-sasl-scram : SASL_SSL / SCRAM-SHA-256·512 메커니즘 dlopen (둘 다 el10 baseos)
#   kcat                      : kafka-preflight (EPEL)
#   jq, python3               : kafka-preflight / metrics-proxy
# epel-release(el10)는 Fedora HTTPS RPM 으로 설치(navix 에 epel/extras repo 미정의).
RUN set -eux; \
    dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm"; \
    dnf -y install \
      zlib-ng-compat openssl libyaml jq python3 \
      cyrus-sasl cyrus-sasl-scram \
      kcat; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum; \
    getent passwd fluent-bit >/dev/null 2>&1 \
      || useradd -u 1000 -M -s /sbin/nologin fluent-bit 2>/dev/null \
      || useradd -M -s /sbin/nologin fluent-bit

COPY --from=builder /opt/fluent-bit /opt/fluent-bit

COPY parsers.conf /etc/fluent-bit/parsers.conf
COPY scripts/prestop.sh /usr/local/bin/prestop.sh
COPY scripts/kafka-preflight /usr/local/bin/kafka-preflight
COPY scripts/metrics-proxy /usr/local/bin/metrics-proxy
COPY scripts/fluent-bit-entrypoint.sh /usr/local/bin/fluent-bit-entrypoint.sh
RUN chmod +x /usr/local/bin/prestop.sh \
      /usr/local/bin/kafka-preflight \
      /usr/local/bin/metrics-proxy \
      /usr/local/bin/fluent-bit-entrypoint.sh

USER fluent-bit

# 2020: fluent-bit HTTP_Server (고정 path /api/v1/metrics/prometheus 등)
# metrics-proxy 는 METRICS_PROXY_PATH + METRICS_PROXY_PORT 가 모두 설정된 경우에만 기동.
EXPOSE 2020

ENTRYPOINT ["/usr/local/bin/fluent-bit-entrypoint.sh"]
CMD ["-c", "/etc/fluent-bit/fluent-bit.conf"]
HEALTHCHECK NONE
