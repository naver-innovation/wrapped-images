# 원본: docker.io/library/alpine:latest
#   https://github.com/alpinelinux/docker-alpine (공식 alpine 베이스 이미지)
# 원본 base: alpine (musl 계열) — 이미지 자체가 alpine 루트파일시스템
# 계열 매핑: alpine → baseimage/alpine (musl 유지, 동일 계열)
# alpine:latest 는 별도 빌드 단계가 없는 순수 베이스 이미지이므로,
# 승인된 baseimage/alpine 으로 FROM 만 교체하면 동일 역할을 한다.
# baseimage/alpine:3.23 == 현재 latest 가 가리키는 alpine 3.23 계열.
# 원본 alpine 은 root 로 동작(다운스트림이 FROM 후 apk 설치)하므로 동일하게 root 기본 사용자 유지.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
LABEL org.opencontainers.image.source=https://github.com/alpinelinux/docker-alpine
LABEL org.opencontainers.image.description="Alpine Linux base image wrapped onto baseimage/alpine"
LABEL org.opencontainers.image.licenses=MIT
CMD ["/bin/sh"]
