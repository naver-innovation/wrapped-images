# 원본: docker.io/library/mysql:8.0.35  (공식 mysql, Oracle Linux 8 변형 Dockerfile.oracle)
#   https://github.com/docker-library/mysql (8.0/Dockerfile.oracle @ commit 84ba05e — 8.0.35-1.el8)
# 원본 base:
#   runtime : oraclelinux:8-slim   (RHEL/dnf 계열)
# 계열 매핑:
#   RHEL(Oracle Linux 8) → baseimage/navix:10.1-wasl-centos  (RHEL/dnf 계열 유지)
# 단일 stage 이미지(빌드 stage 없음) → 런타임 FROM 만 교체.
#
# bitnami 대체: 이 이미지는 bitnamilegacy/mysql:8.0.35-debian-11-r0 (issue #6) 의 대체용이다.
#   bitnami 와 달리 공식 mysql 의 config/path/env 규약을 그대로 따른다(아래 PR 본문 참고).
#
# 계열 보정 포인트(원본 Dockerfile.oracle 대비 변경):
#   1) base 가 Oracle Linux 8 → navix(CentOS 10.1) 로 바뀌어도 설치 패키지는 EL8 빌드(.el8)를
#      그대로 쓴다. mysql 커뮤니티 RPM 은 el/9·el/10 docker 경로를 8.0.35 시점에 제공하지 않으므로
#      repo baseurl 의 ${VERSION_ID} 치환을 사용하지 않고 el8 을 고정한다.
#   2) navix 는 microdnf 가 없을 수 있어 microdnf→dnf 로 변환(빌드시 가용 패키지매니저 탐지).
#   3) GPG: 원본의 keyserver(hkps/keyserver.ubuntu.com) recv-keys 는 빌드망에서 막힌다(hkp 차단).
#      → 벤더 HTTPS 키로 교체하고 지문을 고정한다.
#        - gosu  : tianon 키 B42F6819007F00F88E364FD4036A9C25BF357DD4 (keys.openpgp.org HTTPS)
#        - mysql : MySQL Release Engineering 859BE8D7C586F538430B19C2467B942D3A79BD29
#                  (repo.mysql.com HTTPS RPM-GPG-KEY)
#   4) navix 기본 USER 는 비루트 → 설치 위해 USER root 로 전환.
#      런타임은 원본과 동일하게 root 로 시작하고 docker-entrypoint.sh 가 gosu 로 mysql(uid 999) 강등한다
#      (datadir chown 을 위해 entrypoint 가 root 권한을 필요로 하는 공식 mysql 설계 — 그대로 유지).

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/navix:10.1-wasl-centos

# navix 기본 USER 는 비루트 → dnf/설치 위해 root 로 전환.
USER root

# mysql 계정(uid/gid 999) 생성 — 원본과 동일. baseimage 가 clean 하지 않을 수 있어 멱등 처리.
RUN set -eux; \
	getent group mysql >/dev/null 2>&1 || groupadd --system --gid 999 mysql; \
	getent passwd mysql >/dev/null 2>&1 || useradd --system --uid 999 --gid 999 --home-dir /var/lib/mysql --no-create-home mysql

# 빌드/설치에 필요한 도구. navix(slim 계열)에 curl/gnupg 가 없을 수 있어 먼저 보정 설치.
# microdnf 우선, 없으면 dnf 사용. (원본 oraclelinux:8-slim 은 microdnf 만 존재)
RUN set -eux; \
	if command -v microdnf >/dev/null 2>&1; then PKG=microdnf; else PKG=dnf; fi; \
	$PKG install -y \
		ca-certificates \
		curl \
		gnupg2 \
		bzip2 \
		gzip \
		openssl \
		xz \
		zstd \
		findutils \
		shadow-utils \
		tar \
	; \
	$PKG clean all

# add gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.16
# 원본의 keyserver recv-keys 를 HTTPS 키(keys.openpgp.org)로 교체하고 지문 고정.
RUN set -eux; \
	arch="$(uname -m)"; \
	case "$arch" in \
		aarch64) gosuArch='arm64' ;; \
		x86_64) gosuArch='amd64' ;; \
		*) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; \
	esac; \
	curl -fL -o /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$gosuArch.asc"; \
	curl -fL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$gosuArch"; \
	export GNUPGHOME="$(mktemp -d)"; \
	GOSU_KEY='B42F6819007F00F88E364FD4036A9C25BF357DD4'; \
	curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/$GOSU_KEY" -o "$GNUPGHOME/gosu.key"; \
	gpg --batch --import "$GNUPGHOME/gosu.key"; \
	gpg --batch --list-keys --with-colons --fingerprint | grep -qi "^fpr:::::::::${GOSU_KEY}:"; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

