# 원본: docker.io/library/python:3.12-slim  (= 3.12-slim-bookworm, PYTHON_VERSION 3.12.13)
# 소스: https://github.com/docker-library/python -> 3.12/slim-bookworm/Dockerfile
#   원본은 apply-templates.sh 로 생성되는 파일이라 직접 수정하지 말라고 적혀 있다.
#   여기서는 그 생성 결과물을 기준으로 옮겼다.
#   라이선스: PSF-2.0 (CPython), Dockerfile 은 docker-library MIT
# 계열 매핑: debian:bookworm-slim (apt) -> baseimage/ubuntu:24.04
#
# 원본 published 이미지 설정 — 맞춰야 하는 계약:
#   USER=(빈값 = root)   WORKDIR=(빈값)   ENTRYPOINT=(없음)   CMD=["python3"]
#   ENV LANG=C.UTF-8, PATH 앞에 /usr/local/bin
#   확인은 `docker buildx imagetools inspect --format '{{json .Image}}'` 로 했다.
#   멀티플랫폼 이미지는 `docker inspect` 가 설정을 전부 빈 값으로 돌려주니 그걸로 판단하면 안 된다.
#   원본은 8개 아키텍처를 내지만 이 저장소 CI 는 amd64/arm64 두 개만 낸다.
#
# 출하 stage 에서 고친 것 — 원본과의 차이는 셋뿐이다
#   1) FROM debian:bookworm-slim -> baseimage/ubuntu:24.04
#      원본 apt 패키지 20개가 noble 에 같은 이름으로 전부 존재해서 패키지명 보정이 없다
#      (libncursesw5-dev 도 noble 에 그대로 있다). 그래서 빌드 절차를 한 줄도 바꾸지 않았다.
#   2) USER root 추가. baseimage/ubuntu 기본 USER 가 waslteam(uid 1000)이라 원본(root)과 다르다.
#      WORKDIR 은 손대지 않았다 — 원본도 baseimage 도 빈 값(=/)이라 이미 같다.
#   3) GPG 키를 HTTPS 로 먼저 받고 실패할 때만 키서버로 넘어간다.
#      원본은 `gpg --keyserver hkps://keys.openpgp.org --recv-keys` 만 쓰는데, 빌드 네트워크에서
#      키서버 프로토콜이 막히는 사례가 있다. keys.openpgp.org 의 HTTPS 조회를 1순위로 두고
#      원본 경로를 폴백으로 남겼다. 어느 쪽으로 받든 gpg --verify 와 sha256 검증은 그대로다.
#
# 참고 — baseimage/ubuntu 는 apt 소스가 사내 미러(nexus.naver-innovation.net)라
#   사내망 밖에서는 apt 가 동작하지 않는다. CI 는 사내망에서 돌아 문제없다.
#   로컬 검증은 소스를 공개 미러로 바꾼 사본에서 했다 (저장소 파일은 base 설정 그대로 둔다).
#
# 확인해 둔 것 (원본 절차를 그대로 유지해도 되는 근거)
#   - baseimage/ubuntu 의 /usr/local/bin 이 비어 있다. 원본 심볼릭 링크 루프의
#     `[ ! -e "/usr/local/bin/$dst" ]` 단정이 그대로 성립하므로 ln -sf 로 완화하지 않았다.
#   - base 에 python/python3 가 아예 없다. 시스템 libpython 과 충돌할 여지가 없고,
#     원본이 그 문제 때문에 넣어 둔 rpath 재빌드도 그대로 두면 된다.
#   - base 는 dpkg 180개 중 105개가 manual 이다. 원본 끝의 apt-get purge --auto-remove 는
#     savedAptMark 로 그 105개를 되살리므로 base 패키지를 걷어내지 않는다 (로컬 빌드로 확인).

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04

# baseimage/ubuntu 기본 USER 는 waslteam(uid 1000) -> 원본(root)에 맞춘다
USER root

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
# last attempted removal of LANG broke many users:
# https://github.com/docker-library/python/pull/570
ENV LANG C.UTF-8

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

ENV GPG_KEY 7169605F62C751356D054A26A821E680E5FA6305
ENV PYTHON_VERSION 3.12.13
ENV PYTHON_SHA256 c08bc65a81971c1dd5783182826503369466c7e67374d1646519adf05207b684

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		gcc \
		gnupg \
		libbluetooth-dev \
		libbz2-dev \
		libc6-dev \
		libdb-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		tk-dev \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
	; \
	\
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
# 키서버가 막힌 빌드 네트워크를 대비해 HTTPS 조회를 먼저 쓴다 (원본은 키서버만 쓴다)
	if wget -q -O "$GNUPGHOME/pubkey.asc" "https://keys.openpgp.org/vks/v1/by-fingerprint/$GPG_KEY"; then \
		gpg --batch --import "$GNUPGHOME/pubkey.asc"; \
	else \
		gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	fi; \
	gpg --batch --verify python.tar.xz.asc python.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" python.tar.xz.asc; \
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	cd /usr/src/python; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--enable-option-checking=fatal \
		--enable-shared \
		$(test "${gnuArch%%-*}" != 'riscv64' && echo '--with-lto') \
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	LDFLAGS="${LDFLAGS:-} -Wl,--strip-all"; \
	arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
# https://docs.python.org/3.12/howto/perf_profiling.html
# https://github.com/docker-library/python/pull/1000#issuecomment-2597021615
	case "$arch" in \
		amd64|arm64) \
			# only add "-mno-omit-leaf" on arches that support it
			# https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/x86-Options.html#index-momit-leaf-frame-pointer-2
			# https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/AArch64-Options.html#index-momit-leaf-frame-pointer
			EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"; \
			;; \
		i386) \
			# don't enable frame-pointers on 32bit x86 due to performance drop.
			;; \
		*) \
			# other arches don't support "-mno-omit-leaf"
			EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer"; \
			;; \
	esac; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
	; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-} -Wl,-rpath='\$\$ORIGIN/../lib'" \
		python \
	; \
	make install; \
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
	ldconfig; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -rt dpkg-query --search \
# https://manpages.debian.org/bookworm/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	pip3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

LABEL org.opencontainers.image.source="https://github.com/docker-library/python" \
      org.opencontainers.image.title="python 3.12-slim (wrapped onto baseimage/ubuntu)" \
      org.opencontainers.image.description="CPython 3.12.13 built from source with the upstream docker-library/python slim-bookworm recipe, shipped on baseimage/ubuntu:24.04." \
      org.opencontainers.image.licenses="PSF-2.0"

CMD ["python3"]
