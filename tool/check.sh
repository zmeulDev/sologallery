#!/usr/bin/env bash
#
# Pre-flight checks for every task (see CLAUDE.md "Definition of Done").
# Runs analyze -> codegen -> host tests. On-device integration tests and
# manual device verification are separate steps.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter analyze"
flutter analyze

echo "==> build_runner (drift codegen)"
# Note: newer build_runner made --delete-conflicting-outputs the default and
# removed the flag, so it's intentionally omitted here.
dart run build_runner build

echo "==> flutter test (unit + widget)"
flutter test

echo "All checks passed."