# MySQL 패키지 서명 검증용 GPG 키 임포트.
# https://dev.mysql.com/doc/refman/8.0/en/checking-gpg-signature.html
# gpg: key 3A79BD29: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>"
# 원본의 keyserver recv-keys 를 HTTPS(repo.mysql.com) 로 교체하고 지문 고정.
RUN set -eux; \
	key='859BE8D7C586F538430B19C2467B942D3A79BD29'; \
	export GNUPGHOME="$(mktemp -d)"; \
	curl -fsSL 'https://repo.mysql.com/RPM-GPG-KEY-mysql-2022' -o "$GNUPGHOME/mysql.key"; \
	gpg --batch --import "$GNUPGHOME/mysql.key"; \
	gpg --batch --list-keys --with-colons --fingerprint | grep -qi "^fpr:::::::::${key}:"; \
	mkdir -p /etc/pki/rpm-gpg; \
	gpg --batch --export --armor "$key" > /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql; \
	gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME"

ENV MYSQL_MAJOR 8.0
ENV MYSQL_VERSION 8.0.35-1.el8

# MySQL 커뮤니티 서버(minimal) 레포 등록.
# 원본은 ${VERSION_ID%%[.-]*} 로 EL 메이저를 동적 치환하나, navix 는 CentOS 10 → el10 docker 경로가
# 8.0.35 시점에 없으므로 설치 대상 RPM(.el8)에 맞춰 el8 을 고정한다.
RUN set -eu; \
	{ \
		echo '[mysql8.0-server-minimal]'; \
		echo 'name=MySQL 8.0 Server Minimal'; \
		echo 'enabled=1'; \
		echo 'baseurl=https://repo.mysql.com/yum/mysql-8.0-community/docker/el/8/$basearch/'; \
		echo 'gpgcheck=1'; \
		echo 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql'; \
# https://github.com/docker-library/mysql/pull/680#issuecomment-825930524
		echo 'module_hotfixes=true'; \
	} | tee /etc/yum.repos.d/mysql-community-minimal.repo

RUN set -eux; \
	if command -v microdnf >/dev/null 2>&1; then PKG=microdnf; else PKG=dnf; fi; \
	$PKG install -y "mysql-community-server-minimal-$MYSQL_VERSION"; \
	$PKG clean all; \
# the "socket" value in the Oracle packages is set to "/var/lib/mysql" which isn't a great place for the socket (we want it in "/var/run/mysqld" instead)
# https://github.com/docker-library/mysql/pull/680#issuecomment-636121520
	grep -F 'socket=/var/lib/mysql/mysql.sock' /etc/my.cnf; \
	sed -i 's!^socket=.*!socket=/var/run/mysqld/mysqld.sock!' /etc/my.cnf; \
	grep -F 'socket=/var/run/mysqld/mysqld.sock' /etc/my.cnf; \
	{ echo '[client]'; echo 'socket=/var/run/mysqld/mysqld.sock'; } >> /etc/my.cnf; \
	\
# make sure users dumping files in "/etc/mysql/conf.d" still works
	! grep -F '!includedir' /etc/my.cnf; \
	{ echo; echo '!includedir /etc/mysql/conf.d/'; } >> /etc/my.cnf; \
	mkdir -p /etc/mysql/conf.d; \
# ensure these directories exist and have useful permissions
# the rpm package has different opinions on the mode of `/var/run/mysqld`, so this needs to be after install
	mkdir -p /var/lib/mysql /var/run/mysqld; \
	chown mysql:mysql /var/lib/mysql /var/run/mysqld; \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	chmod 1777 /var/lib/mysql /var/run/mysqld; \
	\
	mkdir -p /docker-entrypoint-initdb.d; \
	\
	mysqld --version; \
	mysql --version

# MySQL Tools(mysql-shell) 레포 등록 + 설치.
RUN set -eu; \
	{ \
		echo '[mysql-tools-community]'; \
		echo 'name=MySQL Tools Community'; \
		echo 'baseurl=https://repo.mysql.com/yum/mysql-tools-community/el/8/$basearch/'; \
		echo 'enabled=1'; \
		echo 'gpgcheck=1'; \
		echo 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql'; \
# https://github.com/docker-library/mysql/pull/680#issuecomment-825930524
		echo 'module_hotfixes=true'; \
	} | tee /etc/yum.repos.d/mysql-community-tools.repo
ENV MYSQL_SHELL_VERSION 8.0.35-1.el8
RUN set -eux; \
	if command -v microdnf >/dev/null 2>&1; then PKG=microdnf; else PKG=dnf; fi; \
	$PKG install -y "mysql-shell-$MYSQL_SHELL_VERSION"; \
	$PKG clean all; \
	\
	mysqlsh --version

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -sf usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]
