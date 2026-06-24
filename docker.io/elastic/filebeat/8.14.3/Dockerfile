# 원본          : docker.io/elastic/filebeat:8.14.3
# 원본 base      : Ubuntu 20.04 (USER 1000=filebeat, WORKDIR /usr/share/filebeat)
# 계열 매핑      : 원본 ubuntu(glibc) → baseimage/ubuntu (filebeat 바이너리가 glibc 동적링크라
#                  musl 인 alpine 불가, 반드시 glibc base)
# 방식          : filebeat 은 단일 바이너리가 아니라 설치 디렉토리(binary+module+kibana)+entrypoint+tini
#                  구조라, 원본 이미지를 빌드 전용(throwaway) 스테이지로 두고 설치물만 COPY 해
#                  허용 base(baseimage/ubuntu) 위에 얹는다. 출하 레이어의 OS/userland = 승인 base.
#                  파일 소유권(root:root)·구조를 원본 그대로 보존 → 현재 배포본과 drop-in 동등.

# --- 파일 출처 스테이지 (출하 안 됨) ---
FROM docker.io/elastic/filebeat:8.14.3 AS upstream

# --- 런타임 (출하): 허용 base ubuntu ---
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/ubuntu:24.04
USER root

# 원본 entrypoint(docker-entrypoint)의 서브커맨드 탐지 awk 가 GNU awk 확장(\s)을 써서 gawk 필요.
# baseimage/ubuntu 기본은 mawk → gawk 설치 (원본 이미지도 gawk 포함).
RUN apt-get update && apt-get install -y --no-install-recommends gawk && rm -rf /var/lib/apt/lists/*

# baseimage/ubuntu 는 uid/gid 1000 을 'ubuntu' 가 선점 → 제거 후 원본과 동일한 filebeat(1000) 생성.
# 원본 filebeat 유저는 보조그룹 root(0) 멤버(groups=1000,0) — data/logs(root:root 0775)에
# group write 하려면 필수(OpenShift 호환 관례). -G 0 로 동일하게 맞춘다.
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd -g 1000 filebeat 2>/dev/null || true; \
    useradd -u 1000 -g 1000 -G 0 -d /usr/share/filebeat -s /bin/sh filebeat 2>/dev/null || true

# 원본 설치물·entrypoint·tini 를 소유권(root:root) 보존해 그대로 가져옴
COPY --from=upstream /usr/share/filebeat /usr/share/filebeat
COPY --from=upstream /usr/local/bin/docker-entrypoint /usr/local/bin/docker-entrypoint
COPY --from=upstream /usr/bin/tini /usr/bin/tini

LABEL org.opencontainers.image.source=https://github.com/elastic/beats
LABEL org.opencontainers.image.licenses=Elastic-2.0
LABEL org.opencontainers.image.version=8.14.3

# 원본 이미지와 동일한 ENV
ENV ELASTIC_CONTAINER=true \
    GODEBUG=madvdontneed=1 \
    LIBBEAT_MONITORING_CGROUPS_HIERARCHY_OVERRIDE=/ \
    PATH=/usr/share/filebeat:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /usr/share/filebeat
USER 1000
ENTRYPOINT [ "/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint" ]
CMD [ "-environment", "container" ]
