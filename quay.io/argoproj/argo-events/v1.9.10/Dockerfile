# 원본: quay.io/argoproj/argo-events:v1.9.10
#   https://github.com/argoproj/argo-events (tag v1.9.10, target stage: argo-events)
#   cmd 단일 Go 바이너리(argo-events). 런타임에 argo-workflows v3.7.7 의 argo CLI 를 함께 임베드.
# 원본 base:
#   builder/base : alpine:3.16.2            (alpine / musl 계열)
#   runtime      : scratch                  (정적 바이너리 base, USER 미지정 = root)
# 계열 매핑:
#   builder : alpine → baseimage/alpine  (musl 유지)
#   runtime : scratch(정적 Go 바이너리 base) → baseimage/alpine 로 통일(허용 base).
#             argo-events 바이너리는 CGO_ENABLED=0 완전 정적.
# 소스는 벤더링 대신 빌더에서 v1.9.10 태그를 git clone (태그 고정).
# 임베드 argo CLI 는 원본과 동일하게 argo-workflows v3.7.7 정적 릴리스를 다운로드 후 sha256 검증.
ARG GIT_TAG=v1.9.10
ARG ARGO_VERSION=v3.7.7

# ── builder ───────────────────────────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS builder
# baseimage/alpine 은 기본 USER 가 비루트 → apk/빌드 위해 root 로 전환
USER root
RUN apk add --no-cache \
    git \
    make \
    ca-certificates \
    wget \
    curl \
    gcc \
    libc-dev \
    bash \
    tzdata \
    go

ARG GIT_TAG
WORKDIR /go/src/github.com/argoproj/argo-events
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-events.git .
RUN go mod download
# 원본 Makefile 경로와 동일: CGO_ENABLED=0 정적 빌드 (./cmd → argo-events).
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    go build -v -ldflags "-X github.com/argoproj/argo-events.gitTag=${GIT_TAG}" \
    -o /go/bin/argo-events ./cmd

# argo CLI (argo-workflows v3.7.7) 다운로드 + sha256 검증 — 원본 base stage 와 동일 출처.
ARG ARGO_VERSION
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) SHA256="4f406103b660bbff61d858a7c14c5bf43d3a98f2105ac9cccb6ac8506a296aa5" ;; \
      arm64) SHA256="7fe3d267d9daac80dd783ea2f4c6cd33632b435b273e13adbb4ffe6b1d80286d" ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    wget -q -O /tmp/argo.gz \
      "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-${TARGETARCH}.gz"; \
    echo "${SHA256}  /tmp/argo.gz" | sha256sum -c -; \
    gunzip -f /tmp/argo.gz; \
    install -m 0755 /tmp/argo /usr/local/bin/argo; \
    rm -f /tmp/argo

# ── runtime (원본 argo-events stage) ────────────────────────────────────────────
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본 scratch 런타임은 USER 미지정 = root + WorkingDir=/ 로 실행된다. baseimage/alpine 기본은
# 비루트(USER=waslteam, uid 500) + WorkingDir=/root 라, 그대로 두면 원본과 실행 유저/CWD 가 달라진다.
# → 원본 런타임 컨텍스트(root, /)를 복원한다.
WORKDIR /
USER root
LABEL org.opencontainers.image.source=https://github.com/argoproj/argo-events
LABEL org.opencontainers.image.description="argo-events - Argo Events controller/executor"
LABEL org.opencontainers.image.licenses=Apache-2.0

# 원본 scratch 런타임이 base stage 에서 복사하던 부가 자산(zoneinfo, ca-certificates, argo CLI).
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/local/bin/argo /usr/local/bin/argo
COPY --from=builder /go/bin/argo-events /bin/argo-events

ENTRYPOINT [ "/bin/argo-events" ]
