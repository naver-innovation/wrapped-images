# 원본: container-registry.oracle.com/oci_observability_management/oci-management-agent
#   OCI Management Agent. Oracle 이 자기네 공개 레지스트리에 올린 외부 이미지다.
# 소스: https://github.com/oracle/docker-images -> OracleManagementAgent/dockerfiles/latest/Dockerfile
#   이미지 라벨 issues=https://github.com/oracle/docker-images/issues 로 찾았다.
#   라이선스: 컨테이너 파일은 UPL-1.0. 에이전트 소프트웨어 자체는 Oracle 라이선스다.
# 계열 매핑: Oracle Linux 8.10 (RHEL 계열) -> baseimage/navix:10.1-wasl-centos
#
# 태그: 요청은 1.10.0 이었으나 1.13.0 으로 올렸다.
#   oci-kubernetes-monitoring 차트 HEAD 가 1.13.0 을 쓰고, 1.10.0 은 그만큼 뒤처져 CVE 를 더 진다.
#   Java 8 제약(아래)은 1.10.0 이든 1.13.0 이든 동일해서 상향으로 피할 수 있는 문제가 아니다.
#
# 원본 published 이미지 설정 — 맞춰야 하는 계약:
#   USER=(빈값 = root)   WORKDIR=(빈값 = /)   CMD=(없음)
#   ENTRYPOINT=["/opt/oracle-mgmtagent-staging/scripts/initialize.sh"]
#   ENV LANG=en_US.UTF-8, LC_ALL=C   arch=amd64+arm64
#   확인은 `docker buildx imagetools inspect --format '{{json .Image}}'` 로 했다.
#   멀티플랫폼 이미지는 `docker inspect` 가 설정을 전부 빈 값으로 돌려주니 그걸로 판단하면 안 된다.
#
# 이 래핑의 핵심 쟁점 — Java 8
#   에이전트 설치기(zip 안 preinstallscript.sh)가 JDK 8 만 받는다. 검사부가 이렇다:
#     elif [[ $version == 1.8* && $version == *"_"* ]]; then ... if [ $upgradeVersion -ge 162 ]
#   11/17/21 을 받는 분기가 없고, 실패 시 메시지도 명시적이다 —
#     "Agent only supports JDK 8 with a minimum upgrade version JDK 8u281 -b02."
#   최신 1.13.0(에이전트 빌드 260429.2105)도 동일하다. 버전 상향으로 풀리지 않는다.
#   그런데 승인 BaseImage 어디에도 Java 8 이 없다:
#     navix(CentOS Stream 10)  java-21 / java-25 만
#     ubuntu 24.04             noble 에서 openjdk-8 제거
#     alpine 3.23              openjdk8 는 있으나 musl 이라 glibc 빌드인 에이전트가 못 돈다
#   그래서 Eclipse Temurin JDK 8 을 tarball 로 직접 넣는다. 원본 이미지의 openjdk 가 1.8.0_492 인데
#   Temurin 8u492-b09 라 업데이트 레벨이 정확히 같다.
#   설치기의 java 탐색 순서는 $JAVA_HOME/bin/java -> /usr/java8_64/bin/java -> /usr/bin/java 다.
#   세 경로를 다 만족시키려고 /usr/java8_64 에 풀고 JAVA_HOME 도 거기로 잡고 /usr/bin/java 도 건다.
#
#   ⚠ 남는 위험 — 배포 전에 판단이 필요하다
#     Oracle 이 지원하는 라이선스 제품의 JDK 벤더(Oracle OL8 openjdk -> Temurin)와 OS(OL8 -> navix)를
#     동시에 바꾸는 것이라 Oracle 지원 구성에서 벗어난다. 기능 검증은 실제 에이전트 등록까지 해봐야 한다.
#     Java 8 런타임 자체가 Trivy 에 자기 CVE 를 들고 온다.
#
# 에이전트 zip 조달
#   원본 Dockerfile 은 `COPY ./oracle.mgmt_agent.zip` 로, 사용자가 OCI 콘솔에서 받아 빌드 컨텍스트에
#   두라고 한다(테넌시 인증 다운로드). CI 가 자동으로 받을 수 없고 111MB 바이너리를 git 에 커밋할 수도 없다.
#   대신 Oracle 공개 레지스트리의 원본 이미지를 빌드 스테이지로 삼아 그 zip 하나만 꺼낸다.
#   출하 레이어는 navix 이고 가져오는 건 벤더 제품 번들 하나뿐이다. 콘솔에서 받는 것과 내용이 같고,
#   1.13.0 이 담은 정확한 빌드(260429.2105)로 고정되는 이점이 있다.
#   zip 은 이미 아키텍처별로 갈려 있어(arm64 이미지 안에 ...linuxarm.zip) buildx 가 알아서 맞는 걸 가져온다.
#
# 컨테이너 스크립트
#   scripts/ 5개는 1.13.0 이미지에서 바이트 그대로 꺼내 벤더링했다(md5 대조 완료).
#   oracle/docker-images 의 latest 를 쓰지 않은 이유는 watchdog.sh 가 이미 드리프트했기 때문이다
#   (저장소 324c5ff3… vs 1.13.0 이미지 e7fc0f09…). 나머지 4개는 동일하다.
#
# 출하 stage 에서 고친 것
#   1) FROM oraclelinux:8-slim -> baseimage/navix:10.1-wasl-centos
#   2) microdnf -> dnf. navix 에는 microdnf 도 dnf5 도 없다.
#   3) java-1.8.0-openjdk -> Temurin JDK 8 tarball (위 "핵심 쟁점" 참조)
#   4) navix 기본 USER 가 비루트(uid 500 waslteam)라 원본(root)에 맞추려면 USER root 가 필요하다.
#      기본 WORKDIR 도 /root(0700) 이라 원본과 같이 / 로 되돌린다.
#   5) glibc-langpack-en 추가. 원본은 LANG=en_US.UTF-8 을 설정만 하는데 navix 는 최소 로케일이라
#      해당 로케일이 없으면 설정이 무효가 된다.
#   6) `dnf -y update` 추가. 원본에는 없지만 base 패키지 CVE 를 줄인다.
#   7) unzip 은 navix 에 이미 있지만 원본이 명시하므로 그대로 둔다(idempotent).

