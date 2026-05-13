#!/usr/bin/env bash
# Runs the rspec-puppet unit tests from the repository root.
# Usage: ./scripts/spec.sh
set -euo pipefail

if ! command -v bundle >/dev/null 2>&1; then
  echo "Bundler not found. Install once with: gem install bundler" >&2
  exit 1
fi

bundle exec rspec

