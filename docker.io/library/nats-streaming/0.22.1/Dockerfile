# =============================================================================
# 원본 이미지      : docker.io/nats-streaming:0.22.1  (docker.io/library/nats-streaming)
# 원본 base 이미지 : scratch (upstream 은 정적 바이너리 단독 이미지)
# 계열 매핑        : scratch/정적 바이너리 -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : 소스 빌드 (github.com/nats-io/nats-streaming-server, 태그 v0.22.1)
#
# 릴리스 zip 을 받아 설치하던 방식에서 소스 빌드로 바꿨다.
#   공식 v0.22.1 릴리스 바이너리는 Go 1.16.6 으로 컴파일돼 있어 Trivy 가 stdlib CRITICAL 5건과
#   HIGH 약 60건을 잡는다. nats-streaming-server 는 EOL 이고 최종 릴리스 v0.25.6 도 옛 Go 로
#   빌드된 건 마찬가지라 태그를 올려도 이 문제는 남는다. 소스를 최신 Go 로 다시 빌드하면
#   stdlib CVE 가 전부 없어지고 버전 계약(0.22.1)도 그대로 지킬 수 있다.
#   로컬 검증: golang:1.26-alpine 에서 v0.22.1 빌드 성공, `nats-streaming-server version 0.22.1` 확인.
#   버전 자체를 올리려면 v0.25.6 을 별도 디렉터리로 래핑하면 된다 (여기서는 태그를 바꾸지 않는다).
#
# upstream published 이미지 설정 — docker buildx imagetools inspect 로 확인해 맞춘다:
#   USER=(빈값 = root)   WORKDIR=(빈값 = /)   ENTRYPOINT=["/nats-streaming-server"]
#   CMD=["-m","8222"]    EXPOSE 4222 8222
#   baseimage/alpine 은 기본 USER 가 비루트이고 기본 WORKDIR 가 /root(0700) 이라
#   런타임 stage 에 USER root 와 WORKDIR / 를 명시해야 원본과 동작이 같아진다.
#
# 남는 CVE: bind-libs / bind-tools / c-ares / curl / libcurl HIGH 는 baseimage/alpine:3.23 이
#   자체적으로 담고 있는 패키지다. 이 Dockerfile 이 설치한 게 아니고 모든 wrap 이 똑같이 상속하므로
#   WASL 팀의 base 이미지 갱신으로 풀어야 한다.
# =============================================================================
ARG GOLANG_VERSION=1.26
ARG VERSION=0.22.1

FROM docker.io/library/golang:${GOLANG_VERSION}-alpine AS builder

RUN apk add --no-cache git

ARG VERSION
WORKDIR /src
RUN git clone --depth 1 --branch "v${VERSION}" https://github.com/nats-io/nats-streaming-server.git .
RUN CGO_ENABLED=0 go build -ldflags '-s -w' -o /out/nats-streaming-server .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/nats-io/nats-streaming-server"
LABEL org.opencontainers.image.description="NATS Streaming Server (STAN) 0.22.1, built from source and wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 가 비루트 -> 원본(root)에 맞춘다
USER root
# baseimage 기본 WORKDIR 은 /root(0700) -> 원본과 같이 / 로 되돌린다
WORKDIR /

RUN apk add --no-cache ca-certificates

COPY --from=builder /out/nats-streaming-server /usr/local/bin/nats-streaming-server
# upstream 의 ENTRYPOINT 경로가 /nats-streaming-server 다. 링크로 그 경로를 만들어 둔다.
RUN ln -sf /usr/local/bin/nats-streaming-server /nats-streaming-server

# upstream 공식 이미지는 root 로 동작하는 정적 단일 바이너리 이미지 (별도 USER 라인 없음).
# 동일하게 root 유지하여 동작을 보존한다.
EXPOSE 4222 8222

ENTRYPOINT ["/nats-streaming-server"]
CMD ["-m", "8222"]
