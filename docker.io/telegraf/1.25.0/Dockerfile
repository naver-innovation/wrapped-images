# 원본: docker.io/telegraf:1.25.0  (official library telegraf, debian variant = 기본 태그)
#   https://github.com/influxdata/influxdata-docker (telegraf/1.25/Dockerfile @ v1.25.0, commit dbc4201)
# 원본 base: FROM buildpack-deps:bullseye-curl  (Debian 11 / glibc 계열)
# 계열 매핑: debian → baseimage/ubuntu  (glibc 유지 — apt/dpkg/setpriv 경로 그대로 보존)
# buildpack-deps 가 기본 제공하던 curl/wget/gnupg 중 일부가 stripped base 에 없을 수 있어 명시 설치한다.
# telegraf 1.25.0 은 influxdata 서명 .deb 를 GPG 검증 후 dpkg 설치 → telegraf 유저/바이너리(/usr/bin/telegraf) 생성.
# entrypoint.sh 는 upstream v1.25.0 에서 그대로 벤더링.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/influxdata/influxdata-docker
LABEL org.opencontainers.image.description="Telegraf - the plugin-driven server agent for collecting and reporting metrics"
LABEL org.opencontainers.image.licenses=MIT

# baseimage/ubuntu 기본 USER 가 비루트일 수 있어 apt/dpkg/gpg 위해 root 로 전환
# (런타임 권한 강등은 entrypoint.sh 의 setpriv 가 telegraf 유저로 수행)
USER root

# 원본 런타임 의존 패키지 + 다운로드/검증 도구(ca-certificates, wget, gnupg).
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        iputils-ping \
        snmp \
        procps \
        lm-sensors \
        libcap2-bin && \
    rm -rf /var/lib/apt/lists/*

# influxdata 패키지 서명키 import.
# 원본은 hkp://keyserver.ubuntu.com (11371) recv-keys 를 쓰지만 빌드 네트워크에서 hkp 포트가
# 막혀 'keyserver receive failed' 로 실패한다. → HTTPS(443) keyserver 웹 조회로 키를 받아 import
# (apt 가 HTTPS 로 동작했으므로 443 은 열려 있음). hkps 폴백 추가. disable-ipv6 유지.
RUN set -ex && \
    mkdir -p ~/.gnupg && chmod 700 ~/.gnupg && \
    echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        ( wget --no-verbose -O- "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x${key}" | gpg --batch --import ) || \
        gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" ; \
    done

ENV TELEGRAF_VERSION=1.25.0
# 아키텍처 감지 후 서명 .deb 다운로드 → GPG 검증 → dpkg 설치 (원본 동일)
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf_${TELEGRAF_VERSION}-1_${ARCH}.deb.asc && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf_${TELEGRAF_VERSION}-1_${ARCH}.deb && \
    gpg --batch --verify telegraf_${TELEGRAF_VERSION}-1_${ARCH}.deb.asc telegraf_${TELEGRAF_VERSION}-1_${ARCH}.deb && \
    dpkg -i telegraf_${TELEGRAF_VERSION}-1_${ARCH}.deb && \
    rm -f telegraf_${TELEGRAF_VERSION}-1_${ARCH}.deb*

EXPOSE 8125/udp 8092/udp 8094

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]
