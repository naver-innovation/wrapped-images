# syntax=docker/dockerfile:1
# fluent-bit v5.1.0 — 소스 빌드 wrapper.
#   upstream: https://github.com/fluent/fluent-bit  (tag v5.1.0)
# 계열 매핑: RHEL/dnf 계열 → baseimage/navix:10.1-wasl-centos  (CentOS Stream 10 / el10)
#
# 공식 RPM 은 librdkafka 가 zlib 없이 빌드되어 Kafka gzip 압축을 지원하지 않으므로,
# zlib 를 링크한 fluent-bit 을 소스에서 빌드한다. 아래 부가 도구를 함께 동봉한다:
#   - kcat            : kafka-preflight 가 쓰는 Kafka CLI (librdkafka 소스 빌드, 아래 참고)
#   - kafka-preflight : kcat 으로 Kafka broker 접속/인증을 사전 검증
#   - metrics-proxy   : fluent-bit HTTP_Server 의 고정 metrics path 를 커스텀 path 로 alias
#   - prestop.sh      : preStop 시 메인 컨테이너 종료 후 sidecar 를 drain
#   - parsers.conf    : json 파서
# 설정(fluent-bit.conf)·CA 인증서·자격증명은 런타임 외부 주입(이미지 미포함).
#
# librdkafka 2.6.1 이상 필수 (5.0.7 대비 변경점):
#   OCI 가 Kafka 클러스터를 4.0.0 으로 강제 업그레이드했다. Kafka 4.0 은 SCRAM nonce 검증이
#   엄격해져, librdkafka 2.6.0 이하 클라이언트는 비밀번호가 맞아도 인증이 거부된다
#   ("Authentication failed ... invalid credentials with SASL mechanism SCRAM-SHA-512").
#   - fluent-bit 은 소스 트리에 librdkafka 를 번들하므로 영향 없다 (v5.1.0 = 2.15.0).
#   - kcat 은 EPEL el10 rpm 이 시스템 librdkafka.so.1 을 동적 링크하는데, c10s AppStream 이
#     주는 버전이 2.1.1 이라 인증이 실패했다. 그래서 EPEL kcat 을 버리고 librdkafka·kcat 을
#     소스에서 빌드해 /opt/kcat 에 담는다. 런타임 epel-release 의존도 함께 사라진다.
#   librdkafka 버전은 fluent-bit 번들과 같은 값으로 맞춘다 (같은 이미지 안에서 두 클라이언트
#   동작이 갈리지 않도록).
#
# el10(navix) 빌드 보정 (로컬 빌드로 검증):
#   1) navix 기본 USER 는 비루트 → 설치/빌드 위해 USER root.
#   2) c10s 는 zlib → zlib-ng 로 교체. zlib-devel/zlib → zlib-ng-compat-devel/zlib-ng-compat
#      (pkgconfig(zlib)·libz.so.1 을 동일 제공하므로 fluent-bit 빌드/런타임 호환).
#   3) libyaml-devel 은 CRB 에만 존재하나 navix 는 CRB repo 미정의 → CRB repo 를 추가
#      (base 의 centos-stream-10.repo 와 동일 정책: mirror.stream.centos.org, gpgcheck=0).
#   4) cyrus-sasl-devel·cyrus-sasl-scram·openssl-devel·cmake 등은 el10 appstream/baseos 에 존재.
#   5) jq 는 el10 baseos 에 존재. curl/bash/python3/tar/gzip 은 navix 기본 포함.
ARG FLB_VERSION=5.1.0
ARG LIBRDKAFKA_VERSION=2.15.0
ARG KCAT_VERSION=1.7.1

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos AS builder

ARG FLB_VERSION
ARG LIBRDKAFKA_VERSION
ARG KCAT_VERSION

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

# librdkafka → /opt/kcat. curl(OAUTHBEARER OIDC)·zstd·lz4-ext 는 preflight 가 쓰지 않으므로 끈다.
# 남기는 것: ssl(SASL_SSL), sasl(SCRAM), zlib.
WORKDIR /build
RUN set -eux; \
    curl -fsSL "https://github.com/confluentinc/librdkafka/archive/refs/tags/v${LIBRDKAFKA_VERSION}.tar.gz" | tar xz; \
    cd "librdkafka-${LIBRDKAFKA_VERSION}"; \
    ./configure \
      --prefix=/opt/kcat \
      --enable-ssl --enable-sasl --enable-zlib \
      --disable-curl --disable-zstd --disable-lz4-ext; \
    make -j"$(nproc)"; \
    make install

