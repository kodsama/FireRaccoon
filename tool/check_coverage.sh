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
format_pkg packages/app_backend

test -f coverage/lcov.info

# Wave-1 baseline floors; ratchet toward 99/99/99/60 in later PRs.
# BACKEND_MIN starts at what the HTTP surface actually covers today rather than
# at the aspiration: app_server.dart sat in no bucket at all, which is how an
# untested auth gate let an agent key reach the Firefly token. A floor the code
# cannot meet would block every commit and teach people to bypass the gate.
export ENGINE_MIN="${ENGINE_MIN:-99}"
export MCP_MIN="${MCP_MIN:-99}"
export APP_LOGIC_MIN="${APP_LOGIC_MIN:-99}"
export BACKEND_MIN="${BACKEND_MIN:-70}"
export UI_MIN="${UI_MIN:-60}"

echo "==> Coverage buckets"
python3 tool/coverage_report.py --check
