# 원본: quay.io/argoproj/argocd:v3.2.3  (Argo CD)
#   https://github.com/argoproj/argo-cd (tag v3.2.3, repo 루트 Dockerfile)
# 원본 base:
#   builder      : golang:1.25.0           (helm/kustomize CLI 다운로드, glibc/debian 계열)
#   argocd-ui    : node:23.0.0             (yarn install → yarn build, UI 산출물)
#   argocd-build : golang:1.25.0           (make argocd-all, UI 임베드한 단일 argocd 바이너리)
#   runtime      : ubuntu:25.04            (argocd-base — git/gpg/helm/kustomize 를 런타임 exec, glibc/distroless 아님)
# 계열 판별 + base:
#   전 stage glibc 계열. 런타임이 distroless 가 아니라 ubuntu 위에서 git/gpg/helm/kustomize 를 실제로 exec.
#   - 빌드 전용(throwaway) stage(builder/argocd-ui/argocd-build): upstream pinned golang/node 유지.
#       (출하 레이어가 아니라 정책 대상 아님 — argoexec/grafana 래핑과 동일 판단. digest 핀은
#        git-clone-by-tag 방식상 유지 불가 → 태그 핀만 유지.)
#   - runtime(argocd-base): ubuntu → baseimage/ubuntu 로 교체.
#       허용 base 가 24.04 까지라 upstream 25.04 → 24.04 로 다운그레이드(아래 리스크 참고).
# 소스는 벤더링 대신 각 빌더에서 v3.2.3 태그를 1회 git clone 후 빌드(이 repo 는 CI 빌드 컨텍스트에
#   argo-cd 소스를 포함하지 않으므로 upstream Dockerfile 의 `COPY . .`/`COPY hack/...` 를 clone 으로 대체).
ARG GIT_TAG=v3.2.3

####################################################################################################
# builder — helm + kustomize CLI 다운로드 (원본 builder stage)
#   원본은 repo 의 hack/install.sh + hack/installers 로 helm/kustomize 핀 버전 설치.
#   여기서는 태그를 clone 해 동일 스크립트로 설치한다.
####################################################################################################
FROM docker.io/library/golang:1.25.0 AS builder

WORKDIR /tmp

# 원본 builder 패키지 (buster-backports 라인은 불필요 — 24.x golang base 는 bookworm 기반).
RUN apt-get update && apt-get install --no-install-recommends -y \
    openssh-server \
    nginx \
    unzip \
    fcgiwrap \
    git \
    git-lfs \
    make \
    wget \
    gcc \
    sudo \
    zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-cd.git /go/src/github.com/argoproj/argo-cd

WORKDIR /go/src/github.com/argoproj/argo-cd
# 원본과 동일: hack/install.sh 로 helm 과 kustomize 를 핀 버전으로 설치.
RUN ./hack/install.sh helm && \
    INSTALL_PATH=/usr/local/bin ./hack/install.sh kustomize

####################################################################################################
# argocd-ui — yarn install → yarn build (원본 argocd-ui stage)
#   make argocd-all 가 ui/dist/app 임베드를 요구하므로 이 stage 는 필수.
####################################################################################################
FROM docker.io/library/node:23.0.0 AS argocd-ui

ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-cd.git /go/src/github.com/argoproj/argo-cd

WORKDIR /src
# 원본: COPY ui/package.json ui/yarn.lock → yarn install → 전체 ui/ 복사 → yarn build.
RUN cp /go/src/github.com/argoproj/argo-cd/ui/package.json \
       /go/src/github.com/argoproj/argo-cd/ui/yarn.lock ./
RUN yarn install --network-timeout 200000
RUN cp -r /go/src/github.com/argoproj/argo-cd/ui/. ./

ARG ARGO_VERSION=latest
ENV ARGO_VERSION=$ARGO_VERSION
ARG TARGETARCH
RUN HOST_ARCH=$TARGETARCH NODE_ENV='production' NODE_ONLINE_ENV='online' NODE_OPTIONS=--max_old_space_size=8192 yarn build

####################################################################################################
# argocd-build — make argocd-all (원본 argocd-build stage)
#   UI 산출물(/src/dist/app)을 ui/dist/app 에 넣은 뒤 go:embed 로 묶인 단일 argocd 바이너리 빌드.
####################################################################################################
FROM docker.io/library/golang:1.25.0 AS argocd-build

ARG GIT_TAG
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/argoproj/argo-cd.git /go/src/github.com/argoproj/argo-cd
WORKDIR /go/src/github.com/argoproj/argo-cd

COPY --from=builder /usr/local/bin/helm /usr/local/bin/helm
COPY --from=builder /usr/local/bin/kustomize /usr/local/bin/kustomize
# 원본: COPY --from=argocd-ui /src/dist/app → ui/dist/app (go:embed 대상).
COPY --from=argocd-ui /src/dist/app /go/src/github.com/argoproj/argo-cd/ui/dist/app

ARG TARGETOS \
    TARGETARCH
# 원본 build args (지정 없으면 Makefile 기본값 사용).
ARG GIT_TAG \
    BUILD_DATE \
    GIT_TREE_STATE \
    GIT_COMMIT
RUN GIT_COMMIT=$GIT_COMMIT \
    GIT_TREE_STATE=$GIT_TREE_STATE \
    GIT_TAG=$GIT_TAG \
    BUILD_DATE=$BUILD_DATE \
    GOOS=$TARGETOS \
    GOARCH=$TARGETARCH \
    make argocd-all

