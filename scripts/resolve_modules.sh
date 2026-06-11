#!/usr/bin/env bash
# resolve_modules.sh
# Reads module_registry.yaml, checks the Jenkins module cache, and clones /
# updates only the modules whose remote ref has changed.
# Outputs: /tmp/module_paths.env  — KEY=VALUE pairs of cache paths for every module.
set -euo pipefail

# Configure a temporary git credential store when Jenkins injects GIT_USERNAME / GIT_PASSWORD.
# The file is removed on script exit so credentials are never left on disk.
if [[ -n "${GIT_USERNAME:-}" && -n "${GIT_PASSWORD:-}" ]]; then
  _CREDS_FILE=$(mktemp)
  chmod 600 "$_CREDS_FILE"
  echo "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com" > "$_CREDS_FILE"
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="credential.helper"
  export GIT_CONFIG_VALUE_0="store --file=${_CREDS_FILE}"
  trap 'rm -f "$_CREDS_FILE"' EXIT
fi

# MODULE_REGISTRY can be overridden by the caller (e.g. Jenkinsfile sets it to
# ${WORKSPACE}/ci/module_registry.yaml when ci/ is a subdirectory of the project).
# When this repo is used standalone, it defaults to module_registry.yaml at the workspace root.
REGISTRY="${MODULE_REGISTRY:-${WORKSPACE:-$(pwd)}/module_registry.yaml}"
CACHE_DIR="${MODULE_CACHE_DIR:-/var/jenkins_home/module_cache}"
PATHS_FILE="/tmp/module_paths.env"
> "$PATHS_FILE"   # truncate

if ! command -v python3 &>/dev/null; then
  echo "[resolve_modules] ERROR: python3 is required to parse YAML" >&2
  exit 1
fi

# ---------- helper: parse a scalar from YAML with python3 ----------
yaml_get() {
  local file="$1" key_path="$2"
  python3 - "$file" "$key_path" << 'PY'
import sys, re
file, key_path = sys.argv[1], sys.argv[2].split(".")
with open(file) as f:
    lines = f.readlines()
# Minimal key-path descent for simple nested YAML (no arrays)
indent = 0
found_keys = 0
for line in lines:
    stripped = line.lstrip()
    current_indent = len(line) - len(stripped)
    if not stripped or stripped.startswith("#"):
        continue
    k, _, v = stripped.partition(":")
    k = k.strip(); v = v.strip().strip('"').strip("'")
    if k == key_path[found_keys]:
        found_keys += 1
        if found_keys == len(key_path):
            print(v)
            sys.exit(0)
sys.exit(1)
PY
}

# ---------- list all module names ----------
module_names() {
  python3 - "$REGISTRY" << 'PY'
import sys
file = sys.argv[1]
in_modules = False
with open(file) as f:
    for line in f:
        s = line.lstrip()
        if s.startswith("modules:"):
            in_modules = True
            continue
        if in_modules:
            if line and not line[0].isspace():
                break   # left modules block
            m = s.rstrip()
            if m.endswith(":") and not m.startswith("#"):
                print(m[:-1].strip())
PY
}

mkdir -p "$CACHE_DIR"

while IFS= read -r MODULE; do
  [[ -z "$MODULE" ]] && continue

  GIT_URL=$(yaml_get "$REGISTRY" "modules.${MODULE}.git_url")
  REF=$(yaml_get      "$REGISTRY" "modules.${MODULE}.ref")
  MODULE_DIR="${CACHE_DIR}/${MODULE}"
  HASH_FILE="${MODULE_DIR}/.resolved_hash"

  echo "[resolve_modules] Processing module: ${MODULE} (ref=${REF})"

  # ---- resolve the remote commit hash for the requested ref ----
  REMOTE_HASH=$(git ls-remote "$GIT_URL" "$REF" 2>/dev/null | awk '{print $1}' | head -1)
  if [[ -z "$REMOTE_HASH" ]]; then
    echo "[resolve_modules] WARNING: could not reach ${GIT_URL}. Using cache if available."
    REMOTE_HASH="UNREACHABLE"
  fi

  CACHED_HASH=""
  [[ -f "$HASH_FILE" ]] && CACHED_HASH=$(cat "$HASH_FILE")

  if [[ "$REMOTE_HASH" != "UNREACHABLE" && "$REMOTE_HASH" == "$CACHED_HASH" && -d "${MODULE_DIR}/lib" ]]; then
    echo "[resolve_modules]   Cache HIT  for ${MODULE} (${REMOTE_HASH:0:8})"
  else
    echo "[resolve_modules]   Cache MISS for ${MODULE} — fetching..."
    if [[ -d "${MODULE_DIR}/.git" ]]; then
      git -C "$MODULE_DIR" fetch --depth=1 origin "$REF" 2>&1 | sed "s/^/  [git] /"
      git -C "$MODULE_DIR" checkout FETCH_HEAD 2>&1 | sed "s/^/  [git] /"
    else
      rm -rf "$MODULE_DIR"
      git clone --depth=1 --branch "$REF" "$GIT_URL" "$MODULE_DIR" 2>&1 | sed "s/^/  [git] /"
    fi
    [[ "$REMOTE_HASH" != "UNREACHABLE" ]] && echo "$REMOTE_HASH" > "$HASH_FILE"
    echo "[resolve_modules]   Cached ${MODULE} at ${MODULE_DIR}"
  fi

  # Write path for downstream scripts
  echo "${MODULE}_PATH=${MODULE_DIR}" >> "$PATHS_FILE"
done < <(module_names)

echo "[resolve_modules] Done. Paths written to ${PATHS_FILE}"
cat "$PATHS_FILE"
