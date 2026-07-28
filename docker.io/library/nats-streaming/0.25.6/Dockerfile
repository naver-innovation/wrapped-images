# =============================================================================
# 원본 이미지      : docker.io/nats-streaming:0.25.6  (docker.io/library/nats-streaming)
#                   nats-streaming-server 의 최종 릴리스다. NATS Streaming(STAN) 자체가 EOL 이고
#                   후속은 NATS JetStream 이다. 신규 사용처는 JetStream 을 검토할 것.
# 원본 base 이미지 : scratch (upstream 은 정적 바이너리 단독 이미지)
# 계열 매핑        : scratch/정적 바이너리 -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : 소스 빌드 (github.com/nats-io/nats-streaming-server, 태그 v0.25.6)
#
# 릴리스 zip 을 받아 넣지 않고 소스에서 빌드하는 이유
#   공식 릴리스 바이너리는 옛 Go 로 컴파일돼 있어 Trivy 가 stdlib CVE 를 무더기로 잡는다.
#   0.22.1 릴리스 바이너리 기준 CRITICAL 5건 + stdlib HIGH 약 60건이었다.
#   최신 Go 로 다시 빌드하면 stdlib CVE 가 전부 없어진다.
#
# 취약 의존성 상향 (빌드 전에 go get 으로 올린다)
#   github.com/nats-io/nats-server/v2  v2.9.24 -> v2.12.6
#     v0.25.6 이 물고 있는 v2.9.24 에 CVE-2025-30215(CRITICAL)와 HIGH 9건이 걸려 있다.
#     2.12.6 은 그중 최신 수정본(2.11.15/2.12.6 계열)까지 포함한다.
#   golang.org/x/crypto  v0.15.0 -> v0.52.0   (HIGH 12건)
#   로컬 검증: golang:1.26-alpine 에서 두 의존성을 올린 상태로 v0.25.6 빌드 성공.
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
ARG VERSION=0.25.6

FROM docker.io/library/golang:${GOLANG_VERSION}-alpine AS builder

RUN apk add --no-cache git

ARG VERSION
WORKDIR /src
RUN git clone --depth 1 --branch "v${VERSION}" https://github.com/nats-io/nats-streaming-server.git .

# 취약 의존성 상향 (위 주석 참조)
RUN set -eux; \
    go get \
      github.com/nats-io/nats-server/v2@v2.12.6 \
      golang.org/x/crypto@v0.52.0

RUN CGO_ENABLED=0 go build -ldflags '-s -w' -o /out/nats-streaming-server .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/nats-io/nats-streaming-server"
LABEL org.opencontainers.image.description="NATS Streaming Server (STAN) 0.25.6, built from source with patched dependencies, wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# baseimage 기본 USER 가 비루트 -> 원본(root)에 맞춘다
USER root
# baseimage 기본 WORKDIR 은 /root(0700) -> 원본과 같이 / 로 되돌린다
WORKDIR /

# ca-certificates 를 apk 로 설치하지 않는다. baseimage/alpine 에 CA 번들이 이미 박혀 있고
# (패키지로는 미설치지만 /etc/ssl/certs/ca-certificates.crt 가 존재한다),
# base 의 apk 리포지터리가 사내 미러(nexus.naver-innovation.net)라 그 망 밖에서는 빌드가 막힌다.
# 대신 번들이 실제로 있는지 확인한다 — base 가 바뀌어 사라지면 조용히 넘어가지 않고 여기서 실패한다.
# 이 이미지는 정적 Go 바이너리 하나만 돌린다. base 가 담고 있는 bind-tools(dig/nslookup)와
# curl 계열은 쓰지 않는데, Trivy HIGH 19건(bind-libs·bind-tools·c-ares·curl·libcurl)이
# 전부 그 패키지들이다. 지우면 19건이 0 이 되고 이미지도 작아진다 (base 63개 -> 41개).
# --no-network 라 base 의 사내 미러(nexus.naver-innovation.net)에 닿지 않아도 동작한다.
# 근본 해결은 WASL 팀의 base 갱신이고, 이건 그때까지의 조치다.
RUN apk del --no-network bind-tools curl \
    && test -s /etc/ssl/certs/ca-certificates.crt

COPY --from=builder /out/nats-streaming-server /usr/local/bin/nats-streaming-server
# upstream 의 ENTRYPOINT 경로가 /nats-streaming-server 다. 링크로 그 경로를 만들어 둔다.
RUN ln -sf /usr/local/bin/nats-streaming-server /nats-streaming-server

# upstream 공식 이미지는 root 로 동작하는 정적 단일 바이너리 이미지 (별도 USER 라인 없음).
# 동일하게 root 유지하여 동작을 보존한다.
EXPOSE 4222 8222

ENTRYPOINT ["/nats-streaming-server"]
CMD ["-m", "8222"]
