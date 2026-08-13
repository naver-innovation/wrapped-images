# =============================================================================
# 원본 이미지      : docker.io/natsio/prometheus-nats-exporter:0.16.0
# 원본 base 이미지 : scratch (정적 바이너리 단독 이미지)
# 계열 매핑        : scratch/정적 바이너리 -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : 소스 빌드 (github.com/nats-io/prometheus-nats-exporter, 태그 v0.16.0)
#
# 릴리스 바이너리나 원본 이미지를 그대로 넣지 않고 소스에서 빌드하는 이유
#   원본 이미지의 바이너리는 옛 Go 로 컴파일돼 있어 Trivy 가 stdlib CVE 를 무더기로 잡는다.
#   0.8.0 원본 기준 CRITICAL 6 + HIGH 78 (stdlib 58, x/crypto 14, nats-server 11, client_golang 1)
#   이었고, 원본 바이너리를 COPY 한 래핑본도 같은 84건이 그대로 따라왔다.
#   최신 Go 로 다시 빌드하면 stdlib CVE 가 전부 없어진다.
#   로컬 Trivy 실측 (CRITICAL/HIGH):
#     원본 0.8.0 이미지            84건 (C6/H78)
#     원본 바이너리 COPY 래핑본    84건 (C6/H78)
#     소스빌드 v0.8.0               1건 (C0/H1  — client_golang v1.9.0 잔존)
#     소스빌드 v0.16.0              0건
#
# 취약 의존성 상향 (빌드 전에 go get 으로 올린다)
#   github.com/nats-io/nats-server/v2  v2.10.20 -> v2.12.6   (CVE-2025-30215 CRITICAL 외 HIGH 다수)
#   golang.org/x/crypto               v0.27.0  -> v0.52.0   (HIGH 다수)
#   go.mod 이 예전 형식이라 go get 뒤 go mod tidy 가 필요하다 (없으면 go.sum 항목 누락으로 빌드 실패).
#
# 0.8.0 이 아니라 0.16.0 을 쓰는 이유, 그리고 0.17.0 이상을 못 쓰는 이유
#   argo-events 는 STAN statefulset 의 metrics 사이드카에 이 args 를 넘긴다:
#     -connz -routez -subz -varz -channelz -serverz http://localhost:8222
#   v0.17.0 부터 NATS Streaming 지원이 빠지면서 -channelz / -serverz 플래그가 삭제됐다.
#   최신(v0.20.1)으로 올리면 알 수 없는 플래그로 컨테이너가 즉시 죽는다.
#   두 플래그가 살아 있는 마지막 버전이 v0.16.0 이다.
#
# 0.8.0 -> 0.16.0 하위호환 (같은 STAN 서버에 두 exporter 를 붙여 /metrics 를 대조함)
#   메트릭 111개 -> 123개. 없어진 것은 go_memstats_gc_cpu_fraction, go_memstats_lookups_total
#   둘뿐이고 이건 prometheus client 라이브러리가 뺀 Go 런타임 내부 지표다.
#   gnatsd_* 는 전부 상위집합이고(connz 5->10, routez 3, subsz 12, varz 43->47),
#   STAN 전용 지표(channelz 1, serverz 계열 16)는 양쪽이 동일하다. 대시보드/알람은 그대로 동작한다.
#
# upstream published 이미지 설정 — docker buildx imagetools inspect 로 확인해 맞춘다:
#   USER=(빈값 = root)   WORKDIR=/   ENTRYPOINT=["/prometheus-nats-exporter"]
#   CMD=["--help"]       EXPOSE 7777/tcp
#
# 실행 계정 — 원본과 일부러 다르게 간다
#   원본은 root 로 돌지만 이 래핑본은 baseimage 기본 계정 waslteam(uid 500)으로 돌린다.
#   설치 단계(apk del, COPY, ln)만 root 로 하고 마지막에 USER waslteam 으로 내린다.
#   exporter 는 7777(비특권 포트)만 열고 파일을 쓰지 않아 비루트로 문제없이 뜬다.
#   baseimage 기본 WORKDIR 가 /root(0700) 이라 비루트가 못 들어간다. 원본과 같이 / 로 되돌린다.
#
# 배포 시 같이 바꿀 것
#   argo-events 는 컨트롤러 ConfigMap(argo-events-controller-config)에서 사이드카 이미지를 읽는다.
#   eventBus.nats.versions[].metricsExporterImage 를 이 래핑본 태그로 바꿔야 반영된다.
#
# 남는 CVE: baseimage/alpine:3.23 이 자체적으로 담고 있는 패키지분은 이 Dockerfile 이 설치한 게
#   아니고 모든 wrap 이 똑같이 상속한다. 근본 해결은 WASL 팀의 base 이미지 갱신이다.
# =============================================================================
ARG GOLANG_VERSION=1.26
ARG VERSION=0.16.0

