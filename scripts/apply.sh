#!/usr/bin/env bash
# Runs puppet apply inside the lab containers.
# Usage:  ./scripts/apply.sh
set -euo pipefail

TARGETS="${TARGETS:-puppet-lab:puppet-lab.local puppet-lab-secondary:secondary.lab.local}"

if ! docker ps >/dev/null 2>&1; then
  echo "Cannot access Docker daemon. Check Docker permissions or run with a user that can use docker." >&2
  exit 1
fi

run_puppet_apply() {
  local container="$1"
  local certname="$2"
  local label="$3"
  local expect_idempotent="${4:-0}"
  local rc

  echo "==> ${container}: puppet apply (${label})"
  set +e
  docker exec "${container}" puppet apply \
    --detailed-exitcodes \
    --certname="${certname}" \
    --hiera_config=/lab/hiera.yaml \
    --modulepath=/lab/modules \
    /lab/manifests/site.pp
  rc=$?
  set -e

  case "${rc}" in
    0)
      echo "${container}: puppet apply result: no changes"
      ;;
    2)
      if [ "${expect_idempotent}" = "1" ]; then
        echo "${container}: puppet apply result: changes on idempotency run" >&2
        exit 2
      fi
      echo "${container}: puppet apply result: changes applied"
      ;;
    *)
      echo "${container}: puppet apply failed with exit code ${rc}" >&2
      exit "${rc}"
      ;;
  esac
}

for target in ${TARGETS}; do
  container="${target%%:*}"
  certname="${target#*:}"

  if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    echo "Container '${container}' not running. Start it with: docker compose up -d" >&2
    exit 1
  fi

  echo "==> ${container}: puppet --version"
  docker exec "${container}" puppet --version

  run_puppet_apply "${container}" "${certname}" "run 1: should converge"

  echo
  run_puppet_apply "${container}" "${certname}" "run 2: idempotency check" 1

  echo
done
