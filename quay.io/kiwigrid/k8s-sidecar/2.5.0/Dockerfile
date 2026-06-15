# 원본: quay.io/kiwigrid/k8s-sidecar:2.5.0
#   https://github.com/kiwigrid/k8s-sidecar (tag 2.5.0)
# 원본 base: FROM python:alpine3.22  (alpine / musl 계열)
# 계열 매핑: alpine → baseimage/alpine  (musl 유지 — glibc 계열로 교체 불가)
# baseimage/alpine 에는 python 런타임이 없으므로 apk 로 보정 설치한다.
# src/ 는 upstream tag 2.5.0 에서 그대로 벤더링.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23 AS base
# baseimage/alpine 은 기본 USER 가 비루트 → apk/빌드 위해 root 로 전환 (런타임은 마지막 stage 에서 65534 로 복귀)
USER root
RUN apk add --no-cache python3

FROM base AS builder
WORKDIR /app
# venv 부트스트랩(py3-pip=ensurepip) + wheel 컴파일 대비 빌드 도구
RUN apk add --no-cache py3-pip gcc python3-dev musl-dev
RUN python3 -m venv .venv && .venv/bin/pip install --no-cache-dir -U pip setuptools
COPY        src/ /app/
RUN .venv/bin/pip install --no-cache-dir -r requirements.txt && \
    rm requirements.txt && \
	find /app/.venv \( -type d -a -name test -o -name tests \) -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' \+


FROM base
LABEL org.opencontainers.image.source=https://github.com/kiwigrid/k8s-sidecar
LABEL org.opencontainers.image.description="K8s sidecar image to collect configmaps and secrets as files"
LABEL org.opencontainers.image.licenses=MIT
ENV         PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=builder /app /app
ENV PATH="/app/.venv/bin:$PATH"
# Use the nobody user's numeric UID/GID to satisfy MustRunAsNonRoot PodSecurityPolicies
# https://kubernetes.io/docs/concepts/policy/pod-security-policy/#users-and-groups
USER        65534:65534
CMD         [ "python", "-u", "/app/sidecar.py" ]
