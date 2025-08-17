#!/bin/bash
set -Eeuo pipefail
trap 'echo "::error:: failed: $BASH_COMMAND (exit $?)"' ERR

echo "COMMIT=$(git rev-parse --short HEAD)"
echo "DART=$(dart --version 2>&1)"

echo "=== 1) Анализ ==="
dart analyze --fatal-infos --fatal-warnings

echo "=== 2) Тесты (v3 + golden) ==="
dart test test/v3 -r expanded
dart test test/golden_workspace -r expanded

echo "=== 3) JSON-схема вывода scan ==="
out=$(dart run bin/flutter_keycheck.dart scan --scope workspace-only)
echo "$out" | jq -e '.schemaVersion=="\"1.0\"" or .schemaVersion=="1.0"' >/dev/null || exit 2
echo "$out" | jq -e '.timestamp and (.keys | type=="array")' >/dev/null || exit 2

echo "=== SUCCESS: Все проверки пройдены ==="