####################################################################################################
# runtime (원본 argocd-base + final image 통합) → baseimage/ubuntu:24.04
####################################################################################################
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/argoproj/argo-cd"
LABEL org.opencontainers.image.description="Argo CD v3.2.3 wrapped onto baseimage/ubuntu:24.04"
LABEL org.opencontainers.image.licenses=Apache-2.0

# baseimage/ubuntu 는 기본 USER 가 비루트 → apt/디렉터리 생성 위해 root 로 전환 (런타임은 마지막에 999 로 복귀).
USER root

ENV ARGOCD_USER_ID=999 \
    DEBIAN_FRONTEND=noninteractive

# uid/gid 999 충돌 대비: ubuntu:24.04 는 uid/gid 1000(ubuntu) 만 선점, 999 는 보통 비어있음.
# 그래도 충돌 시 점유 계정을 제거한 뒤 고정 id 로 재생성하고, 생성 성공을 검증한다.
RUN if getent group "$ARGOCD_USER_ID" >/dev/null && [ "$(getent group "$ARGOCD_USER_ID" | cut -d: -f1)" != "argocd" ]; then \
        groupdel "$(getent group "$ARGOCD_USER_ID" | cut -d: -f1)"; \
    fi && \
    if getent passwd "$ARGOCD_USER_ID" >/dev/null && [ "$(getent passwd "$ARGOCD_USER_ID" | cut -d: -f1)" != "argocd" ]; then \
        userdel "$(getent passwd "$ARGOCD_USER_ID" | cut -d: -f1)"; \
    fi && \
    (getent group argocd >/dev/null || groupadd -g "$ARGOCD_USER_ID" argocd) && \
    (getent passwd argocd >/dev/null || useradd -r -u "$ARGOCD_USER_ID" -g argocd argocd) && \
    getent passwd argocd >/dev/null && getent group argocd >/dev/null && \
    mkdir -p /home/argocd && \
    chown argocd:0 /home/argocd && \
    chmod g=u /home/argocd

# 원본 런타임 패키지. 24.04 는 별도 backports 없이 git/git-lfs/tini/gnupg/tzdata/connect-proxy 제공.
# 주의: 최소 패키지 `gpg` 가 아니라 메타패키지 `gnupg` 를 설치한다. `gpg` 만 깔면 gpg-agent·dirmngr 가
#       빠져서, repo-server 의 gpg 키 생성(`gpg --gen-key` → gpg-agent)이
#       `error running '/usr/bin/gpg-agent': probably not installed / No agent running` 으로 실패해
#       repo-server 가 크래시한다. 원본 argocd 이미지도 gnupg(gpg-agent 포함)를 쓴다.
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
    git git-lfs tini gnupg tzdata connect-proxy && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 원본 hack 래퍼 + entrypoint (clone 한 소스에서 가져옴 — 원본은 repo 컨텍스트에서 COPY).
COPY --from=builder /go/src/github.com/argoproj/argo-cd/hack/gpg-wrapper.sh \
    /go/src/github.com/argoproj/argo-cd/hack/git-verify-wrapper.sh \
    /go/src/github.com/argoproj/argo-cd/entrypoint.sh \
    /usr/local/bin/
RUN chmod +x /usr/local/bin/gpg-wrapper.sh \
    /usr/local/bin/git-verify-wrapper.sh \
    /usr/local/bin/entrypoint.sh

COPY --from=builder /usr/local/bin/helm /usr/local/bin/helm
COPY --from=builder /usr/local/bin/kustomize /usr/local/bin/kustomize

# 하위 호환용 uid_entrypoint.sh (멱등: -f).
RUN ln -sf /usr/local/bin/entrypoint.sh /usr/local/bin/uid_entrypoint.sh

# configmap 마운트 지원 (멱등: mkdir -p / ln -sf).
# baseimage/ubuntu 는 openssh 미설치라 /etc/ssh 가 없다 → 심볼릭 링크 전에 디렉터리 생성(로컬 빌드로 확인).
WORKDIR /app/config/ssh
RUN mkdir -p /etc/ssh && \
    touch ssh_known_hosts && \
    ln -sf /app/config/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts

WORKDIR /app/config
RUN mkdir -p tls && \
    mkdir -p gpg/source && \
    mkdir -p gpg/keys && \
    chown argocd gpg/keys && \
    chmod 0700 gpg/keys

ENV USER=argocd

####################################################################################################
# 최종 — argocd 바이너리 + 9개 컴포넌트 심볼릭링크 (원본 final image)
#   make argocd-all 은 dist/argocd 단일 바이너리만 만든다. 9개 컴포넌트(argocd-server 등)는
#   원본 final stage 에서 직접 ln -s 로 생성하므로 동일하게 재현한다(멱등 위해 -sf).
####################################################################################################
ENTRYPOINT ["/usr/bin/tini", "--"]
COPY --from=argocd-build /go/src/github.com/argoproj/argo-cd/dist/argocd* /usr/local/bin/

RUN ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-server && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-repo-server && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-cmp-server && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-application-controller && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-dex && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-notifications && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-applicationset-controller && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-k8s-auth && \
    ln -sf /usr/local/bin/argocd /usr/local/bin/argocd-commit-server

USER 999
WORKDIR /home/argocd
