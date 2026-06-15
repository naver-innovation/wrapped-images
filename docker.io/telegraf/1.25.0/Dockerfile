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
# 주의: telegraf_1.25.0-1_*.deb.asc 의 실제 서명키는 influxdata-archive_compat.key
#   (fpr 9D539D90D3328DC7D6C8D3B9D8FF8E1F7DF8B07E) 이다.
#   원본 Dockerfile 이 받던 05CE15085FC09D18E99EFB22684A14CF2582E0C5 구키는
#   (a) ubuntu keyserver 에서 폐기(revoked)되어 공개키를 못 받고,
#   (b) 현재 .asc 의 서명자도 아니다(InfluxData 가 compat 키로 재서명).
# → InfluxData 가 HTTPS(443)로 직접 배포하는 compat 키를 받아 import 하고 fingerprint 를 핀(검증).
RUN set -ex && \
    mkdir -p ~/.gnupg && chmod 700 ~/.gnupg && \
    wget --no-verbose -O /tmp/influxdata-archive_compat.key https://repos.influxdata.com/influxdata-archive_compat.key && \
    gpg --batch --import /tmp/influxdata-archive_compat.key && \
    gpg --batch --list-keys 9D539D90D3328DC7D6C8D3B9D8FF8E1F7DF8B07E && \
    rm -f /tmp/influxdata-archive_compat.key

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
