# 원본: docker.io/library/busybox:1.37.0  (공식 busybox)
#   https://github.com/docker-library/busybox
# 원본 base: FROM scratch + busybox 멀티콜 정적 바이너리 (busybox 계열)
# 계열 매핑: busybox → baseimage/alpine (가장 근접한 계열 — alpine 의 userland 자체가 busybox)
# baseimage/alpine 에 busybox 가 이미 포함되어 동일 명령군(sh, ls, wget, vi 등)을 제공한다.
# 정책상 외부 정적 바이너리 직접 반입 대신 승인 base 의 busybox 를 사용한다
# (busybox 버전은 baseimage/alpine 제공 버전을 따른다).
# 원본 busybox 이미지는 root 로 동작하므로 동일하게 root 기본 사용자 유지.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
LABEL org.opencontainers.image.source=https://github.com/docker-library/busybox
LABEL org.opencontainers.image.description="busybox wrapped onto baseimage/alpine (busybox userland provided by alpine)"
LABEL org.opencontainers.image.licenses=GPL-2.0-only
CMD ["sh"]
