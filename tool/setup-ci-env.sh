#!/usr/bin/env bash
# Creates a placeholder .env for CI builds and tests. The real .env is gitignored
# and must not contain secrets in the repository.
set -euo pipefail

if [[ -f .env ]]; then
  echo ".env already present; leaving unchanged."
else
  cp .env.example .env
  echo "Created .env from .env.example"
fi
