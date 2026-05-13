#!/usr/bin/env bash
# Runs puppet apply inside the lab container.
# Usage:  ./scripts/apply.sh
set -euo pipefail

CONTAINER="${CONTAINER:-puppet-lab}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Container '${CONTAINER}' not running. Start it with: docker compose up -d" >&2
  exit 1
fi

echo "==> puppet --version"
docker exec "${CONTAINER}" puppet --version

echo "==> puppet apply (run 1: should converge)"
docker exec "${CONTAINER}" puppet apply \
  --hiera_config=/lab/hiera.yaml \
  --modulepath=/lab/modules \
  /lab/manifests/site.pp

echo
echo "==> puppet apply (run 2: should report 0 events – idempotency check)"
docker exec "${CONTAINER}" puppet apply \
  --hiera_config=/lab/hiera.yaml \
  --modulepath=/lab/modules \
  /lab/manifests/site.pp
