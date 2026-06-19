# 원본: quay.io/prometheus-operator/prometheus-config-reloader:v0.89.0
# 원본 base: builder=quay.io/prometheus/golang-builder:1.25-base, runtime=quay.io/prometheus/busybox-linux-<arch>:latest (busybox 계열, nobody uid 65534)
# 계열 매핑: busybox(최소 런타임) → baseimage/alpine:3.23 (승인된 최소 런타임 base)
# 소스 방식: v0.89.0 릴리스에 standalone 바이너리 없음(에셋=bundle.yaml/stripped-down-crds.yaml) → 소스 multi-stage 빌드
#            업스트림과 동일하게 ./cmd/prometheus-config-reloader/ 빌드. alpine(musl) 런타임 호환 위해 CGO_ENABLED=0 정적 빌드.
ARG GIT_TAG=v0.89.0

FROM docker.io/library/golang:1.25 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/prometheus-operator/prometheus-operator.git .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -X github.com/prometheus/common/version.Version=0.89.0" -o /out/prometheus-config-reloader ./cmd/prometheus-config-reloader/

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
RUN apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source="https://github.com/prometheus-operator/prometheus-operator"
LABEL org.opencontainers.image.url="https://prometheus-operator.dev/"
LABEL org.opencontainers.image.licenses="Apache-2.0"
COPY --from=builder /out/prometheus-config-reloader /bin/prometheus-config-reloader
# 업스트림 busybox 런타임의 nobody(uid 65534) 와 동일하게 비루트 실행
RUN adduser -S -u 65534 nobody 2>/dev/null || true
USER 65534
ENTRYPOINT ["/bin/prometheus-config-reloader"]
