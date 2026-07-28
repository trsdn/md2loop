#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${RELEASE_ENV_FILE:-.release.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

DMG_PATH="${DMG_PATH:-dist/md2loop-macos.dmg}"

./scripts/build_release.sh
APP_PATH="${APP_PATH:-dist/md2loop.app}" ./scripts/notarize_app.sh
DMG_PATH="$DMG_PATH" ./scripts/make_dmg.sh
DMG_PATH="$DMG_PATH" ./scripts/notarize_dmg.sh

echo "Release artifacts are in dist/."
