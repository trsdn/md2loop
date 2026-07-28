#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DMG_PATH="${DMG_PATH:-dist/md2loop-macos.dmg}"
APP_NAME="${APP_NAME:-md2loop}"
CHECKSUM_PATH="${CHECKSUM_PATH:-$DMG_PATH.sha256}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found at $DMG_PATH"
  exit 1
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
  echo "Checksum not found at $CHECKSUM_PATH"
  exit 1
fi

dmg_name="$(basename "$DMG_PATH")"
checksum_name="$(basename "$CHECKSUM_PATH")"
checksum_line_count="$(wc -l < "$CHECKSUM_PATH" | tr -d ' ')"
read -r checksum_digest checksum_asset checksum_extra < "$CHECKSUM_PATH"

if [[ "$checksum_line_count" != "1"
      || ! "$checksum_digest" =~ ^[[:xdigit:]]{64}$
      || "$checksum_asset" != "$dmg_name"
      || "$checksum_asset" != "$(basename "$checksum_asset")"
      || -n "${checksum_extra:-}" ]]; then
  echo "Checksum must contain one SHA-256 digest and the DMG basename only."
  exit 1
fi

verification_directory="$(mktemp -d /tmp/md2loop-checksum.XXXXXX)"
mount_directory="$(mktemp -d /tmp/md2loop-mount.XXXXXX)"
mounted_device=""

cleanup() {
  status=$?
  set +e
  if [[ -n "$mounted_device" ]]; then
    hdiutil detach "$mounted_device" >/dev/null 2>&1
  fi
  rm -rf "$verification_directory" "$mount_directory"
  exit "$status"
}
trap cleanup EXIT

cp "$DMG_PATH" "$verification_directory/$dmg_name"
cp "$CHECKSUM_PATH" "$verification_directory/$checksum_name"
(
  cd "$verification_directory"
  shasum -a 256 -c "$checksum_name"
)

hdiutil verify "$DMG_PATH"
codesign --verify --strict --verbose=2 "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

attach_output="$(
  hdiutil attach \
    -readonly \
    -nobrowse \
    -mountpoint "$mount_directory" \
    "$DMG_PATH"
)"
printf '%s\n' "$attach_output"
mounted_device="$(printf '%s\n' "$attach_output" | awk '/^\/dev\// { print $1; exit }')"

if [[ -z "$mounted_device" ]]; then
  echo "Could not determine the mounted DMG device."
  exit 1
fi

mounted_app="$mount_directory/$APP_NAME.app"
if [[ ! -d "$mounted_app" ]]; then
  echo "Mounted app bundle not found at $mounted_app"
  exit 1
fi

xcrun stapler validate "$mounted_app"
codesign --verify --deep --strict --verbose=2 "$mounted_app"
spctl --assess --type execute --verbose=4 "$mounted_app"

hdiutil detach "$mounted_device"
mounted_device=""

echo "Validated notarized DMG and mounted app: $DMG_PATH"
