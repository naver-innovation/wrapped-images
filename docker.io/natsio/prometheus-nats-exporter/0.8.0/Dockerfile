# =============================================================================
# 원본 이미지      : docker.io/natsio/prometheus-nats-exporter:0.8.0
# 원본 base 이미지 : scratch (정적 바이너리 단독 이미지)
# 계열 매핑        : scratch/정적 바이너리 -> me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 소스 방식        : 원본 이미지를 빌드 전용(throwaway) 스테이지로 두고 바이너리만 COPY
#
# GitHub 릴리스 tar.gz 를 받아 쓰지 않는 이유 (이전 리비전이 그렇게 했다가 amd64 가 깨졌다)
#   v0.8.0 릴리스 아티팩트는 아키텍처마다 링크 방식이 다르다.
#     linux-amd64 : ELF x86-64, dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2
#     linux-arm64 : ELF aarch64, statically linked
#   alpine 은 musl 이라 /lib64/ld-linux-x86-64.so.2 가 없다. 커널이 ELF 인터프리터를 못 찾으면
#   ENOENT 를 그대로 돌려주기 때문에 바이너리가 멀쩡히 있는데도 실행 시점에
#     exec /usr/local/bin/prometheus-nats-exporter: no such file or directory
#   가 뜬다. 빌드는 성공하고 amd64 런타임만 죽으므로 CI 에서 안 걸린다. arm64 는 정적이라 통과한다.
#
#   반면 원본 이미지 안의 /prometheus-nats-exporter 는 정적 링크다
#   (amd64 확인: ELF x86-64, statically linked). 그래서 릴리스 tar.gz 대신 원본 이미지의
#   바이너리를 가져온다. glibc shim(gcompat) 을 얹는 우회는 Go 런타임에서 신뢰하기 어려워 쓰지 않는다.
#
# upstream published 이미지 설정 — docker buildx imagetools inspect 로 확인 (4개 아치 모두 동일):
#   USER=(빈값 = root)   WORKDIR=/   ENTRYPOINT=["/prometheus-nats-exporter"]
#   CMD=["--help"]       EXPOSE 7777/tcp
#   멀티아치: linux/amd64, linux/arm64, linux/arm/v6, linux/arm/v7
#
# 실행 계정 — 원본과 일부러 다르게 간다
#   원본은 root 로 돌지만 이 래핑본은 baseimage 기본 계정 waslteam(uid 500)으로 돌린다.
#   설치 단계(apk del, ln)만 root 로 하고 마지막에 USER waslteam 으로 내린다.
#   exporter 는 7777(비특권 포트)만 열고 파일을 쓰지 않아 비루트로 문제없이 뜬다
#   (검증: uid 500 으로 기동 후 /metrics 200).
#   baseimage 기본 WORKDIR 가 /root(0700) 이라 비루트가 못 들어간다. 원본과 같이 / 로 되돌린다.
#
# 남는 CVE: baseimage/alpine:3.23 이 자체적으로 담고 있는 패키지분은 이 Dockerfile 이 설치한 게
#   아니고 모든 wrap 이 똑같이 상속한다. 근본 해결은 WASL 팀의 base 이미지 갱신이다.
# =============================================================================

# --- 파일 출처 스테이지 (출하 안 됨) ---
FROM docker.io/natsio/prometheus-nats-exporter:0.8.0 AS upstream

# --- 런타임 (출하): 허용 base alpine ---
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/nats-io/prometheus-nats-exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for NATS server metrics wrapped onto baseimage/alpine:3.23"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="0.8.0"

# 설치 단계(apk del, ln)만 root 로 수행한다. 실행 계정은 파일 끝에서 waslteam 으로 내린다.
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

# 원본 이미지의 정적 바이너리를 그대로 가져온다
COPY --from=upstream /prometheus-nats-exporter /usr/local/bin/prometheus-nats-exporter
# upstream 의 ENTRYPOINT 경로가 /prometheus-nats-exporter 다. 링크로 그 경로를 만들어 둔다.
# 이전 리비전이 /usr/local/bin 경로로 출하됐으므로 두 경로 모두 유효하게 남긴다.
RUN ln -sf /usr/local/bin/prometheus-nats-exporter /prometheus-nats-exporter

EXPOSE 7777

# 실행 계정은 baseimage 기본 비루트 계정 (uid 500). 7777 은 비특권 포트라 그대로 바인딩된다.
USER waslteam

# 인자 없이 뜨면 원본처럼 --help 를 찍고 끝난다
# (운영 파드는 args 로 -connz -varz http://nats:8222 같은 값을 넘겨 CMD 를 덮어쓴다).
ENTRYPOINT ["/prometheus-nats-exporter"]
CMD ["--help"]
