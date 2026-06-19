# 원본: quay.io/argoproj/kubectl-argo-rollouts:v1.9.0
#   https://github.com/argoproj/argo-rollouts (tag v1.9.0, target stage: kubectl-argo-rollouts)
#   cmd/kubectl-argo-rollouts 플러그인 바이너리. argo-rollouts 릴리스가 정적 바이너리
#   (kubectl-argo-rollouts-linux-<arch>) + 체크섬을 배포하므로 DOWNLOAD 방식 사용.
# 원본 base:
#   runtime  : gcr.io/distroless/static-debian12  (정적 바이너리 base)
# 계열 매핑:
#   runtime  : distroless/static (CGO_ENABLED=0 정적 Go 바이너리 base) → baseimage/alpine 로 통일.
# 방식: 공식 릴리스 정적 바이너리를 HTTPS 다운로드 후 sha256 검증 (GOLD B).

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/argoproj/argo-rollouts
LABEL org.opencontainers.image.description="kubectl-argo-rollouts - Argo Rollouts kubectl plugin"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/alpine 은 기본 USER 가 비루트 → 다운로드/설치 위해 root 로 전환
USER root
RUN apk add --no-cache ca-certificates wget

ARG VERSION=v1.9.0
ARG TARGETARCH
# 릴리스 자산별 sha256 (argo-rollouts-checksums.txt, v1.9.0)
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) SHA256="d1c98f59f6d3716b7a35aa540506764700a358448dd6a10e92381b7aa294d00b" ;; \
      arm64) SHA256="90907a84406b3843fb9deecd12a7312f61a9269e6d5729a30ca72a26bf67f2ab" ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    wget -q -O /tmp/kubectl-argo-rollouts \
      "https://github.com/argoproj/argo-rollouts/releases/download/${VERSION}/kubectl-argo-rollouts-linux-${TARGETARCH}"; \
    echo "${SHA256}  /tmp/kubectl-argo-rollouts" | sha256sum -c -; \
    install -m 0755 /tmp/kubectl-argo-rollouts /bin/kubectl-argo-rollouts; \
    rm -f /tmp/kubectl-argo-rollouts

# 원본 런타임 stage 의 비루트 UID(999) 유지 (runAsNonRoot).
USER 999
WORKDIR /home/argo-rollouts

ENTRYPOINT [ "/bin/kubectl-argo-rollouts" ]
CMD [ "dashboard" ]
