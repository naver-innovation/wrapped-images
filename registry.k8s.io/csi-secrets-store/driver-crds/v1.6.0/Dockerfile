# 원본: registry.k8s.io/csi-secrets-store/driver-crds:v1.6.0
# 원본 base: gcr.io/distroless/static (Config.User=0 / WorkingDir=/ → root 실행)
#   - 원본 docker/crd.Dockerfile: CRD YAML(`COPY * /crds/`) + kubectl 바이너리만 담은 tiny 이미지, ENTRYPOINT=/kubectl
# 계열 매핑: distroless/static → baseimage/alpine:3.23 (정적 산출물 COPY only, 런타임 패키지 설치 없음)
# 소스/산출물 방식: 원본은 빌드 컨텍스트(_output/crds/)에 차트 CRD 를 미리 복사해 COPY → 본 repo CI 는 upstream 소스 미포함
#   - CRD YAML 확보: git clone --depth 1 --branch v1.6.0 후 charts/secrets-store-csi-driver/crds/ 복사
#     (원본 Makefile build-crds: CI 미설정 시 charts/…/crds → _output/crds. v1.6.0 기준 manifest_staging 과 파일 구성 동일)
#   - kubectl 확보: 원본과 동일하게 dl.k8s.io 에서 다운로드. 원본은 `curl -LO` 만 하지만 여기서는 sha256 검증 추가
# CVE 보정: 원본 kubectl v1.34.3 은 Go stdlib 1.24.11 유래로 CRITICAL 1 / HIGH 19 를 그대로 싣는다.
#   → 같은 마이너의 최신 패치 v1.34.10 으로 상향 (2026-08-07 기준 dl.k8s.io/release/stable-1.34.txt)
ARG GIT_TAG=v1.6.0
ARG KUBE_VERSION=v1.34.10

# CRD YAML 산출물 확보 (원본 build-crds: charts/.../crds → _output/crds)
FROM docker.io/library/alpine:3.23 AS crds
ARG GIT_TAG
RUN apk add --no-cache git
WORKDIR /src
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/kubernetes-sigs/secrets-store-csi-driver.git . && \
    mkdir -p /crds && \
    cp -R charts/secrets-store-csi-driver/crds/. /crds/

# kubectl 바이너리 확보 (원본 builder 스테이지와 동일: alpine + curl 다운로드)
FROM docker.io/library/alpine:3.23 AS builder
ARG KUBE_VERSION
ARG TARGETARCH
RUN apk add --no-cache curl && \
    curl -fsSLO https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kubectl && \
    curl -fsSLO https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256 && \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - && \
    chmod +x kubectl && \
    rm -f kubectl.sha256

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
# 원본 distroless/static 은 root(uid 0) + WorkingDir=/ 로 실행된다. baseimage/alpine 기본은
# 비루트(USER=waslteam, uid 500) + WorkingDir=/root 라, 차트가 `kubectl apply -f crds/` 를 호출하면
# CWD=/root(0700 root) 를 비루트가 traverse 못 해 `stat crds/: permission denied` 로 죽는다.
# → 원본 런타임 컨텍스트(root, /)를 복원한다.
WORKDIR /
USER root
# baseimage/alpine:3.23 이 싣고 있는 OS 패키지의 잔존 CVE 보정
# (bind-libs/bind-tools, c-ares, curl/libcurl — alpine 3.23 저장소에 픽스 존재)
RUN apk upgrade --no-cache
# 원본 distroless/static 이 갖는 ENV (baseimage/alpine 도 ca-certificates-bundle 로 같은 경로를 제공)
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
LABEL org.opencontainers.image.source=https://github.com/kubernetes-sigs/secrets-store-csi-driver
LABEL org.opencontainers.image.description="Secrets Store CSI Driver CRDs installer (wrapped on approved OCIR alpine baseimage)"
LABEL org.opencontainers.image.licenses=Apache-2.0
# 원본: COPY * /crds/  (빌드 컨텍스트=_output/crds 의 CRD YAML 들)
COPY --from=crds /crds/ /crds/
COPY --from=builder /kubectl /kubectl
ENTRYPOINT ["/kubectl"]
