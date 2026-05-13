#!/usr/bin/env bash
# Minimal smoke test: managed services/config should be present and queryable.
# Usage:  ./scripts/smoke.sh
set -uo pipefail

CONTAINER="${CONTAINER:-puppet-lab}"
FAIL=0

if ! docker exec "${CONTAINER}" true >/dev/null 2>&1; then
  echo "Cannot exec into container '${CONTAINER}'. Check Docker permissions or start it with: docker compose up -d" >&2
  exit 1
fi

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
check "named    running"          bash -c "pgrep -x named >/dev/null"
check "isc-dhcp present (config)" bash -c "[ -f /etc/dhcp/dhcpd.conf ]"
check "postfix  running"          bash -c "pgrep -x master >/dev/null"
check "nginx    running"          bash -c "pgrep -x nginx  >/dev/null"

echo
echo "==> Nginx serves managed page on port 80"
check "HTTP 200 on /"             bash -c "curl -sSf http://127.0.0.1/ | grep -q 'puppet-lab'"

echo
echo "==> BIND9 authoritative answers"
check "lab.local SOA"             bash -c "dig @127.0.0.1 lab.local SOA +short | grep -q 'ns1.lab.local.'"
check "www.lab.local A"           bash -c "dig @127.0.0.1 www.lab.local A +short | grep -qx '192.0.2.20'"
check "lab.local MX"              bash -c "dig @127.0.0.1 lab.local MX +short | grep -qx '10 mail.lab.local.'"

echo
if [ "${FAIL}" -ne 0 ]; then
  echo "smoke test FAILED" >&2
  exit 1
fi
echo "smoke test passed"
