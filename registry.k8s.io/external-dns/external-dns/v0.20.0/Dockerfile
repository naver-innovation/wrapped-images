# 원본          : registry.k8s.io/external-dns/external-dns:v0.20.0
# 원본 base      : gcr.io/distroless/static-nonroot (배포 전용, 공개 Dockerfile 없음)
# 계열 매핑      : distroless(static) → alpine (승인된 baseimage/alpine 으로 런타임 교체)
# 소스 방식      : 멀티스테이지 소스 빌드 (upstream Makefile 동일 빌드: CGO_ENABLED=0 go build -o build/external-dns .)
#
# upstream(github.com/kubernetes-sigs/external-dns v0.20.0) 는 컨테이너 이미지만
# 배포하고 리눅스 서버용 release 바이너리를 제공하지 않으므로 소스에서 직접 빌드한다.
# Makefile: BINARY=external-dns / LDFLAGS=-X .../externaldns.Version -w -s / 메인 패키지는 repo root(.)
ARG GIT_TAG=v0.20.0

FROM docker.io/library/golang:1.25 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-sigs/external-dns.git .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags "-X sigs.k8s.io/external-dns/pkg/apis/externaldns.Version=${GIT_TAG} -w -s" \
    -o /out/external-dns .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# baseimage/alpine 기본 USER 는 non-root → 설치를 위해 root 로 전환
USER root
RUN apk add --no-cache ca-certificates

LABEL org.opencontainers.image.source=https://github.com/kubernetes-sigs/external-dns
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.version=v0.20.0

COPY --from=builder /out/external-dns /bin/external-dns

# 원본 distroless static-nonroot 와 동일하게 비루트(65532) 로 실행
RUN adduser -S -u 65532 -H nonroot 2>/dev/null || true
USER 65532
ENTRYPOINT ["/bin/external-dns"]
