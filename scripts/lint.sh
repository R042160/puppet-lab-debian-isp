#!/usr/bin/env bash
# Runs static validation for the Puppet lab.
# Usage: ./scripts/lint.sh
set -euo pipefail

if ! command -v bundle >/dev/null 2>&1; then
  echo "Bundler not found. Install once with: gem install bundler" >&2
  exit 1
fi

mapfile -t manifests < <(find manifests modules -name '*.pp' -type f | sort)
mapfile -t templates < <(find modules -path '*/templates/*.epp' -type f | sort)
mapfile -t metadata < <(find modules -name metadata.json -type f | sort)
mapfile -t yaml_files < <(find data -name '*.yaml' -type f | sort)

yaml_files=(hiera.yaml "${yaml_files[@]}")

echo "==> bash syntax"
bash -n scripts/apply.sh scripts/lint.sh scripts/smoke.sh scripts/spec.sh

echo "==> YAML syntax"
ruby -ryaml -e 'ARGV.each { |path| YAML.load_file(path); puts "  OK #{path}" }' "${yaml_files[@]}"

echo "==> Puppet parser"
bundle exec puppet parser validate "${manifests[@]}"

echo "==> EPP templates"
bundle exec puppet epp validate "${templates[@]}"

echo "==> puppet-lint"
bundle exec puppet-lint "${manifests[@]}"

echo "==> metadata-json-lint"
bundle exec metadata-json-lint "${metadata[@]}"

echo "lint passed"
