# 원본 이미지: phx.ocir.io/axyd58snjxbf/cert-manager-webhook-oci:latest
#   clicktruck 이 자기네 공개 OCIR 테넌시(axyd58snjxbf, phx 리전)에 올린 외부 이미지다.
#   *.ocir.io 라고 정책 준수가 아니다 — 우리 테넌시(me-riyadh-1.ocir.io/axlo4g31gl45)가 아니면 외부 이미지다.
# 소스: https://github.com/clicktruck/cert-manager-webhook-oci
#   (gitlab.com/dn13/cert-manager-webhook-oci 의 포크. go.mod 모듈 경로는 gitlab 쪽 그대로다)
#   원본 Dockerfile: golang:1.19.4-alpine3.17 로 build_deps → build 2단, 런타임은 FROM alpine:3.17
#   라이선스: Apache-2.0 (repo LICENSE)
# 계열 매핑: alpine → baseimage/alpine:3.23 (musl 유지)
#
# 원본 published 이미지 설정 — docker inspect 로 확인해 맞춘다:
#   USER=(빈값 = root)   WORKDIR=(빈값 = /)   ENTRYPOINT=["webhook"]   CMD=(없음)   단일 arch(amd64)
#   baseimage/alpine 은 기본 USER 가 비루트이고 기본 WORKDIR 가 /root(0700) 이라
#   런타임 stage 에 USER root 와 WORKDIR / 를 명시해야 원본과 동작이 같아진다.
#
# 보정 사항
#   1) Go 버전 — 원본 Dockerfile 은 ARG GOLANG_VERSION=1.19.4 를 쓰는데 현재 go.mod 는 `go 1.24.0` 을
#      요구한다. upstream 이 의존성(cert-manager 1.12.14 등)만 올리고 Dockerfile ARG 를 안 고친 상태라
#      1.19 빌더로는 빌드가 깨진다. 빌더를 1.24 계열로 올렸다.
#   2) 소스 고정 — upstream 에 릴리스 태그가 없다. 커밋 SHA 로 핀해서 latest 가 떠다니는 걸 막는다.
#      SHA 를 fetch 로 직접 지정하므로, upstream 이 force-push 로 그 커밋을 없애면 조용히 다른 코드를
#      빌드하는 대신 빌드가 실패한다.
#   3) 빌드 컨텍스트 — 이 저장소는 Dockerfile 만 두므로 원본의 `COPY . .` 대신 빌더에서 소스를 받는다.
#   4) 원본 arch 는 amd64 단일이지만 여기서는 소스에서 빌드하므로 amd64/arm64 둘 다 나온다.
#      CGO_ENABLED=0 정적 링크라 musl/glibc 와도 무관하다 (원본과 동일한 빌드 플래그).
ARG GOLANG_VERSION=1.24
ARG GIT_REF=635df6b6c012ce98da6cdb43fbfb5af80ae30378

FROM docker.io/library/golang:${GOLANG_VERSION}-alpine AS build_deps

RUN apk add --no-cache git

WORKDIR /workspace
ENV GO111MODULE=on

ARG GIT_REF
RUN set -eux; \
    git init -q .; \
    git remote add origin https://github.com/clicktruck/cert-manager-webhook-oci.git; \
    git fetch -q --depth 1 origin "${GIT_REF}"; \
    git checkout -q FETCH_HEAD; \
    test -f go.mod

RUN go mod download

FROM build_deps AS build

RUN CGO_ENABLED=0 go build -o webhook -ldflags '-w -extldflags "-static"' .

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23

# baseimage/alpine 기본 USER 는 비루트 → 원본(root)에 맞춘다
USER root
# baseimage/alpine 기본 WORKDIR 은 /root(0700) → 원본과 같이 / 로 되돌린다
WORKDIR /

RUN apk add --no-cache ca-certificates

COPY --from=build /workspace/webhook /usr/local/bin/webhook

LABEL org.opencontainers.image.source="https://github.com/clicktruck/cert-manager-webhook-oci" \
      org.opencontainers.image.title="cert-manager-webhook-oci (wrapped onto baseimage/alpine)" \
      org.opencontainers.image.description="cert-manager ACME DNS01 webhook for Oracle Cloud Infrastructure DNS, built from source and wrapped onto baseimage/alpine." \
      org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["webhook"]
