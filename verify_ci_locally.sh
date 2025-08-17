#!/usr/bin/env bash
set -Eeuo pipefail

echo "== Dart =="
dart --version

echo "== Pub get =="
dart pub get

echo "== Analyze =="
dart analyze --fatal-infos --fatal-warnings

echo "== Tests =="
mkdir -p reports
dart test -r expanded --file-reporter=json:reports/test_report.json

echo "== Activate CLI =="
dart pub global activate --source path .
export PATH="$PATH:$HOME/.pub-cache/bin"
which flutter_keycheck

echo "== Contract: scans + policies =="
FKC_CACHE_TTL_HOURS=0 flutter_keycheck scan --scope=workspace-only --fail-on-package-missing --fail-on-collision
FKC_CACHE_TTL_HOURS=0 flutter_keycheck scan --scope=deps-only      --fail-on-package-missing --fail-on-collision
FKC_CACHE_TTL_HOURS=0 flutter_keycheck scan --scope=all            --fail-on-package-missing --fail-on-collision

echo "== Contract: missing config -> exit 2 =="
set +e
flutter_keycheck scan --scope=workspace-only --config ./DOES_NOT_EXIST.json
ec=$?
echo "exit=$ec"
if [ "$ec" -ne 2 ]; then
  echo "Expected exit 2 for missing config, got $ec"
  exit 1
fi
set -e

echo "== Demo app smoke =="
pushd example/demo_app >/dev/null
dart pub get
flutter_keycheck scan --scope=workspace-only
popd >/dev/null

echo "== OK =="