# kcat 은 위에서 만든 librdkafka 를 pkg-config 로 찾게 하고, 런타임 탐색 경로를 rpath 로 고정한다
# (LD_LIBRARY_PATH 주입 없이 /opt/kcat/bin/kcat 단독 실행 가능).
RUN set -eux; \
    curl -fsSL "https://github.com/edenhill/kcat/archive/refs/tags/${KCAT_VERSION}.tar.gz" | tar xz; \
    cd "kcat-${KCAT_VERSION}"; \
    export PKG_CONFIG_PATH=/opt/kcat/lib/pkgconfig:/opt/kcat/lib64/pkgconfig; \
    export LDFLAGS="-Wl,-rpath,/opt/kcat/lib -Wl,-rpath,/opt/kcat/lib64"; \
    ./configure --prefix=/opt/kcat; \
    make -j"$(nproc)"; \
    make install; \
    /opt/kcat/bin/kcat -V


FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

LABEL org.opencontainers.image.source="https://github.com/fluent/fluent-bit"
LABEL org.opencontainers.image.description="Fluent Bit v5.1.0 (zlib/gzip source build) with kafka preflight + metrics path-alias tooling, wrapped onto baseimage/navix"
LABEL org.opencontainers.image.licenses="Apache-2.0"

USER root

# 런타임 의존:
#   zlib-ng-compat            : libz.so.1 (Kafka gzip)         — c10s zlib 대체
#   cyrus-sasl, cyrus-sasl-scram : SASL_SSL / SCRAM-SHA-256·512 메커니즘 dlopen (둘 다 el10 baseos)
#   jq, python3               : kafka-preflight / metrics-proxy
# kcat 은 rpm 대신 builder 에서 소스 빌드해 /opt/kcat 로 복사한다(위 librdkafka 주석 참고).
RUN set -eux; \
    dnf -y install \
      zlib-ng-compat openssl libyaml jq python3 \
      cyrus-sasl cyrus-sasl-scram; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum; \
    getent passwd fluent-bit >/dev/null 2>&1 \
      || useradd -u 1000 -M -s /sbin/nologin fluent-bit 2>/dev/null \
      || useradd -M -s /sbin/nologin fluent-bit

COPY --from=builder /opt/fluent-bit /opt/fluent-bit
COPY --from=builder /opt/kcat /opt/kcat

# kafka-preflight 는 kcat 을 PATH 에서 찾는다.
RUN ln -sf /opt/kcat/bin/kcat /usr/local/bin/kcat

COPY parsers.conf /etc/fluent-bit/parsers.conf
COPY scripts/prestop.sh /usr/local/bin/prestop.sh
COPY scripts/kafka-preflight /usr/local/bin/kafka-preflight
COPY scripts/metrics-proxy /usr/local/bin/metrics-proxy
COPY scripts/fluent-bit-entrypoint.sh /usr/local/bin/fluent-bit-entrypoint.sh
RUN chmod +x /usr/local/bin/prestop.sh \
      /usr/local/bin/kafka-preflight \
      /usr/local/bin/metrics-proxy \
      /usr/local/bin/fluent-bit-entrypoint.sh

# 빌드 게이트: kcat 이 실제로 링크한 librdkafka 가 2.6.1 이상인지 확인한다.
# 미달이면 Kafka 4.0 에서 SCRAM 인증이 거부되므로 이미지를 만들지 않는다.
# kcat -V 출력 예: "Version 1.7.1 (JSON, librdkafka 2.15.0 builtin.features=...)"
RUN set -eux; \
    /opt/kcat/bin/kcat -V; \
    rdk=$(/opt/kcat/bin/kcat -V | sed -n 's/.*librdkafka \([0-9.]*\).*/\1/p'); \
    echo "kcat librdkafka=${rdk}"; \
    [ "$(printf '2.6.1\n%s\n' "$rdk" | sort -V | head -1)" = "2.6.1" ] \
      || { echo "librdkafka ${rdk} < 2.6.1 — Kafka 4.0 SCRAM 인증 불가"; exit 1; }

USER fluent-bit

# 2020: fluent-bit HTTP_Server (고정 path /api/v1/metrics/prometheus 등)
# metrics-proxy 는 METRICS_PROXY_PATH + METRICS_PROXY_PORT 가 모두 설정된 경우에만 기동.
EXPOSE 2020

ENTRYPOINT ["/usr/local/bin/fluent-bit-entrypoint.sh"]
CMD ["-c", "/etc/fluent-bit/fluent-bit.conf"]
HEALTHCHECK NONE
