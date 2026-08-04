#!/usr/bin/env bash
set -e

# Detect available CPU cores for maximum parallel test execution
CORES=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
echo "🚀 Running test suite with ${CORES} parallel workers..."

echo "==> Running Flutter app tests..."
flutter test --concurrency="${CORES}" --reporter=compact "$@"

echo "==> Running packages/engine tests..."
(cd packages/engine && dart test --concurrency="${CORES}" "$@")

echo "==> Running packages/mcp tests..."
(cd packages/mcp && dart test --concurrency="${CORES}" "$@")

echo "✅ All test suites passed!"
