# 원본          : docker.io/lusotycoon/apache-exporter:v1.0.8 (Lusitaniae/apache_exporter)
# 원본 base      : quay.io/prometheus/busybox-linux-amd64 (USER nobody) — 원본은 promu 가 사전빌드한
#                  "정적" Go 바이너리(.build/${OS}-${ARCH}/apache_exporter)를 COPY 한다.
# 계열 매핑      : 정적 Go(CGO 비활성) 단일 바이너리 → baseimage/alpine 런타임
#   - 원본 .build/ 사전산출물에 의존하지 않고, 원본과 동일하게 소스에서 CGO_ENABLED=0 정적 빌드한다.
#     정적이라 loader 불필요 → musl 인 baseimage/alpine 에서 그대로 실행된다.
#     (repo 내 kube-state-metrics·kyverno wrap 들과 동일한 정적-빌드 패턴)
#   - CI 는 arch 별 네이티브 러너(arc-amd64/arc-arm64)라 GOARCH 미지정 = 러너 네이티브로 빌드된다.
# 소스          : git clone v1.0.8 후 go build (main 패키지는 repo 루트, module github.com/Lusitaniae/apache_exporter)
ARG GIT_TAG=v1.0.8

FROM docker.io/library/golang:1.26 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/Lusitaniae/apache_exporter.git .
RUN go mod download
# 원본 .promu.yml 과 동일: tags netgo, CGO off, prometheus/common version 스탬프
RUN CGO_ENABLED=0 GOOS=linux go build -tags netgo \
      -ldflags="-s -w \
                -X github.com/prometheus/common/version.Version=1.0.8 \
                -X github.com/prometheus/common/version.Revision=v1.0.8 \
                -X github.com/prometheus/common/version.Branch=HEAD" \
      -o /out/apache_exporter .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/Lusitaniae/apache_exporter
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.version=v1.0.8
COPY --from=builder /out/apache_exporter /bin/apache_exporter

EXPOSE      9117
# 원본과 동일한 런타임 USER (alpine nobody=65534)
USER        nobody
ENTRYPOINT  [ "/bin/apache_exporter" ]