FROM docker.io/library/golang:${GOLANG_VERSION}-alpine AS builder

RUN apk add --no-cache git

ARG VERSION
WORKDIR /src
RUN git clone --depth 1 --branch "v${VERSION}" https://github.com/nats-io/prometheus-nats-exporter.git .

# 취약 의존성 상향 (위 주석 참조)
RUN set -eux; \
    go get \
      github.com/nats-io/nats-server/v2@v2.12.6 \
      golang.org/x/crypto@v0.52.0; \
    go mod tidy

# main.version 은 소스 기본값이 "0.0.0" 이라 ldflags 로 실제 버전을 박는다 (--version 출력용)
RUN CGO_ENABLED=0 go build -ldflags "-s -w -X main.version=${VERSION}" \
      -o /out/prometheus-nats-exporter .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/nats-io/prometheus-nats-exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for NATS server metrics 0.16.0, built from source with patched dependencies, wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="0.16.0"

# 설치 단계(apk del, COPY, ln)만 root 로 수행한다. 실행 계정은 파일 끝에서 waslteam 으로 내린다.
USER root
# baseimage 기본 WORKDIR 은 /root(0700) 이라 비루트가 못 들어간다 -> 원본과 같이 / 로 되돌린다
WORKDIR /

# ca-certificates 를 apk 로 설치하지 않는다. baseimage/alpine 에 CA 번들이 이미 박혀 있고
# (패키지로는 미설치지만 /etc/ssl/certs/ca-certificates.crt 가 존재한다),
# base 의 apk 리포지터리가 사내 미러(nexus.naver-innovation.net)라 그 망 밖에서는 빌드가 막힌다.
# 대신 번들이 실제로 있는지 확인한다 — base 가 바뀌어 사라지면 조용히 넘어가지 않고 여기서 실패한다.
# exporter 는 NATS monitoring 엔드포인트를 HTTPS 로 긁을 때 이 번들을 쓴다.
# 이 이미지는 정적 Go 바이너리 하나만 돌린다. base 가 담고 있는 bind-tools(dig/nslookup)와
# curl 계열은 쓰지 않는데 Trivy HIGH 상당수가 그 패키지들이다. 지우면 그만큼 줄고 이미지도 작아진다.
# --no-network 라 base 의 사내 미러에 닿지 않아도 동작한다. nats-streaming wrap 과 같은 조치다.
RUN apk del --no-network bind-tools curl \
    && test -s /etc/ssl/certs/ca-certificates.crt

COPY --from=builder /out/prometheus-nats-exporter /usr/local/bin/prometheus-nats-exporter
# upstream 의 ENTRYPOINT 경로가 /prometheus-nats-exporter 다. 링크로 그 경로를 만들어 둔다.
RUN ln -sf /usr/local/bin/prometheus-nats-exporter /prometheus-nats-exporter

EXPOSE 7777

# 실행 계정은 baseimage 기본 비루트 계정 (uid 500). 7777 은 비특권 포트라 그대로 바인딩된다.
USER waslteam

# 인자 없이 뜨면 원본처럼 --help 를 찍고 끝난다
# (argo-events 는 args 로 -connz -routez -subz -varz -channelz -serverz 를 넘겨 CMD 를 덮어쓴다).
ENTRYPOINT ["/prometheus-nats-exporter"]
CMD ["--help"]
