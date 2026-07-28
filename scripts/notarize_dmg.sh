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

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found at $DMG_PATH"
  exit 1
fi

if ! xcrun --find notarytool >/dev/null 2>&1; then
  echo "xcrun notarytool is required for notarization."
  exit 1
fi

if ! xcrun --find stapler >/dev/null 2>&1; then
  echo "xcrun stapler is required to staple the notarization ticket."
  exit 1
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
else
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "Set NOTARY_PROFILE or provide notarization environment variables: APPLE_ID APPLE_TEAM_ID APPLE_APP_PASSWORD"
    exit 1
  fi

  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
fi

xcrun stapler staple "$DMG_PATH"

dmg_directory="$(dirname "$DMG_PATH")"
dmg_name="$(basename "$DMG_PATH")"
(
  cd "$dmg_directory"
  shasum -a 256 "$dmg_name"
) > "$DMG_PATH.sha256"

checksum_path="$DMG_PATH.sha256"
DMG_PATH="$DMG_PATH" CHECKSUM_PATH="$checksum_path" ./scripts/verify_release_dmg.sh

echo "DMG notarization complete: $DMG_PATH"
