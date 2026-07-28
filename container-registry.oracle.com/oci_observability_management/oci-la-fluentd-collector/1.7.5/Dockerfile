# 원본: container-registry.oracle.com/oci_observability_management/oci-la-fluentd-collector:1.7.5
#   OCI Logging Analytics 용 Fluentd 수집기. Oracle 이 자기네 공개 레지스트리에 올린 외부 이미지다.
# 소스: https://github.com/oracle-quickstart/oci-kubernetes-monitoring
#   원본 Dockerfile: logan/docker-images/v1.0/oraclelinux/8-slim/Dockerfile
#   1.7.5 = 그 저장소 HEAD(fc023c2a3b6a6c151700c8cf64740ce68c4972f5, 2026-06-10) 기준이다.
#     저장소 태그는 v3.3.0 같은 차트 버전이라 이미지 태그와 대응하지 않는다. 대신 CHANGELOG.md 와
#     charts/logan/values.yaml·charts/oci-onm/values.yaml 이 HEAD 에서 1.7.5 를 가리킨다.
#   Gemfile, Gemfile.lock, entrypoint.sh, tcpconnect.{c,h,bpf.c} 는 그 경로에서 그대로 가져와
#     이 디렉터리에 같이 뒀다 (CI 빌드 컨텍스트가 Dockerfile 이 있는 디렉터리다).
#   라이선스: UPL-1.0 (Universal Permissive License v1.0)
# 계열 매핑: Oracle Linux 8.10 (RHEL 계열) -> baseimage/navix:10.1-wasl-centos
#
# 원본 published 이미지 설정 — 맞춰야 하는 계약:
#   USER=root   WORKDIR=/fluentd   ENTRYPOINT=["tini","--","/fluentd/entrypoint.sh"]   CMD=(없음)
#   arch=amd64+arm64
#   확인은 `docker buildx imagetools inspect --format '{{json .Image}}'` 로 했다.
#   멀티플랫폼 이미지는 `docker inspect` 가 설정을 전부 빈 값으로 돌려주니 그걸로 판단하면 안 된다.
#
# 원본은 2-stage 인데 여기서는 3-stage 다. 이유는 하나 — 네이티브 확장의 ABI 다.
#   처음엔 원본대로 빌더 하나(oraclelinux:8-slim)를 그대로 두고 출하 stage 만 navix 로 바꿨다.
#   빌드는 통과했지만 gem 번들의 ffi_c.so 가 navix 에서 `libffi.so.6 => not found` 로 죽었다.
#   OL8 은 libffi 3.1(so.6), CentOS Stream 10 은 3.4(so.8) 이고 so.6 호환 패키지가 없다.
#   그래서 ruby gem 은 런타임과 같은 navix 에서 컴파일하고, C 산출물만 원본 OL8 툴체인에 남겼다.
#     c_builder   (OL8)   : tini, jemalloc, tcpconnect — glibc 만 링크해 상위 버전에서 그대로 돈다
#     gem_builder (navix) : gem 번들 — 런타임과 같은 libffi·openssl·ruby ABI 로 컴파일
#   두 빌더 모두 출하되지 않으므로 정책 대상은 마지막 stage 하나다.
#
# 출하 stage 에서 고친 것
#   1) FROM oraclelinux:8-slim -> baseimage/navix:10.1-wasl-centos
#   2) microdnf -> dnf. navix 에는 microdnf 도 dnf5 도 없고 dnf 만 있다.
#   3) `module enable ruby:3.3` 제거. CentOS Stream 10 은 모듈러리티를 없앴다("modularity is
#      deprecated"). 대신 AppStream 이 ruby 3.3.10 을 기본으로 준다 — 원본 이미지의 ruby 3.3.10 과
#      같은 버전이라 gem 경로가 그대로 유효하다.
#   4) navix 기본 USER 가 비루트(uid 500 waslteam)라 원본대로 root 로 돌리려면 USER root 가 필요하다.
#      원본 Dockerfile 에도 있는 줄이라 그대로 뒀다.
#   5) libyaml 을 명시적으로 설치한다. psych 확장이 libyaml.so.0 을 링크하는데 빌드 stage 에서만
#      libyaml-devel 로 딸려오던 것이라, 출하 stage 에 없으면 런타임에 죽는다.
#   6) rm -rf 대상에 /var/cache/libdnf5 를 더했다.
#
# 검증 (로컬 arm64)
#   fluentd 1.17.1 기동, OCI Logging Analytics 플러그인 로드, gem 네이티브 확장 14개 전부 해소,
#   tini 0.19.0 / tcpconnect / libjemalloc.so.2 동작 확인.

### stage 1 — C 산출물 전용 빌더 (원본 oraclelinux:8-slim 유지)
## tini / jemalloc / tcpconnect(eBPF) 만 만든다. 원본에 있던 ruby·bundler 설치와 bundle install 은
## stage 2 로 옮겼으므로 여기서는 뺐다. 나머지 절차와 버전 핀은 원본 그대로다.
FROM container-registry.oracle.com/os/oraclelinux:8-slim AS c_builder
USER root
WORKDIR /build
COPY tcpconnect.* /build/
RUN microdnf -y update --setopt=install_weak_deps=0 --nodocs \
 && microdnf --enablerepo ol8_codeready_builder -y install --nodocs gcc make redhat-rpm-config openssl gcc-c++ libtool bzip2 git which elfutils-libelf-devel clang llvm \
 && microdnf -y install --setopt=install_weak_deps=0 --nodocs oracle-epel-release-el8 \
 && microdnf -y install --nodocs tini-0.19.0 \
 && cd /tmp \
 && git clone -b 5.3.0 https://github.com/jemalloc/jemalloc.git && cd jemalloc/ \
 && ./autogen.sh && make && make install_bin install_include install_lib \
 && mv lib/libjemalloc.so.2 /usr/lib \
 && cd /tmp \
 && git clone -b v0.29.1 https://github.com/iovisor/bcc.git && cd bcc/ && git submodule update --init --recursive \
 && cd libbpf-tools/ && cp /build/tcpconnect.* ./ && make \
 && mv ./tcpconnect /usr/bin/

