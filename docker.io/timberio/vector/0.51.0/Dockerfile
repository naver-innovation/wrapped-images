# 원본          : docker.io/timberio/vector:0.51.0 (외부 OSS — vectordotdev/vector). 운영 배포본 = alpine(musl) 변형.
# 원본 base      : alpine (musl). 기본 USER=root, WORKDIR /, ENTRYPOINT ["/usr/local/bin/vector"]
# 계열 매핑      : 운영 중 이미지가 x86_64-unknown-linux-musl (alpine 변형)로 확인됨 → 계열 매핑상 alpine 유지.
#                  (musl → baseimage/alpine. glibc(navix)로 바꾸면 계열 불일치 → alpine 으로 래핑.)
# 방식          : vector alpine 변형은 정적(static) musl 바이너리(/usr/local/bin/vector)+config(/etc/vector)+
#                  data(/var/lib/vector) 구조. 원본 이미지를 빌드 전용(throwaway) 스테이지로 두고 설치물만
#                  COPY(소유권 보존). 바이너리는 fully-static(ldd: not a valid dynamic program)이라 런타임
#                  라이브러리 의존 없음 → TLS(ca-certificates)/타임존(tzdata)만 apk 로 보강(원본 alpine 변형 동일).
# 비고          : PHOTODEV-2267 후속. 기존 me-riyadh-1.ocir.io/axlo4g31gl45/vector:0.0.1-oci = 허용 base 래핑
#                  없이 OCIR 복제만 된 비표준본(운영 확인: 0.51.0 musl, ENTRYPOINT /usr/local/bin/vector) →
#                  본 래핑본으로 대체. 운영 파드는 args `--config-dir ...` 를 ENTRYPOINT 에 전달하므로
#                  ENTRYPOINT(/usr/local/bin/vector) 동일 유지 필수. 멀티아치(amd64/arm64)는 멀티아치 upstream +
#                  멀티아치 base 라 CI 아키텍처별 네이티브 빌드에서 자동 정합.

# --- 파일 출처 스테이지 (출하 안 됨) ---
FROM docker.io/timberio/vector:0.51.0-alpine AS upstream

# --- 런타임 (출하): 허용 base alpine ---
FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root

# 런타임 의존: TLS(ca-certificates), 타임존(tzdata). 바이너리는 정적 musl 이라 별도 lib 불필요.
RUN apk add --no-cache ca-certificates tzdata

# 원본 설치물(정적 바이너리·설정)을 소유권 보존해 그대로 가져옴
COPY --from=upstream /usr/local/bin/vector /usr/local/bin/vector
COPY --from=upstream /etc/vector /etc/vector
# data 디렉토리는 idempotent 생성 (원본 /var/lib/vector 는 빈 디렉토리)
RUN mkdir -p /var/lib/vector

LABEL org.opencontainers.image.source=https://github.com/vectordotdev/vector
LABEL org.opencontainers.image.licenses=MPL-2.0
LABEL org.opencontainers.image.version=0.51.0

# 원본 alpine 변형과 동일 실행 사양 (root 실행, WORKDIR /, ENTRYPOINT /usr/local/bin/vector)
WORKDIR /
ENTRYPOINT ["/usr/local/bin/vector"]
