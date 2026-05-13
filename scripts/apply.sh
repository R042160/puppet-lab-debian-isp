#!/usr/bin/env bash
# Runs puppet apply inside the lab container.
# Usage:  ./scripts/apply.sh
set -euo pipefail

CONTAINER="${CONTAINER:-puppet-lab}"

if ! docker ps >/dev/null 2>&1; then
  echo "Cannot access Docker daemon. Check Docker permissions or run with a user that can use docker." >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Container '${CONTAINER}' not running. Start it with: docker compose up -d" >&2
  exit 1
fi

echo "==> puppet --version"
docker exec "${CONTAINER}" puppet --version

run_puppet_apply() {
  local label="$1"
  local expect_idempotent="${2:-0}"
  local rc

  echo "==> puppet apply (${label})"
  set +e
  docker exec "${CONTAINER}" puppet apply \
    --detailed-exitcodes \
    --hiera_config=/lab/hiera.yaml \
    --modulepath=/lab/modules \
    /lab/manifests/site.pp
  rc=$?
  set -e

  case "${rc}" in
    0)
      echo "puppet apply result: no changes"
      ;;
    2)
      if [ "${expect_idempotent}" = "1" ]; then
        echo "puppet apply result: changes on idempotency run" >&2
        exit 2
      fi
      echo "puppet apply result: changes applied"
      ;;
    *)
      echo "puppet apply failed with exit code ${rc}" >&2
      exit "${rc}"
      ;;
  esac
}

run_puppet_apply "run 1: should converge"

echo
run_puppet_apply "run 2: idempotency check" 1