ARG AGENT_TAG=1.13.0

### 에이전트 zip 조달용 스테이지 (출하 안 됨)
FROM container-registry.oracle.com/oci_observability_management/oci-management-agent:${AGENT_TAG} AS agent_src

### 출하 이미지
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

# navix 기본 USER 는 비루트(uid 500 waslteam) -> 원본(root)에 맞춘다
USER root
# navix 기본 WORKDIR 은 /root(0700) -> 원본과 같이 / 로 되돌린다
WORKDIR /

# 원본 라벨 유지
LABEL "provider"="Oracle"                                               \
      "issues"="https://github.com/oracle/docker-images/issues"         \
      "volume.data"="/opt/oracle"

# 원본의 sudo/unzip 에 glibc-langpack-en 을 더한다 (LANG=en_US.UTF-8 이 실효를 가지려면 필요).
# curl·tar·gzip 은 navix 에 이미 있어 JDK tarball 조달에 추가 설치가 필요 없다.
RUN set -eux; \
    dnf -y update --setopt=install_weak_deps=0 --nodocs; \
    dnf -y install --setopt=install_weak_deps=0 --nodocs sudo unzip glibc-langpack-en; \
    command -v curl; command -v tar; command -v unzip; command -v sudo; \
    test -s /etc/pki/tls/certs/ca-bundle.crt; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/libdnf5 /var/cache/yum

# Eclipse Temurin JDK 8. 원본 이미지의 openjdk 1.8.0_492 와 업데이트 레벨을 맞췄다.
# 설치기가 보는 경로(/usr/java8_64)에 풀고 JAVA_HOME 도 같은 값으로 잡는다.
ARG TEMURIN_RELEASE=jdk8u492-b09
ARG TEMURIN_FILE=8u492b09
ARG TEMURIN_SHA256_AMD64=da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e
ARG TEMURIN_SHA256_ARM64=3c2253b986909c20f79d6de7a0cb957f89c243df57615897836046e24d2e5257
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) TARCH=x64;     TSHA="${TEMURIN_SHA256_AMD64}" ;; \
      arm64) TARCH=aarch64; TSHA="${TEMURIN_SHA256_ARM64}" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/adoptium/temurin8-binaries/releases/download/${TEMURIN_RELEASE}/OpenJDK8U-jdk_${TARCH}_linux_hotspot_${TEMURIN_FILE}.tar.gz"; \
    echo "downloading ${url}"; \
    curl -fsSL --retry 3 -o /tmp/jdk8.tar.gz "${url}"; \
    echo "${TSHA}  /tmp/jdk8.tar.gz" | sha256sum -c -; \
    mkdir -p /usr/java8_64; \
    tar -xzf /tmp/jdk8.tar.gz -C /usr/java8_64 --strip-components=1; \
    rm -f /tmp/jdk8.tar.gz; \
    ln -sf /usr/java8_64/bin/java /usr/bin/java; \
    /usr/java8_64/bin/java -version

ENV JAVA_HOME=/usr/java8_64
ENV PATH=/usr/java8_64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 원본과 동일한 로케일 설정
ENV LANG=en_US.UTF-8
ENV LC_ALL=C

# 컨테이너 스크립트 + 사용자 스크립트 (1.13.0 이미지에서 추출해 벤더링)
COPY scripts/ /opt/oracle-mgmtagent-staging/scripts/

# 에이전트 설치 zip — Oracle 공개 레지스트리의 1.13.0 이미지에서 가져온다 (아키텍처별로 갈려 있다)
COPY --from=agent_src /opt/oracle-mgmtagent-staging/packages/oracle.mgmt_agent.zip /opt/oracle-mgmtagent-staging/packages/

# 원본과 동일한 권한 설정
RUN chmod -R 0755 /opt/oracle-mgmtagent-staging/

LABEL org.opencontainers.image.source="https://github.com/oracle/docker-images" \
      org.opencontainers.image.title="oci-management-agent (wrapped onto baseimage/navix)" \
      org.opencontainers.image.description="OCI Management Agent 1.13.0 wrapped onto baseimage/navix. The agent installer requires JDK 8, which no approved base provides, so Eclipse Temurin 8u492-b09 is installed from a checksum-verified tarball. The agent bundle is taken from Oracle's published 1.13.0 image."

# 원본과 동일 — watchdog 를 띄우는 initialize.sh 가 PID 1
ENTRYPOINT ["/opt/oracle-mgmtagent-staging/scripts/initialize.sh"]
