# ============================================================
# aws-mountpoint-s3-csi-driver v2.7.0 — BaseImage(navix) 래핑
# ------------------------------------------------------------
# 원본: github.com/awslabs/mountpoint-s3-csi-driver v2.7.0 Dockerfile
# 정책: 출하(runtime) stage 의 FROM 만 승인 base 로 교체 (baseimage-oci)
#   - mp_builder / builder stage 는 빌드 전용(throwaway) — 원본 base 유지
#   - 원본 runtime(eks-distro-minimal-base-csi)이 제공하던 libfuse·mount utils 는
#     dnf 로 보충. mount-s3 는 rpath $ORIGIN 으로 자체 libfuse.so.2 동반.
#   - 원본 runtime 은 distroless(USER 미지정=root, WORKDIR=/) → 명시 복원
#
# 빌드 (컨텍스트 = upstream 소스 v2.7.0 클론):
#   git clone --branch v2.7.0 --depth 1 https://github.com/awslabs/mountpoint-s3-csi-driver
#   docker build -t <tag> -f mountpoint-s3/wrap/Dockerfile ./mountpoint-s3-csi-driver
# ============================================================

ARG MOUNTPOINT_VERSION=1.22.3

# Download the mountpoint tarball and produce an installable directory
FROM --platform=$TARGETPLATFORM public.ecr.aws/amazonlinux/amazonlinux:2023 as mp_builder
ARG MOUNTPOINT_VERSION
ARG TARGETARCH
ARG TARGETPLATFORM
RUN dnf install -y gzip wget tar fuse-libs binutils patchelf && \
    # gnupg2-minimal doesn't include gpg-agent needed for signature verification.
    dnf swap -y gnupg2-minimal gnupg2-full

RUN MP_ARCH=`echo ${TARGETARCH} | sed s/amd64/x86_64/` && \
    wget -q "https://s3.amazonaws.com/mountpoint-s3-release/${MOUNTPOINT_VERSION}/$MP_ARCH/mount-s3-${MOUNTPOINT_VERSION}-$MP_ARCH.tar.gz" && \
    wget -q "https://s3.amazonaws.com/mountpoint-s3-release/${MOUNTPOINT_VERSION}/$MP_ARCH/mount-s3-${MOUNTPOINT_VERSION}-$MP_ARCH.tar.gz.asc" && \
    wget -q https://s3.amazonaws.com/mountpoint-s3-release/public_keys/KEYS

# Import the key and validate it has the fingerprints we expect
RUN gpg --import KEYS && \
    (gpg --fingerprint mountpoint-s3@amazon.com | grep "8AEF E705 EBE3 29C0 948C  75A6 6F1C 3B3A EF4B 030B") && \
    (gpg --fingerprint mountpoint-s3@amazon.com | grep "673F E406 1506 BB46 9A0E  F857 BE39 7A52 B086 DA5A") # older key

# Verify the downloaded tarball, extract it, and fixup the binary
RUN MP_ARCH=`echo ${TARGETARCH} | sed s/amd64/x86_64/` && \
    gpg --verify mount-s3-${MOUNTPOINT_VERSION}-$MP_ARCH.tar.gz.asc && \
    mkdir -p /mountpoint-s3 && \
    tar -xvzf mount-s3-${MOUNTPOINT_VERSION}-$MP_ARCH.tar.gz -C /mountpoint-s3 && \
    # set rpath for dynamic library loading
    patchelf --set-rpath '$ORIGIN' /mountpoint-s3/bin/mount-s3

# Build driver. Use BUILDPLATFORM not TARGETPLATFORM for cross compilation
FROM --platform=$BUILDPLATFORM public.ecr.aws/eks-distro-build-tooling/golang:1.26.4-al23 as builder
ARG TARGETARCH

WORKDIR /go/src/github.com/awslabs/mountpoint-s3-csi-driver
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg/mod \
    TARGETARCH=${TARGETARCH} make generate_licenses bin

# 정책 래핑: 출하 stage — 승인 base(navix, AL2023 과 같은 RHEL 계열)로 교체.
# mount-s3(AL2023 glibc 2.34 빌드)는 navix 신형 glibc 에서 하위호환 동작.
FROM --platform=$TARGETPLATFORM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos AS linux-amazon
# baseimage 기본 USER 는 비루트 → 패키지 설치 및 런타임(privileged CSI) 모두 root 필요
USER root
# 원본 minimal-base-csi 가 포함하던 libfuse + mount/umount 보충 (이미 있으면 no-op)
RUN dnf install -y fuse-libs util-linux && dnf clean all

ARG MOUNTPOINT_VERSION
ENV MOUNTPOINT_VERSION=${MOUNTPOINT_VERSION}
ENV MOUNTPOINT_BIN_DIR=/mountpoint-s3/bin

# Copy Mountpoint binary
COPY --from=mp_builder /mountpoint-s3 /mountpoint-s3
COPY --from=mp_builder /lib64/libfuse.so.2 /mountpoint-s3/bin/

# Copy licenses of CSI Driver's dependencies
COPY --from=builder /go/src/github.com/awslabs/mountpoint-s3-csi-driver/LICENSES /LICENSES

# Copy CSI Driver binaries
COPY --from=builder /go/src/github.com/awslabs/mountpoint-s3-csi-driver/bin/aws-s3-csi-driver /bin/aws-s3-csi-driver
COPY --from=builder /go/src/github.com/awslabs/mountpoint-s3-csi-driver/bin/aws-s3-csi-controller /bin/aws-s3-csi-controller
COPY --from=builder /go/src/github.com/awslabs/mountpoint-s3-csi-driver/bin/aws-s3-csi-mounter /bin/aws-s3-csi-mounter
COPY --from=builder /go/src/github.com/awslabs/mountpoint-s3-csi-driver/bin/aws-s3-csi-daemonset-mounter /bin/aws-s3-csi-daemonset-mounter

# 원본 runtime = distroless (USER 미지정=root, WORKDIR=/) — 명시 복원
USER root
WORKDIR /
ENTRYPOINT ["/bin/aws-s3-csi-driver"]
