# 원본: registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.16.0
# 원본 base: gcr.io/distroless/static:latest (User=0 / WorkingDir=/ , ENTRYPOINT=/csi-node-driver-registrar — docker inspect 확인)
# 계열 매핑: distroless/static → baseimage/alpine:3.23 (정적 CGO_ENABLED=0 바이너리)
# 소스 방식: 공식 릴리스 바이너리 미배포 → 멀티스테이지 소스 빌드
#   - 빌더: golang:1.25 (go.mod go 1.25.0), git clone --branch v2.16.0
#   - main 패키지: ./cmd/csi-node-driver-registrar (release-tools/build.make CMDS_DIR=cmd, CMDS=csi-node-driver-registrar)
#   - 빌드 플래그: CGO_ENABLED=0 GOOS=linux, ldflags '-X main.version=<tag> -extldflags "-static"'
ARG GIT_TAG=v2.16.0

FROM docker.io/library/golang:1.25 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-csi/node-driver-registrar.git .
# CVE 보정 — v2.16.0 go.mod 의존성의 Trivy CRITICAL 1 / HIGH 7 을 모듈 상향으로 해결 (앱 버전 유지):
#   grpc 1.82.1     (CVE-2026-33186 CRITICAL fixed 1.79.3, GHSA-hrxh-6v49-42gf fixed 1.82.1)
#   x/net 0.56.0    (CVE-2026-25681, 27136, 33814, 39821 — fixed 0.55.0, x/text 0.39.0 이 0.56.0 요구)
#   x/text 0.39.0   (CVE-2026-56852)
#   otel 1.43.0     (CVE-2026-29181 — fixed 1.41.0, grpc 1.82.1 과의 모듈 그래프 정합)
RUN go get \
        google.golang.org/grpc@v1.82.1 \
        golang.org/x/net@v0.56.0 \
        golang.org/x/text@v0.39.0 \
        go.opentelemetry.io/otel@v1.43.0 && \
    go mod tidy && \
    go mod vendor
# 업스트림은 vendor/ 를 커밋한다 — 모듈 상향 후 vendor 를 다시 만들지 않으면
# "marked as explicit in vendor/modules.txt, but not explicitly required in go.mod" 로 빌드가 깨진다
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags "-X main.version=${GIT_TAG} -extldflags \"-static\"" \
    -o /out/csi-node-driver-registrar ./cmd/csi-node-driver-registrar

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본은 distroless/static 기반 root 실행(User=0, WorkingDir=/) → baseimage 기본 non-root·WORKDIR=/root 를 원본과 일치시킨다
USER root
WORKDIR /
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates
LABEL org.opencontainers.image.source=https://github.com/kubernetes-csi/node-driver-registrar
LABEL org.opencontainers.image.description="CSI node-driver-registrar (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/csi-node-driver-registrar /csi-node-driver-registrar
ENTRYPOINT ["/csi-node-driver-registrar"]
