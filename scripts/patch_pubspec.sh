#!/usr/bin/env bash
# patch_pubspec.sh
# Rewrites shell_app/pubspec.yaml and each module's pubspec.yaml so that
# inter-module path: dependencies point at the Jenkins cache directories
# (loaded from /tmp/module_paths.env written by resolve_modules.sh).
set -euo pipefail

PATHS_FILE="/tmp/module_paths.env"
SHELL_PUBSPEC="${WORKSPACE:-$(pwd)}/shell_app/pubspec.yaml"
MODULES_DIR="${WORKSPACE:-$(pwd)}/modules"

if [[ ! -f "$PATHS_FILE" ]]; then
  echo "[patch_pubspec] ERROR: ${PATHS_FILE} not found. Run resolve_modules.sh first." >&2
  exit 1
fi

# Load paths into associative array
declare -A MODULE_PATHS
while IFS='=' read -r key val; do
  [[ -z "$key" ]] && continue
  MODULE_PATHS["$key"]="$val"
done < "$PATHS_FILE"

# ---- helper: replace a path: dependency in a pubspec.yaml ----
patch_pubspec_file() {
  local pubspec="$1"
  local module_name="$2"
  local new_path="$3"
  local path_key="${module_name}_PATH"

  if [[ -z "$new_path" ]]; then
    echo "[patch_pubspec]   Skipping ${module_name} (not in cache paths)"
    return
  fi

  python3 - "$pubspec" "$module_name" "$new_path" << 'PY'
import sys, re

pubspec_file, module_name, new_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(pubspec_file) as f:
    content = f.read()

# Replace the path: line that follows "module_name:" in a dependency block
pattern = re.compile(
    r'(?P<indent>[ \t]*)(?P<name>' + re.escape(module_name) + r'):[ \t]*\n'
    r'(?P<path_indent>[ \t]+)path:[ \t]*[^\n]+',
    re.MULTILINE,
)
replacement = (
    r'\g<indent>\g<name>:\n'
    r'\g<path_indent>path: ' + new_path
)
new_content, n = pattern.subn(replacement, content)
if n == 0:
    print(f"  [patch_pubspec] WARNING: no path: entry found for {module_name} in {pubspec_file}")
else:
    with open(pubspec_file, 'w') as f:
        f.write(new_content)
    print(f"  [patch_pubspec] Patched {module_name} -> {new_path} in {pubspec_file}")
PY
}

echo "[patch_pubspec] Patching shell_app/pubspec.yaml ..."
for key in "${!MODULE_PATHS[@]}"; do
  module="${key%_PATH}"
  patch_pubspec_file "$SHELL_PUBSPEC" "$module" "${MODULE_PATHS[$key]}"
done

if [[ -d "$MODULES_DIR" ]]; then
  echo "[patch_pubspec] Patching module inter-dependencies ..."
  for mod_dir in "${MODULES_DIR}"/*/; do
    mod_pubspec="${mod_dir}pubspec.yaml"
    [[ ! -f "$mod_pubspec" ]] && continue
    for key in "${!MODULE_PATHS[@]}"; do
      module="${key%_PATH}"
      patch_pubspec_file "$mod_pubspec" "$module" "${MODULE_PATHS[$key]}"
    done
  done
fi

echo "[patch_pubspec] Done."
