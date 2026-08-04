#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

format_pkg() {
  local dir="$1"
  (
    cd "$dir"
    dart run coverage:format_coverage \
      --lcov --in=coverage --out=coverage/lcov.info \
      --package=. --report-on=lib --check-ignore
  )
}

echo "==> Formatting package coverage"
format_pkg packages/engine
format_pkg packages/mcp

test -f coverage/lcov.info

# Wave-1 baseline floors; ratchet toward 99/99/99/60 in later PRs.
export ENGINE_MIN="${ENGINE_MIN:-99}"
export MCP_MIN="${MCP_MIN:-99}"
export APP_LOGIC_MIN="${APP_LOGIC_MIN:-99}"
export UI_MIN="${UI_MIN:-60}"

echo "==> Coverage buckets"
python3 tool/coverage_report.py --check
