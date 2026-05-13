#!/usr/bin/env bash
# Minimal smoke test: each managed service should be active.
# Usage:  ./scripts/smoke.sh
set -uo pipefail

CONTAINER="${CONTAINER:-puppet-lab}"
FAIL=0

check() {
  local label="$1"; shift
  if docker exec "${CONTAINER}" "$@" >/dev/null 2>&1; then
    printf "  \033[32mOK\033[0m   %s\n" "${label}"
  else
    printf "  \033[31mFAIL\033[0m %s\n" "${label}"
    FAIL=1
  fi
}

echo "==> Service status (inside ${CONTAINER})"
check "bind9    running"          bash -c "pgrep -x named >/dev/null"
check "isc-dhcp present (config)" bash -c "[ -f /etc/dhcp/dhcpd.conf ]"
check "postfix  running"          bash -c "pgrep -x master >/dev/null"
check "nginx    running"          bash -c "pgrep -x nginx  >/dev/null"

echo
echo "==> Nginx serves managed page on port 80"
check "HTTP 200 on /"             bash -c "curl -sSf http://127.0.0.1/ | grep -q 'puppet-lab'"

echo
if [ "${FAIL}" -ne 0 ]; then
  echo "smoke test FAILED" >&2
  exit 1
fi
echo "smoke test passed"
