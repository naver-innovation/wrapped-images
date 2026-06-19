# 원본: registry.k8s.io/csi-secrets-store/driver-crds:v1.3.3
# 원본 base: gcr.io/distroless/static (USER 없음 / non-root, static distroless)
#   - 원본 docker/crd.Dockerfile: CRD YAML(`COPY * /crds/`) + kubectl 바이너리만 담은 tiny 이미지, ENTRYPOINT=/kubectl
# 계열 매핑: distroless/static → baseimage/alpine:3.23 (정적 산출물 COPY only, 패키지 설치 없음)
# 소스/산출물 방식: 원본은 빌드 컨텍스트(_output/crds/)에 차트 CRD 를 미리 복사해 COPY → 본 repo CI 는 upstream 소스 미포함
#   - CRD YAML 확보: git clone --depth 1 --branch v1.3.3 후 charts/secrets-store-csi-driver/crds/ 복사
#   - kubectl 확보: 원본과 동일하게 dl.k8s.io 에서 KUBE_VERSION=v1.26.0 다운로드 (HTTPS, sha256 검증)
ARG GIT_TAG=v1.3.3
ARG KUBE_VERSION=v1.26.0

# CRD YAML 산출물 확보 (원본 build-crds: charts/.../crds → _output/crds)
FROM docker.io/library/alpine:3.18 AS crds
ARG GIT_TAG
RUN apk add --no-cache git
WORKDIR /src
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-sigs/secrets-store-csi-driver.git . && \
    mkdir -p /crds && \
    cp -R charts/secrets-store-csi-driver/crds/. /crds/

# kubectl 바이너리 확보 (원본 builder 스테이지와 동일: alpine + curl 다운로드)
FROM docker.io/library/alpine:3.18 AS builder
ARG KUBE_VERSION
ARG TARGETARCH
RUN apk add --no-cache curl && \
    curl -fsSLO https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kubectl && \
    curl -fsSLO https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256 && \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - && \
    chmod +x kubectl

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본은 distroless/static (non-root) → 별도 패키지/파일 작업 없이 산출물만 COPY (USER 변경 불필요)
LABEL org.opencontainers.image.source=https://github.com/kubernetes-sigs/secrets-store-csi-driver
LABEL org.opencontainers.image.description="Secrets Store CSI Driver CRDs installer (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
# 원본: COPY * /crds/  (빌드 컨텍스트=_output/crds 의 CRD YAML 들)
COPY --from=crds /crds/ /crds/
COPY --from=builder /kubectl /kubectl
ENTRYPOINT ["/kubectl"]
