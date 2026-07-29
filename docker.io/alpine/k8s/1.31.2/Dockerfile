# 원본: docker.io/alpine/k8s:1.31.2
#   https://github.com/alpine-docker/k8s (master CI 빌드 — git 태그 없음.
#   레시피는 원본 이미지 config history 에서 복원, ARG 값은 빌드 당시 주입값 그대로)
# 원본 base:
#   alpine:edge (2024-10-27 CI 빌드 시점 스냅샷)
# 계열 매핑: alpine → baseimage/alpine
# 보정 사항:
#   - baseimage/alpine 은 기본 USER 가 비루트 → 설치 위해 USER root 전환.
#     원본 런타임은 USER 미지정(=root), WORKDIR /apps, CMD /bin/sh → 마지막에 그대로 복원.
#   - baseimage/alpine 의 apk repository 는 사내망 전용 → dl-cdn v3.23 repositories 파일을 명시 사용.
#   - alpine 3.23 에서 yq 패키지가 yq-go 로 개명 (동일하게 /usr/bin/yq 제공) → apk add jq yq-go.
#   - 원본이 releases/latest 로 받던 eksctl·aws-iam-authenticator 를 원본 빌드일(2024-10-27) 기준
#     latest 버전으로 핀: eksctl 0.194.0, aws-iam-authenticator 0.6.27.
#     (GitHub API latest 조회는 CI 에서 rate-limit 으로 깨질 수 있고 재현성도 없음.
#      eksctl 은 weaveworks/eksctl 아카이브 → 정식 저장소 eksctl-io/eksctl 로 URL 교체.)
#   - krew 의 PATH 등록은 ~/.bashrc 대신 /root/.bashrc 로 명시 (base 의 HOME 가정 제거).
#   - helm plugin install 도 버전 미지정 시 최신 태그를 받아 helm 3.16.2 와 호환이 깨짐
#     (최신 helm-diff 의 plugin.yaml 은 platformHooks 필드 사용 → "unknown field" 로 설치 실패).
#     원본 빌드일 기준 latest 로 핀: helm-diff 3.9.11, helm-unittest 0.6.3, helm-push 0.10.4.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

ARG ARCH
ARG HELM_VERSION=3.16.2
ARG KUBECTL_VERSION=1.31.2
ARG KUSTOMIZE_VERSION=v5.5.0
ARG KUBESEAL_VERSION=0.27.1
ARG KREW_VERSION=0.4.4
ARG VALS_VERSION=0.37.7
ARG KUBECONFORM_VERSION=0.6.7
ARG EKSCTL_VERSION=0.194.0
ARG AUTHENTICATOR_VERSION=0.6.27
ARG HELM_DIFF_VERSION=3.9.11
ARG HELM_UNITTEST_VERSION=0.6.3
ARG HELM_PUSH_VERSION=0.10.4

USER root

RUN printf '%s\n' \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/main" \
        "https://dl-cdn.alpinelinux.org/alpine/v3.23/community" \
        > /tmp/apk.repositories

RUN case `uname -m` in \
    x86_64) ARCH=amd64; ;; \
    armv7l) ARCH=arm; ;; \
    aarch64) ARCH=arm64; ;; \
    ppc64le) ARCH=ppc64le; ;; \
    s390x) ARCH=s390x; ;; \
    *) echo "un-supported arch, exit ..."; exit 1; ;; \
    esac && \
    echo "export ARCH=$ARCH" > /envfile && \
    cat /envfile

# helm
RUN . /envfile && echo $ARCH && \
    apk add --update --no-cache --repositories-file /tmp/apk.repositories \
        curl ca-certificates bash git && \
    curl -sL https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz | tar -xvz && \
    mv linux-${ARCH}/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-${ARCH}

# helm plugins
RUN helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION} && rm -rf /tmp/helm-*
RUN helm plugin install https://github.com/helm-unittest/helm-unittest --version ${HELM_UNITTEST_VERSION} && rm -rf /tmp/helm-*
RUN helm plugin install https://github.com/chartmuseum/helm-push --version ${HELM_PUSH_VERSION} && \
    rm -rf /tmp/helm-* \
    /root/.local/share/helm/plugins/helm-push/testdata \
    /root/.cache/helm/plugins/https-github.com-chartmuseum-helm-push/testdata

# kubectl
RUN . /envfile && echo $ARCH && \
    curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

# kustomize
RUN . /envfile && echo $ARCH && \
    curl -sLO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz && \
    tar xvzf kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz && \
    mv kustomize /usr/bin/kustomize && \
    chmod +x /usr/bin/kustomize && \
    rm kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz

# eksctl
RUN . /envfile && echo $ARCH && \
    curl -sL "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_$(uname -s)_${ARCH}.tar.gz" | tar xz -C /tmp && \
    mv /tmp/eksctl /usr/bin && \
    chmod +x /usr/bin/eksctl

# awscli
RUN apk add --update --no-cache --repositories-file /tmp/apk.repositories py3-pip && \
    pip3 install --break-system-packages --upgrade pip setuptools && \
    pip3 install --break-system-packages awscli && \
    pip3 cache purge

RUN apk add --update --no-cache --repositories-file /tmp/apk.repositories jq yq-go

# aws-iam-authenticator
RUN . /envfile && echo $ARCH && \
    curl -fL https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${AUTHENTICATOR_VERSION}/aws-iam-authenticator_${AUTHENTICATOR_VERSION}_linux_${ARCH} -o /usr/bin/aws-iam-authenticator && \
    chmod +x /usr/bin/aws-iam-authenticator

# envsubst
RUN apk add --update --no-cache --repositories-file /tmp/apk.repositories gettext

# kubeseal
RUN . /envfile && echo $ARCH && \
    curl -L https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-${ARCH}.tar.gz -o - | tar xz -C /usr/bin/ && \
    chmod +x /usr/bin/kubeseal

# vals
RUN . /envfile && echo $ARCH && \
    curl -L https://github.com/helmfile/vals/releases/download/v${VALS_VERSION}/vals_${VALS_VERSION}_linux_${ARCH}.tar.gz -o - | tar xz -C /usr/bin/ && \
    chmod +x /usr/bin/vals

# krew
RUN . /envfile && echo $ARCH && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v${KREW_VERSION}/krew-linux_${ARCH}.tar.gz" && \
    tar zxvf krew-linux_${ARCH}.tar.gz && \
    ./krew-linux_${ARCH} install krew && \
    echo 'export PATH=/root/.krew/bin:$PATH' >> /root/.bashrc && \
    rm krew-linux_${ARCH}.tar.gz

# kubeconform
RUN . /envfile && echo $ARCH && \
    curl -L https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${ARCH}.tar.gz -o - | tar xz -C /usr/bin/ && \
    chmod +x /usr/bin/kubeconform

RUN rm -f /tmp/apk.repositories

# 원본 런타임 복원 (원본 User 미지정 = root)
USER root
WORKDIR /apps
CMD ["/bin/sh"]
