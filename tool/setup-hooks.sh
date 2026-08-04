#!/usr/bin/env bash
# One-time setup: point git at the repo-tracked hooks in .githooks/.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/* tool/*.sh

echo "✓ git hooksPath set to .githooks"
