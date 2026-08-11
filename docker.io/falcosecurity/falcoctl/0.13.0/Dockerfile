# 원본 이미지·태그: docker.io/falcosecurity/falcoctl:0.13.0
#   https://github.com/falcosecurity/falcoctl (tag v0.13.0, build/Dockerfile)
# 원본 base:
#   builder  cgr.dev/chainguard/go
#   runtime  cgr.dev/chainguard/static:latest (apko, 정적 바이너리 전용)
# 계열 매핑: distroless 성격의 chainguard/static → baseimage/alpine
#   (원본이 CGO_ENABLED=0 정적 빌드라 musl/glibc 무관 — 소스 빌드 유지)
# 원본 런타임 계약(buildx imagetools inspect 실측):
#   USER 65532, WORKDIR / , ENTRYPOINT ["/usr/bin/falcoctl"], CMD 없음,
#   ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
# 보정 사항:
#   - 원본 빌드 stage 는 cgr.dev/chainguard/go(태그 미핀, Chainguard 무료 티어 latest 전용)를
#     쓴다. 재현 가능한 핀을 위해 golang:1.25-alpine 로 교체(go.mod 는 go 1.25.7 요구).
#     빌드 전용 stage 라 출하되지 않으므로 정책 대상 아님.
#   - 원본은 로컬 빌드 컨텍스트(COPY . ./)를 쓰지만 본 repo CI 는 Dockerfile 디렉터리만
#     빌드하므로 태그 핀 git clone 으로 대체한다.
#   - 원본이 CI 에서 --build-arg 로 주입하던 RELEASE/COMMIT/BUILD_DATE 는 값이 없으면
#     `test -n` 체크에서 빌드가 중단된다 → v0.13.0 실제 값을 기본값으로 박는다.
#   - baseimage/alpine 기본 USER 는 waslteam(uid 500) 이라 설치 단계 앞에 USER root,
#     런타임 stage 끝에서 원본과 동일한 uid 65532 로 복원한다.

ARG GIT_TAG=v0.13.0

# -----------------------------------------------------------------------------
# 빌드 전용 stage (출하 안 됨)
FROM docker.io/library/golang:1.25-alpine AS builder
WORKDIR /tmp/builder

ARG GIT_TAG
ARG RELEASE=0.13.0
ARG COMMIT=92e3d53f85092f607f31902761a46a57e30ad878
ARG BUILD_DATE=2026-05-04T13:58:45Z
ARG PROJECT=github.com/falcosecurity/falcoctl

RUN test -n "$RELEASE" || ( echo "The RELEASE argument is unset. Aborting" && false )
RUN test -n "$COMMIT" || ( echo "The COMMIT argument is unset. Aborting" && false )
RUN test -n "$BUILD_DATE" || ( echo "The BUILD_DATE argument is unset. Aborting" && false )

RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/falcosecurity/falcoctl.git .

RUN go mod download

# CVE 보정 — v0.13.0 go.mod 의존성의 Trivy HIGH 21건 중 18건을 모듈 상향으로 해결
# (앱 버전 유지, thanos v0.41.0 wrap 과 동일 전략):
#   x/crypto 0.53.0        (CVE-2026-39828~39835, 42508, 46595, 46597 — fixed 0.52.0,
#                           x/net 0.56.0 이 0.53.0 요구해 상향)
#   x/net 0.56.0           (CVE-2026-25681, 27136, 39821 — fixed 0.55.0)
#   x/text 0.39.0          (CVE-2026-56852)
#   grpc 1.82.1            (GHSA-hrxh-6v49-42gf)
#   oras-go/v2 2.6.2       (CVE-2026-50151, CVE-2026-50163)
#   sigstore/fulcio 1.8.6  (fulcio HIGH 1건)
#   sigstore/rekor 1.5.2   (rekor HIGH 1건)
# ⚠️ 잔존 HIGH 3건 — github.com/docker/docker (CVE-2026-34040, 41567, 42306):
#   CVE-2026-34040 의 fixed 29.3.1 은 모듈 경로가 github.com/moby/moby 로 이동해
#   github.com/docker/docker 에는 v28.5.2+incompatible 이 최상위 버전이다
#   (proxy.golang.org 목록에 v29.x 없음). 나머지 2건은 fixed 미출시.
#   상세는 같은 디렉터리의 CVE-NOTES.md 참고.
RUN go get \
        golang.org/x/crypto@v0.53.0 \
        golang.org/x/net@v0.56.0 \
        golang.org/x/text@v0.39.0 \
        google.golang.org/grpc@v1.82.1 \
        oras.land/oras-go/v2@v2.6.2 \
        github.com/sigstore/fulcio@v1.8.6 \
        github.com/sigstore/rekor@v1.5.2 && \
    go mod tidy

RUN CGO_ENABLED=0 \
    GOOS=$(go env GOOS) \
    GOARCH=$(go env GOARCH) \
    go build -ldflags \
    "-s \
    -w \
    -X '${PROJECT}/cmd/version.semVersion=${RELEASE}' \
    -X '${PROJECT}/cmd/version.gitCommit=${COMMIT}' \
    -X '${PROJECT}/cmd/version.buildDate=${BUILD_DATE}'" \
    ./

# -----------------------------------------------------------------------------
# 런타임 stage(출하): cgr.dev/chainguard/static → baseimage/alpine 교체
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

LABEL org.opencontainers.image.source="https://github.com/falcosecurity/falcoctl"
LABEL org.opencontainers.image.description="Wrapped docker.io/falcosecurity/falcoctl:0.13.0 (falcoctl on approved alpine base)"
LABEL org.opencontainers.image.licenses="Apache-2.0"

USER root

# 원본 chainguard/static 이 제공하던 것: ca-certificates + nonroot(65532) 계정.
# 계정 생성은 idempotent 하게 처리하되 생성 실패를 삼키지 않도록 마지막에 uid 를 검증한다.
RUN set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache ca-certificates; \
    update-ca-certificates; \
    getent group nonroot >/dev/null || addgroup -g 65532 nonroot; \
    getent passwd nonroot >/dev/null || adduser -D -u 65532 -G nonroot -h /home/nonroot nonroot; \
    mkdir -p /home/nonroot; \
    chown 65532:65532 /home/nonroot; \
    test "$(id -u nonroot)" = "65532"

COPY --from=builder /tmp/builder/falcoctl /usr/bin/falcoctl

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

USER 65532
WORKDIR /
ENTRYPOINT [ "/usr/bin/falcoctl" ]
