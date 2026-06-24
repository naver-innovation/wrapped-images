#!/bin/sh
# fluent-bit + metrics-proxy 동시 실행 래퍼.
# metrics-proxy 는 fluent-bit HTTP_Server 의 고정 경로(/api/v1/metrics/prometheus)를
# 커스텀 path 로 alias 하기 위한 경량 HTTP 중계 프로세스.
#
# METRICS_PROXY_PATH 와 METRICS_PROXY_PORT 가 모두 설정된 경우에만 proxy 활성화.
# 둘 중 하나라도 비어 있으면 proxy 를 띄우지 않는다 (기본값 바이어스 없음).

set -eu

if [ -n "${METRICS_PROXY_PATH:-}" ] && [ -n "${METRICS_PROXY_PORT:-}" ]; then
    /usr/local/bin/metrics-proxy &
fi

exec /opt/fluent-bit/bin/fluent-bit "$@"
