# 원본: registry.k8s.io/csi-secrets-store/driver:v1.6.0
# 원본 base: registry.k8s.io/build-image/debian-base:bookworm-v1.0.6
#   (USER 없음 = root 실행, WORKDIR /, ENTRYPOINT=/secrets-store-csi — docker inspect 실측)
# 계열 매핑: debian-base → baseimage/alpine:3.23 (정적 CGO_ENABLED=0 바이너리라 libc 무관)
#   - 원본은 런타임에 apt upgrade + `ca-certificates mount` 설치
#     → alpine 에서 apk upgrade + ca-certificates + util-linux(mount/umount) 로 대응
# 소스 방식: 공식 릴리스 바이너리 미배포 → 멀티스테이지 소스 빌드 (v1.3.3 래핑과 동일 패턴)
#   - 빌더: golang:1.25 (v1.6.0 go.mod 는 go 1.25.9 요구 — 1.25 최신 패치로 충족)
#   - main 패키지: ./cmd/secrets-store-csi-driver (Makefile build: -o _output/secrets-store-csi)
#   - 빌드 플래그: CGO_ENABLED=0 GOOS=linux -a, ldflags '-X .../version.BuildVersion=<tag>'
ARG GIT_TAG=v1.6.0

FROM docker.io/library/golang:1.25 AS builder
WORKDIR /src
ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-sigs/secrets-store-csi-driver.git .
# CVE 보정 — Trivy HIGH 15건 (gobinary, 전부 fixed 존재) 을 모듈 상향으로 제거:
#   x/crypto 0.53.0 (CVE-2026-39828~39835, 42508, 46595, 46597 — fixed 0.52.0,
#                    x/net 0.56.0 이 0.53.0 요구), x/net 0.56.0 (CVE-2026-25681,
#                    27136, 33814, 39821 — x/text 0.39.0 이 0.56.0 요구),
#   x/text 0.39.0 (CVE-2026-56852), grpc 1.82.1 (GHSA-hrxh-6v49-42gf)
#   ※ x/* 정합 세트는 thanos v0.41.0 래핑에서 실측 검증된 조합
RUN go get \
        golang.org/x/crypto@v0.53.0 \
        golang.org/x/net@v0.56.0 \
        golang.org/x/text@v0.39.0 \
        google.golang.org/grpc@v1.82.1 && \
    go mod tidy
RUN go mod download
# 원본 Makefile LDFLAGS: -X .../pkg/version.BuildVersion=<IMAGE_VERSION>
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags "-X sigs.k8s.io/secrets-store-csi-driver/pkg/version.BuildVersion=${GIT_TAG}" \
    -o /out/secrets-store-csi ./cmd/secrets-store-csi-driver

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본은 debian-base 기반 root 실행 → baseimage 기본 non-root 를 root 로 복귀
USER root
# 원본 런타임 의존성: ca-certificates + mount/umount (debian: clean-install ca-certificates mount)
# + 원본의 `apt upgrade -y` 에 대응해 apk upgrade — base 선탑재 구버전(bind/c-ares/curl) CVE 보정.
# 기본 apk 미러는 사내망 밖 빌드에서 타임아웃 → 공식 CDN 을 repositories-file 로 지정
RUN set -eux; \
    printf '%s\n' \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" \
        > /tmp/apk.repositories; \
    apk upgrade --no-cache --repositories-file /tmp/apk.repositories; \
    apk add --no-cache --repositories-file /tmp/apk.repositories \
        ca-certificates util-linux; \
    rm -f /tmp/apk.repositories
LABEL org.opencontainers.image.source=https://github.com/kubernetes-sigs/secrets-store-csi-driver
LABEL org.opencontainers.image.description="Secrets Store CSI Driver (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=builder /out/secrets-store-csi /secrets-store-csi
# 원본 런타임 계약 복원: root + WORKDIR / (baseimage 기본 WORKDIR /root → / 로 명시)
WORKDIR /
ENTRYPOINT ["/secrets-store-csi"]
