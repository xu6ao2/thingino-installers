#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <tag> <notes-file> [artifact ...]" >&2
  exit 1
}

[ $# -lt 2 ] && usage
[ -z "${GITHUB_TOKEN:-}" ] && { echo "GITHUB_TOKEN is required" >&2; exit 1; }
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO=${GITHUB_REPOSITORY:-wltechblog/thingino-installers}
TAG_NAME=$1
shift
NOTES_FILE=$1
shift
[ -f "$NOTES_FILE" ] || { [ -f "$ROOT/$NOTES_FILE" ] && NOTES_FILE="$ROOT/$NOTES_FILE"; }
[ -f "$NOTES_FILE" ] || { echo "Release notes file not found: $NOTES_FILE" >&2; exit 1; }
NAME=${RELEASE_NAME:-$TAG_NAME}
DRAFT=${RELEASE_DRAFT:-false}
PRERELEASE=${RELEASE_PRERELEASE:-false}
PAYLOAD=$(TAG_NAME="$TAG_NAME" RELEASE_NAME_VALUE="$NAME" NOTES_FILE_PATH="$NOTES_FILE" DRAFT_FLAG="$DRAFT" PRERELEASE_FLAG="$PRERELEASE" python3 - <<'PY'
import json, os
path = os.environ["NOTES_FILE_PATH"]
with open(path, "r", encoding="utf-8") as handle:
    body = handle.read()
payload = {
    "tag_name": os.environ["TAG_NAME"],
    "name": os.environ["RELEASE_NAME_VALUE"],
    "body": body,
    "draft": os.environ["DRAFT_FLAG"].lower() == "true",
    "prerelease": os.environ["PRERELEASE_FLAG"].lower() == "true"
}
print(json.dumps(payload))
PY
)
CREATE_RESPONSE=$(curl -sS --fail -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d "$PAYLOAD" \
  "https://api.github.com/repos/${REPO}/releases")
read -r RELEASE_ID UPLOAD_URL <<EOF
$(printf '%s' "$CREATE_RESPONSE" | python3 - <<'PY'
import json, sys
content = json.load(sys.stdin)
print(content["id"])
print(content["upload_url"].split("{")[0])
PY
)
EOF
[ -n "$RELEASE_ID" ] || { echo "Failed to create release" >&2; exit 1; }
artifacts=("$@")
if [ ${#artifacts[@]} -eq 0 ]; then
  while IFS= read -r -d '' file; do
    case "$file" in
      "$ROOT/.git"*|"$ROOT/assets"*|"$ROOT/tmp"*|"$ROOT/mnt"*) continue ;;
    esac
    artifacts+=("$file")
  done < <(find "$ROOT" -maxdepth 2 -type f -name '*.zip' -print0)
fi
[ ${#artifacts[@]} -gt 0 ] || { echo "No artifacts found" >&2; exit 1; }
for artifact in "${artifacts[@]}"; do
  if [ ! -f "$artifact" ]; then
    if [ -f "$ROOT/$artifact" ]; then
      artifact="$ROOT/$artifact"
    else
      echo "Missing artifact: $artifact" >&2
      exit 1
    fi
  fi
  filename=$(basename "$artifact")
  echo "Uploading $filename"
  curl -sS --fail -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Content-Type: application/octet-stream" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --data-binary @"$artifact" \
    "${UPLOAD_URL}?name=${filename}" >/dev/null
done
