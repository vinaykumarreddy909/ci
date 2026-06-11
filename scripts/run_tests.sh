#!/usr/bin/env bash
# run_tests.sh — runs flutter test for shell app and all modules.
set -euo pipefail
ROOT="${WORKSPACE:-$(pwd)}"
FAILED=0

run_tests() {
  local dir="$1"
  if [[ ! -d "${dir}/test" ]]; then
    echo "[test] SKIP: ${dir} (no test/ directory found)"
    return
  fi
  echo "------------------------------------------------------------"
  echo "[test] Testing: ${dir}"
  echo "------------------------------------------------------------"
  cd "$dir"
  flutter pub get --no-example
  if flutter test --no-pub; then
    echo "[test] PASS: ${dir}"
  else
    echo "[test] FAIL: ${dir}"
    FAILED=1
  fi
  cd "$ROOT"
}

# modules/ is only present when running from the full project checkout.
# Skip gracefully when ci/ is used as a standalone repo.
if [[ -d "${ROOT}/modules" ]]; then
  for mod in "$ROOT"/modules/*/; do
    [[ -f "${mod}pubspec.yaml" ]] && run_tests "$mod"
  done
fi

run_tests "$ROOT/shell_app"

[[ $FAILED -eq 0 ]] || { echo "[test] One or more test suites failed."; exit 1; }
echo "[test] All suites passed."
