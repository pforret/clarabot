#!/usr/bin/env bash
#
# health-check.sh — Verify Clarabot is healthy after deployment
#
# Usage: scripts/health-check.sh <base_url>
#
# Runs a series of HTTP checks against the deployed application.
# Exits with code 0 if all checks pass, 1 if any fail.

set -euo pipefail

BASE_URL="${1:?Usage: health-check.sh <base_url>}"

# Remove trailing slash
BASE_URL="${BASE_URL%/}"

PASS=0
FAIL=0

check() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local max_retries="${4:-3}"
    local retry_delay="${5:-5}"

    for attempt in $(seq 1 "$max_retries"); do
        STATUS=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo "000")

        if [ "$STATUS" = "$expected_status" ]; then
            echo "  PASS  $name (HTTP $STATUS)"
            PASS=$((PASS + 1))
            return 0
        fi

        if [ "$attempt" -lt "$max_retries" ]; then
            echo "  RETRY $name (HTTP $STATUS, expected $expected_status, attempt $attempt/$max_retries)"
            sleep "$retry_delay"
        fi
    done

    echo "  FAIL  $name (HTTP $STATUS, expected $expected_status)"
    FAIL=$((FAIL + 1))
    return 1
}

echo "==> Running health checks against $BASE_URL"
echo ""

# Core health checks
check "Application up"     "$BASE_URL/up"
check "Login page"         "$BASE_URL/login"

echo ""
echo "==> Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
    echo "==> HEALTH CHECK FAILED"
    exit 1
fi

echo "==> All health checks passed"
exit 0
