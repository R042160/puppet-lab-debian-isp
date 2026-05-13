#!/usr/bin/env bash
# Minimal smoke test: managed services/config should be present and queryable.
# Usage:  ./scripts/smoke.sh
set -uo pipefail

PRIMARY_CONTAINER="${PRIMARY_CONTAINER:-puppet-lab}"
SECONDARY_CONTAINER="${SECONDARY_CONTAINER:-puppet-lab-secondary}"
CLIENT_CONTAINER="${CLIENT_CONTAINER:-puppet-lab-client}"
PRIMARY_IP="${PRIMARY_IP:-172.28.53.10}"
LAB_MAIL_USER="${LAB_MAIL_USER:-labuser@lab.local}"
LAB_MAIL_PASSWORD="${LAB_MAIL_PASSWORD:-labpass}"
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

check_smtp_auth_in() {
  local container="$1"; shift
  local label="$1"; shift
  local auth_token

  auth_token="$(printf '\0%s\0%s' "${LAB_MAIL_USER}" "${LAB_MAIL_PASSWORD}" | base64 -w0)"

  if docker exec \
    -e PRIMARY_IP="${PRIMARY_IP}" \
    -e SMTP_AUTH_TOKEN="${auth_token}" \
    "${container}" \
    timeout 5 bash -c '
      set -euo pipefail
      exec 3<>"/dev/tcp/${PRIMARY_IP}/587"
      IFS= read -r banner <&3
      printf "EHLO client.lab.local\r\n" >&3
      while IFS= read -r line <&3; do
        case "${line}" in
          250\ *) break ;;
        esac
      done
      printf "AUTH PLAIN %s\r\n" "${SMTP_AUTH_TOKEN}" >&3
      IFS= read -r auth_reply <&3
      printf "QUIT\r\n" >&3
      case "${auth_reply}" in
        235*) exit 0 ;;
        *) printf "%s\n" "${auth_reply}" >&2; exit 1 ;;
      esac
    ' >/dev/null 2>&1; then
    printf "  \033[32mOK\033[0m   %s\n" "${label}"
  else
    printf "  \033[31mFAIL\033[0m %s\n" "${label}"
    FAIL=1
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
check "dovecot  running"          bash -c "pgrep -x dovecot >/dev/null"
check "opendkim running"          bash -c "pgrep -x opendkim >/dev/null"
check "nginx    running"          bash -c "pgrep -x nginx  >/dev/null"

echo
echo "==> Nginx serves managed page on port 80"
check "HTTP 200 on /"             bash -c "curl -sSf http://127.0.0.1/ | grep -q 'puppet-lab'"

echo
echo "==> Mail submission and Dovecot SASL"
check_in "${PRIMARY_CONTAINER}" "submission 587 listens locally" bash -c "timeout 2 bash -c '</dev/tcp/127.0.0.1/587'"
check_in "${CLIENT_CONTAINER}" "client reaches submission 587" bash -c "timeout 2 bash -c '</dev/tcp/${PRIMARY_IP}/587'"
check_in "${PRIMARY_CONTAINER}" "dovecot auth socket for postfix" bash -c "[ -S /var/spool/postfix/private/auth ]"
check_in "${PRIMARY_CONTAINER}" "dovecot Maildir config active" bash -c "doveconf -n | grep -q '^mail_location = maildir:~/Maildir'"
check_in "${PRIMARY_CONTAINER}" "dovecot passwd-file auth works" bash -c "doveadm auth test '${LAB_MAIL_USER}' '${LAB_MAIL_PASSWORD}'"
check_smtp_auth_in "${CLIENT_CONTAINER}" "SMTP AUTH succeeds via submission"

echo
echo "==> OpenDKIM signing path and DNS records"
check_in "${PRIMARY_CONTAINER}" "opendkim milter listens on 8891" bash -c "timeout 2 bash -c '</dev/tcp/127.0.0.1/8891'"
check_in "${PRIMARY_CONTAINER}" "postfix uses opendkim milter" bash -c "postconf -h smtpd_milters | grep -qx 'inet:127.0.0.1:8891'"
check_in "${PRIMARY_CONTAINER}" "DKIM public key served by BIND" bash -c "dig @127.0.0.1 default._domainkey.lab.local TXT +short | grep -q 'v=DKIM1'"
check_in "${PRIMARY_CONTAINER}" "SPF record served by BIND" bash -c "dig @127.0.0.1 lab.local TXT +short | grep -q 'v=spf1 mx -all'"
check_in "${PRIMARY_CONTAINER}" "DMARC record served by BIND" bash -c "dig @127.0.0.1 _dmarc.lab.local TXT +short | grep -q 'v=DMARC1; p=none'"

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
