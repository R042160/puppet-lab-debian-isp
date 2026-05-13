#!/usr/bin/env bash
# Minimal smoke test: managed services/config should be present and queryable.
# Usage:  ./scripts/smoke.sh
set -uo pipefail

PRIMARY_CONTAINER="${PRIMARY_CONTAINER:-puppet-lab}"
SECONDARY_CONTAINER="${SECONDARY_CONTAINER:-puppet-lab-secondary}"
CLIENT_CONTAINER="${CLIENT_CONTAINER:-puppet-lab-client}"
PRIMARY_IP="${PRIMARY_IP:-172.28.53.10}"
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

check_in() {
  local container="$1"; shift
  local label="$1"; shift

  if docker exec "${container}" "$@" >/dev/null 2>&1; then
    printf "  \033[32mOK\033[0m   %s\n" "${label}"
  else
    printf "  \033[31mFAIL\033[0m %s\n" "${label}"
    FAIL=1
  fi
}

check_retry_in() {
  local container="$1"; shift
  local label="$1"; shift
  local attempt

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if docker exec "${container}" "$@" >/dev/null 2>&1; then
      printf "  \033[32mOK\033[0m   %s\n" "${label}"
      return
    fi
    sleep 1
  done

  printf "  \033[31mFAIL\033[0m %s\n" "${label}"
  FAIL=1
}

check_denied_axfr_in() {
  local container="$1"; shift
  local label="$1"; shift
  local output

  output="$(docker exec "${container}" bash -c "dig @${PRIMARY_IP} lab.local AXFR +short" 2>&1 || true)"

  if printf "%s\n" "${output}" | grep -q "192.0.2.20"; then
    printf "  \033[31mFAIL\033[0m %s\n" "${label}"
    FAIL=1
  else
    printf "  \033[32mOK\033[0m   %s\n" "${label}"
  fi
}

for container in "${PRIMARY_CONTAINER}" "${SECONDARY_CONTAINER}" "${CLIENT_CONTAINER}"; do
  if ! docker exec "${container}" true >/dev/null 2>&1; then
    echo "Cannot exec into container '${container}'. Check Docker permissions or start it with: docker compose up -d" >&2
    exit 1
  fi
done

echo "==> Primary service status (inside ${PRIMARY_CONTAINER})"
CONTAINER="${PRIMARY_CONTAINER}"
check "named    running"          bash -c "pgrep -x named >/dev/null"
check "isc-dhcp present (config)" bash -c "[ -f /etc/dhcp/dhcpd.conf ]"
check "postfix  running"          bash -c "pgrep -x master >/dev/null"
check "nginx    running"          bash -c "pgrep -x nginx  >/dev/null"

echo
echo "==> Nginx serves managed page on port 80"
check "HTTP 200 on /"             bash -c "curl -sSf http://127.0.0.1/ | grep -q 'puppet-lab'"

echo
echo "==> Primary BIND9 authoritative answers"
check_in "${PRIMARY_CONTAINER}" "primary lab.local SOA"   bash -c "dig @127.0.0.1 lab.local SOA +short | grep -q 'ns1.lab.local.'"
check_in "${PRIMARY_CONTAINER}" "primary www.lab.local A" bash -c "dig @127.0.0.1 www.lab.local A +short | grep -qx '192.0.2.20'"
check_in "${PRIMARY_CONTAINER}" "primary lab.local MX"    bash -c "dig @127.0.0.1 lab.local MX +short | grep -qx '10 mail.lab.local.'"

echo
echo "==> Secondary BIND9 transfer and answers"
check_in "${SECONDARY_CONTAINER}" "secondary named running" bash -c "pgrep -x named >/dev/null"
check_retry_in "${SECONDARY_CONTAINER}" "secondary SOA synced" bash -c "dig @127.0.0.1 lab.local SOA +short | grep -q 'ns1.lab.local.'"
check_retry_in "${SECONDARY_CONTAINER}" "secondary www.lab.local A" bash -c "dig @127.0.0.1 www.lab.local A +short | grep -qx '192.0.2.20'"
check_in "${SECONDARY_CONTAINER}" "AXFR allowed from secondary" bash -c "dig @${PRIMARY_IP} lab.local AXFR +short | grep -qx '192.0.2.20'"

echo
echo "==> DNS transfer policy"
check_denied_axfr_in "${CLIENT_CONTAINER}" "AXFR denied from unauthorized client"

echo
if [ "${FAIL}" -ne 0 ]; then
  echo "smoke test FAILED" >&2
  exit 1
fi
echo "smoke test passed"
