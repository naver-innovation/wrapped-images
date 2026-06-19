# 원본 이미지·태그 : quay.io/prometheus/alertmanager:v0.31.1
# 원본 base        : quay.io/prometheus/busybox-linux-<arch>:latest (Prometheus busybox 변형)
# 계열 매핑 근거   : 원본은 busybox(musl) 단일 정적 바이너리 런타임 → musl 계열인 alpine 으로 매핑
# 소스 확보 방식   : upstream 이 amd64/arm64 정적 release 바이너리 + sha256 을 GitHub Releases 로 공식 배포 → 다운로드 후 sha256 검증 (빌드 불필요)
#                   tarball 에 alertmanager, amtool, alertmanager.yml 포함. upstream Dockerfile 레이아웃 그대로 재현.
#                   참고: upstream v0.31.1 Dockerfile 은 EXPOSE 9093 만 선언 (cluster 9094 는 미선언) → 원본 충실 재현.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source="https://github.com/prometheus/alertmanager"
LABEL org.opencontainers.image.description="The Alertmanager handles alerts sent by client applications such as the Prometheus server"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 는 non-root → 설치/다운로드/디렉터리 생성 위해 root 로 전환
USER root
RUN apk add --no-cache ca-certificates wget

ARG TARGETARCH
ARG ALERTMANAGER_VERSION=0.31.1
# upstream release 페이지의 per-arch sha256 (linux amd64/arm64)
ARG SHA256_amd64=35191cbd9d4f8162458b78dd7e93990cccd246044d9a6f788adb1c66ac3ea07b
ARG SHA256_arm64=266dda88b64318c27847ef9af4ff450fc178c827550a8039420c5ca8657a4a8b
RUN set -eux; \
    eval "SHA256=\${SHA256_${TARGETARCH}}"; \
    DIR="alertmanager-${ALERTMANAGER_VERSION}.linux-${TARGETARCH}"; \
    TARBALL="${DIR}.tar.gz"; \
    wget -q "https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/${TARBALL}" -O "${TARBALL}"; \
    echo "${SHA256}  ${TARBALL}" | sha256sum -c -; \
    tar -xzf "${TARBALL}"; \
    install -m 0755 "${DIR}/alertmanager" /bin/alertmanager; \
    install -m 0755 "${DIR}/amtool"       /bin/amtool; \
    mkdir -p /etc/alertmanager; \
    cp "${DIR}/alertmanager.yml" /etc/alertmanager/alertmanager.yml; \
    rm -rf "${TARBALL}" "${DIR}"

# 원본 런타임 재현: 데이터 디렉터리 + nobody 소유권
RUN mkdir -p /alertmanager && chown -R nobody:nobody /etc/alertmanager /alertmanager

USER nobody
EXPOSE 9093
VOLUME [ "/alertmanager" ]
WORKDIR /alertmanager
ENTRYPOINT [ "/bin/alertmanager" ]
CMD [ "--config.file=/etc/alertmanager/alertmanager.yml", \
      "--storage.path=/alertmanager" ]