### stage 2 — gem 번들 빌더 (출하 stage 와 같은 navix)
## libyaml-devel 이 navix 기본 리포지터리에 없다 (RHEL10 계열에서 CRB 소속인데 navix 에는 CRB 가
## 설정돼 있지 않다). 없으면 psych 5.1.2 컴파일이 실패한다. navix 가 이미 mirror.stream.centos.org
## 에서 BaseOS·AppStream 을 직접 받으므로, 같은 미러의 CRB 를 빌더에서만 켠다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos AS gem_builder
USER root
WORKDIR /fluentd
ENV PATH=/fluentd/vendor/bundle/ruby/3.3/bin:$PATH
ENV GEM_PATH=/fluentd/vendor/bundle/ruby/3.3
ENV GEM_HOME=/fluentd/vendor/bundle/ruby/3.3
ENV FLUENTD_DISABLE_BUNDLER_INJECTION=1
COPY Gemfile* /fluentd/
RUN set -eux; \
    printf '[crb]\nname=CentOS Stream 10 - CRB\nbaseurl=https://mirror.stream.centos.org/10-stream/CRB/$basearch/os/\ngpgcheck=0\nenabled=0\n' > /etc/yum.repos.d/crb.repo; \
    dnf -y install --setopt=install_weak_deps=0 --nodocs ruby ruby-libs rubygems; \
    ruby -e 'raise "ruby 3.3 expected, got #{RUBY_VERSION}" unless RUBY_VERSION.start_with?("3.3.")'; \
    gem install bundler -v 2.5.16; \
    dnf -y --enablerepo=crb install --nodocs gcc make redhat-rpm-config openssl ruby-devel gcc-c++ libtool libffi-devel bzip2 git libyaml-devel which; \
    bundle config silence_root_warning true; \
    bundle config --local path /fluentd/vendor/bundle; \
    bundle config --global jobs 9; \
    bundle install --gemfile=/fluentd/Gemfile

### stage 3 — 출하 이미지 (원본 oraclelinux:8-slim 을 승인 BaseImage 로 교체)
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

# navix 기본 USER 는 비루트(uid 500 waslteam) -> 원본(root)에 맞춘다
USER root
WORKDIR /fluentd

ENV PATH=/fluentd/vendor/bundle/ruby/3.3/bin:$PATH
ENV GEM_PATH=/fluentd/vendor/bundle/ruby/3.3
ENV GEM_HOME=/fluentd/vendor/bundle/ruby/3.3
ENV FLUENTD_DISABLE_BUNDLER_INJECTION=1

# 원본의 microdnf 를 dnf 로 바꾸고 module enable 을 뺐다 (위 "출하 stage 에서 고친 것" 2·3번).
# libyaml 은 psych 확장이 링크하는 런타임 라이브러리라 여기서 명시적으로 넣는다.
# gem 번들 경로가 ruby/3.3 로 고정돼 있어, ruby 가 3.3 이 아니면 여기서 빌드를 세운다.
RUN set -eux; \
    dnf -y update --setopt=install_weak_deps=0 --nodocs; \
    dnf -y install --setopt=install_weak_deps=0 --nodocs ruby ruby-libs rubygems libyaml; \
    ruby -e 'raise "ruby 3.3 expected, got #{RUBY_VERSION}" unless RUBY_VERSION.start_with?("3.3.")'; \
    gem install bundler -v 2.5.16; \
    bundle config --local path /fluentd/vendor/bundle; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/libdnf5 /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

COPY --from=gem_builder /fluentd /fluentd
COPY --from=c_builder /usr/bin/tini /usr/bin/tini
COPY --from=c_builder /usr/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so.2
COPY --from=c_builder /usr/bin/tcpconnect /usr/bin/tcpconnect

RUN mkdir -p /fluentd/etc /fluentd/plugins \
 && touch /fluentd/etc/disable.conf

ENV FLUENTD_CONF="/fluentd/etc/fluent.conf"
ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"

COPY entrypoint.sh /fluentd/entrypoint.sh
RUN ["chmod", "+x", "/fluentd/entrypoint.sh"]

LABEL org.opencontainers.image.source="https://github.com/oracle-quickstart/oci-kubernetes-monitoring" \
      org.opencontainers.image.title="oci-la-fluentd-collector (wrapped onto baseimage/navix)" \
      org.opencontainers.image.description="OCI Logging Analytics Fluentd collector 1.7.5, wrapped onto baseimage/navix. Ruby gems are rebuilt on navix so native extensions match the runtime ABI; tini, jemalloc and the tcpconnect eBPF tool keep the upstream Oracle Linux toolchain." \
      org.opencontainers.image.licenses="UPL-1.0"

ENTRYPOINT ["tini", "--", "/fluentd/entrypoint.sh"]
