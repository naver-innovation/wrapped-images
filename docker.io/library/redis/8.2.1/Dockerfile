# 원본: docker.io/library/redis:8.2.1  (Docker 공식 redis)
#   https://github.com/docker-library/redis  (debian/Dockerfile, redis 8.2 라인)
# 원본 base: FROM debian:bookworm-slim  (debian / glibc 계열)
# 계열 매핑: debian → baseimage/ubuntu:24.04  (둘 다 debian 계열·glibc·apt — 호환)
#
# 비고: docker-library/redis 는 redis 8.2.0/8.2.1 용 공식 이미지를 발행하지 않았고
#   8.0.6 다음 8.2.2 로 점프했다. 따라서 8.2 라인의 정식(canonical) Dockerfile 구조
#   (docker-library 8.2.2 브랜치 debian/Dockerfile)를 그대로 사용하되,
#   REDIS_DOWNLOAD_URL/SHA 만 redis 8.2.1 릴리스(2025-08-18)로 핀고정한다.
#   SHA256 은 https://github.com/redis/redis/archive/refs/tags/8.2.1.tar.gz 를
#   직접 받아 계산한 값:
#     517e47ebce911ebbed2fe86047a871d9cbeadc7d2de15ffca37a1540eb4d588f
#
# 8.2 라인은 gosu/GPG 키 임포트를 쓰지 않는다. 권한 강하는 util-linux 의 setpriv
#   (entrypoint) 로 처리하고, 소스 tarball 은 HTTPS 다운로드 + SHA256 검증만 한다.
# 멀티스테이지가 아닌 단일 stage 빌드이므로, 그 한 stage 의 FROM 만 교체한다.
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/docker-library/redis
LABEL org.opencontainers.image.description="Redis is an open source key-value store that functions as a data structure server."
LABEL org.opencontainers.image.licenses=BSD-3-Clause

# baseimage/ubuntu 는 기본 USER 가 비루트 → apt/빌드/유저생성 위해 root 로 전환
# (런타임 기본 USER 는 이 파일 마지막에서 redis 로 복귀)
USER root

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
# baseimage 는 clean 이 아닐 수 있으므로 멱등 처리 (이미 존재해도 실패하지 않음).
RUN set -eux; \
	groupadd -r -g 999 redis 2>/dev/null || true; \
	useradd -r -g redis -u 999 redis 2>/dev/null || true

# runtime dependencies
# setpriv(entrypoint 의 권한 강하)은 util-linux, bash 는 entrypoint 셸로 필요.
# baseimage/ubuntu 가 이들을 항상 포함한다고 보장할 수 없어 명시 설치한다.
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		bash \
		util-linux \
# add tzdata explicitly for https://github.com/docker-library/redis/issues/138 (see also https://bugs.debian.org/837060 and related)
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

ENV REDIS_DOWNLOAD_URL=https://github.com/redis/redis/archive/refs/tags/8.2.1.tar.gz
ENV REDIS_DOWNLOAD_SHA=517e47ebce911ebbed2fe86047a871d9cbeadc7d2de15ffca37a1540eb4d588f
RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		wget \
		dpkg-dev \
		gcc \
		g++ \
		libc6-dev \
		libssl-dev \
		make; \
	\
	arch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	case "$arch" in \
		'amd64') export BUILD_WITH_MODULES=yes; export INSTALL_RUST_TOOLCHAIN=yes; export DISABLE_WERRORS=yes ;; \
		'arm64') export BUILD_WITH_MODULES=yes; export INSTALL_RUST_TOOLCHAIN=yes; export DISABLE_WERRORS=yes ;; \
		*) echo >&2 "Modules are NOT supported! unsupported architecture: '$arch'"; export BUILD_WITH_MODULES=no ;; \
	esac; \
	if [ "$BUILD_WITH_MODULES" = "yes" ]; then \
		apt-get install -y --no-install-recommends \
			git \
			cmake \
			python3 \
			python3-pip \
			python3-venv \
			python3-dev \
			unzip \
			rsync \
			clang \
			automake \
			autoconf \
			libtool \
			g++; \
	fi; \
	\
	rm -rf /var/lib/apt/lists/*; \
	\
	wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
	echo "$REDIS_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c -; \
	mkdir -p /usr/src/redis; \
	tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
	rm redis.tar.gz; \
	\
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/redis/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
	grep -E '^ *createBoolConfig[(]"protected-mode",.*, *1 *,.*[)],$' /usr/src/redis/src/config.c; \
	sed -ri 's!^( *createBoolConfig[(]"protected-mode",.*, *)1( *,.*[)],)$!\10\2!' /usr/src/redis/src/config.c; \
	grep -E '^ *createBoolConfig[(]"protected-mode",.*, *0 *,.*[)],$' /usr/src/redis/src/config.c; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
# https://github.com/jemalloc/jemalloc/issues/467 -- we need to patch the "./configure" for the bundled jemalloc to match how Debian compiles, for compatibility
# (also, we do cross-builds, so we need to embed the appropriate "--build=xxx" values to that "./configure" invocation)
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	extraJemallocConfigureFlags="--build=$gnuArch"; \
# https://salsa.debian.org/debian/jemalloc/-/blob/c0a88c37a551be7d12e4863435365c9a6a51525f/debian/rules#L8-23
	case "${arch##*-}" in \
		amd64 | i386 | x32) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=12" ;; \
		*) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=16" ;; \
	esac; \
	extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-hugepage=21"; \
	grep -F 'cd jemalloc && ./configure ' /usr/src/redis/deps/Makefile; \
	sed -ri 's!cd jemalloc && ./configure !&'"$extraJemallocConfigureFlags"' !' /usr/src/redis/deps/Makefile; \
	grep -F "cd jemalloc && ./configure $extraJemallocConfigureFlags " /usr/src/redis/deps/Makefile; \
	\
	export BUILD_TLS=yes; \
	make -C /usr/src/redis -j "$(nproc)" all; \
	make -C /usr/src/redis install; \
	\
# TODO https://github.com/redis/redis/pull/3494 (deduplicate "redis-server" copies)
	serverMd5="$(md5sum /usr/local/bin/redis-server | cut -d' ' -f1)"; export serverMd5; \
	find /usr/local/bin/redis* -maxdepth 0 \
		-type f -not -name redis-server \
		-exec sh -eux -c ' \
			md5="$(md5sum "$1" | cut -d" " -f1)"; \
			test "$md5" = "$serverMd5"; \
		' -- '{}' ';' \
		-exec ln -svfT 'redis-server' '{}' ';' \
	; \
	\
	make -C /usr/src/redis distclean; \
	rm -r /usr/src/redis; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/cache/debconf/*; \
	\
	redis-cli --version; \
	redis-server --version

RUN mkdir /data && chown redis:redis /data
VOLUME /data
WORKDIR /data

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 6379
# baseimage/ubuntu 정책상 기본 USER 는 비루트여야 한다 → redis(uid 999)로 복귀.
# entrypoint 는 uid!=0 이면 권한 강하 단계를 건너뛰고 그대로 redis 로 실행한다.
USER redis
CMD ["redis-server"]
