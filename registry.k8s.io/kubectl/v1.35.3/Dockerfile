# 원본: registry.k8s.io/kubectl:v1.35.3  (issue #132)
#   argo-cd redis-secret-init hook 에서 사용. OCIR 에는 v1.36.2 만 있어 v1.35.3 신규 래핑.
#   기준 패턴: registry.k8s.io/kubectl/v1.36.2/Dockerfile (버전만 상이).
# 원본 base: 없음 (공식 k8s 릴리스 바이너리 직접 다운로드)
# 계열 매핑: 단일 정적 바이너리 → 허용 base 아무거나 가능 → baseimage/alpine (최소 크기)
# 버전 핀: v1.35.3. 다운로드는 HTTPS only + sha256 검증(생략 금지).
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
LABEL org.opencontainers.image.source=https://github.com/kubernetes/kubernetes
LABEL org.opencontainers.image.description="kubectl - Kubernetes command-line tool (v1.35.3)"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/alpine 은 기본 USER 가 비루트 → apk/설치 위해 root 로 전환 (런타임은 마지막에 1001 로 복귀)
USER root

# TLS 검증용 ca-certificates + 다운로드 도구.
RUN apk add --no-cache ca-certificates wget

# buildx 가 주입하는 타깃 아키텍처 (amd64 / arm64 모두 공식 바이너리 존재).
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.35.3

# 공식 k8s 릴리스에서 바이너리 + sha256 다운로드(HTTPS only) → sha256 검증 후 설치.
RUN wget -q "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -O kubectl && \
    wget -q "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" -O kubectl.sha256 && \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    rm -f kubectl kubectl.sha256

# 런타임용 비루트 유저 (idempotent — 이미 존재해도 실패하지 않음).
RUN adduser -S -u 1001 kubectl 2>/dev/null || true
USER 1001

ENTRYPOINT ["kubectl"]
