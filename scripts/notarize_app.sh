#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${RELEASE_ENV_FILE:-.release.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

APP_PATH="${APP_PATH:-dist/md2loop.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH"
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

notary_arguments=()
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  notary_arguments=(--keychain-profile "$NOTARY_PROFILE")
else
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "Set NOTARY_PROFILE or provide notarization environment variables: APPLE_ID APPLE_TEAM_ID APPLE_APP_PASSWORD"
    exit 1
  fi

  notary_arguments=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$APPLE_APP_PASSWORD"
  )
fi

temporary_directory="$(mktemp -d /tmp/md2loop-app-notary.XXXXXX)"
archive_path="$temporary_directory/md2loop.app.zip"
cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null \
  | grep -A1 '<key>com.apple.security.get-task-allow</key>' \
  | grep -q '<true/>'; then
  echo "Refusing to notarize an app with com.apple.security.get-task-allow enabled."
  exit 1
fi
ditto -c -k --keepParent "$APP_PATH" "$archive_path"
xcrun notarytool submit "$archive_path" "${notary_arguments[@]}" --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

echo "App notarization complete: $APP_PATH"
