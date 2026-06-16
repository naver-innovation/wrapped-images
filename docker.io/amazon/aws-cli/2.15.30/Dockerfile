# syntax=docker/dockerfile:1
# 원본: docker.io/amazon/aws-cli:2.15.30
#   https://github.com/aws/aws-cli (tag 2.15.30, docker/Dockerfile)
# 원본 base:
#   public.ecr.aws/amazonlinux/amazonlinux:2  (Amazon Linux 2 = centos/rhel/fedora 계열)
# 계열 매핑: Amazon Linux 2 → baseimage/navix
# 보정 사항:
#   - 원본은 빌드 컨텍스트에 사전 생성된 awscli-exe zip 을 COPY 한다.
#     본 repo CI 는 Dockerfile 디렉터리만 빌드하므로 공식 versioned zip URL 에서 다운로드한다.
#   - AWS 공식 설치 문서의 PGP key 로 zip signature 를 검증한 뒤 설치한다.
#   - 원본과 동일하게 /usr/local/aws-cli 와 /usr/local/bin/aws 를 final stage 로 복사한다.
ARG AWS_CLI_VERSION=2.15.30

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos AS installer

USER root

ARG TARGETARCH
ARG AWS_CLI_VERSION

RUN set -eux; \
    if command -v dnf >/dev/null 2>&1; then PKG=dnf; \
    elif command -v microdnf >/dev/null 2>&1; then PKG=microdnf; \
    else echo "no dnf/microdnf package manager found" >&2; exit 1; fi; \
    install_pkg() { \
      if [ "$PKG" = dnf ]; then $PKG --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y "$@"; \
      else $PKG install -y "$@"; fi; \
    }; \
    $PKG update -y; \
    install_pkg unzip; \
    command -v curl >/dev/null 2>&1 || install_pkg curl-minimal || install_pkg curl; \
    command -v gpg >/dev/null 2>&1 || install_pkg gnupg2-minimal || install_pkg gnupg2; \
    $PKG clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN <<'EOF'
set -eux
case "${TARGETARCH:-amd64}" in
  amd64) AWS_ARCH=x86_64 ;;
  arm64) AWS_ARCH=aarch64 ;;
  *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;;
esac

EXE_FILENAME="awscli-exe-linux-${AWS_ARCH}-${AWS_CLI_VERSION}.zip"
curl -fsSLo "/tmp/${EXE_FILENAME}" "https://awscli.amazonaws.com/${EXE_FILENAME}"
curl -fsSLo "/tmp/${EXE_FILENAME}.sig" "https://awscli.amazonaws.com/${EXE_FILENAME}.sig"

cat >/tmp/aws-cli-public-key.asc <<'KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
aGveYQUJDMpiLAAKCRCmMQrMRnJHXKBYD/9Ab0qQdGiO5hObchG8xh8Rpb4Mjyf6
0JrVo6m8GNjNj6BHkSc8fuTQJ/FaEhaQxj3pjZ3GXPrXjIIVChmICLlFuRXYzrXc
Pw0lniybypsZEVai5kO0tCNBCCFuMN9RsmmRG8mf7lC4FSTbUDmxG/QlYK+0IV/l
uJkzxWa+rySkdpm0JdqumjegNRgObdXHAQDWlubWQHWyZyIQ2B4U7AxqSpcdJp6I
S4Zds4wVLd1WE5pquYQ8vS2cNlDm4QNg8wTj58e3lKN47hXHMIb6CHxRnb947oJa
pg189LLPR5koh+EorNkA1wu5mAJtJvy5YMsppy2y/kIjp3lyY6AmPT1posgGk70Z
CmToEZ5rbd7ARExtlh76A0cabMDFlEHDIK8RNUOSRr7L64+KxOUegKBfQHb9dADY
qqiKqpCbKgvtWlds909Ms74JBgr2KwZCSY1HaOxnIr4CY43QRqAq5YHOay/mU+6w
hhmdF18vpyK0vfkvvGresWtSXbag7Hkt3XjaEw76BzxQH21EBDqU8WJVjHgU6ru+
DJTs+SxgJbaT3hb/vyjlw0lK+hFfhWKRwgOXH8vqducF95NRSUxtS4fpqxWVaw3Q
V2OWSjbne99A5EPEySzryFTKbMGwaTlAwMCwYevt4YT6eb7NmFhTx0Fis4TalUs+
j+c7Kg92pDx2uQ==
=OBAt
-----END PGP PUBLIC KEY BLOCK-----
KEY

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
gpg --batch --no-autostart --import /tmp/aws-cli-public-key.asc
gpg --batch --no-autostart --with-colons --fingerprint A6310ACC4672475C \
  | grep -q '^fpr:::::::::FB5DB77FD5C118B80511ADA8A6310ACC4672475C:'
gpg --batch --no-autostart --verify "/tmp/${EXE_FILENAME}.sig" "/tmp/${EXE_FILENAME}"
gpgconf --kill all || true
rm -rf "$GNUPGHOME" /tmp/aws-cli-public-key.asc "/tmp/${EXE_FILENAME}.sig"

unzip -q "/tmp/${EXE_FILENAME}" -d /tmp
/tmp/aws/install --bin-dir /aws-cli-bin/
rm -rf /tmp/aws "/tmp/${EXE_FILENAME}"
EOF

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

LABEL org.opencontainers.image.source="https://github.com/aws/aws-cli"
LABEL org.opencontainers.image.description="AWS CLI v2"
LABEL org.opencontainers.image.licenses="Apache-2.0"

USER root

RUN set -eux; \
    if command -v dnf >/dev/null 2>&1; then PKG=dnf; \
    elif command -v microdnf >/dev/null 2>&1; then PKG=microdnf; \
    else echo "no dnf/microdnf package manager found" >&2; exit 1; fi; \
    install_pkg() { \
      if [ "$PKG" = dnf ]; then $PKG --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y "$@"; \
      else $PKG install -y "$@"; fi; \
    }; \
    $PKG update -y; \
    install_pkg groff less; \
    $PKG clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

COPY --from=installer /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=installer /aws-cli-bin/ /usr/local/bin/

WORKDIR /aws
ENTRYPOINT ["/usr/local/bin/aws"]
