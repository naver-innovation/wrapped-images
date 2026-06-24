#!/bin/bash
# preStop hook: 메인 앱 컨테이너가 종료된 이후 sidecar 가 종료되도록 대기하여
# 종료 직전 마지막 로그 전송을 보장한다.
#
# Usage:
#   prestop.sh --healthcheck-url <url> [--timeout <seconds>]

HEALTHCHECK_URL=""
TIMEOUT=60
INTERVAL=1

while [[ $# -gt 0 ]]; do
    case $1 in
        --healthcheck-url)
            HEALTHCHECK_URL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$HEALTHCHECK_URL" ]]; then
    echo "Error: --healthcheck-url is required"
    exit 1
fi

echo "Waiting for $HEALTHCHECK_URL to become unavailable (timeout: ${TIMEOUT}s)..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    if ! curl -sf "$HEALTHCHECK_URL" > /dev/null 2>&1; then
        echo "Health check failed. App container is shutting down."
        sleep 5
        exit 0
    fi
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
done

echo "Timeout reached. Proceeding with shutdown."
exit 0
