#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${RELEASE_ENV_FILE:-.release.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

APP_NAME="md2loop"
SCHEME="md2loop"
PROJECT="md2loop.xcodeproj"
BUILD_ROOT="${BUILD_ROOT:-release-build}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
DIST_DIR="${DIST_DIR:-dist}"
DIST_APP="$DIST_DIR/$APP_NAME.app"
RELEASE_VERSION="${RELEASE_VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
REQUIRE_SIGNING="${REQUIRE_SIGNING:-1}"

if [[ -z "$RELEASE_VERSION" ]]; then
  RELEASE_VERSION="$(grep -E 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\([^"]*\)".*/\1/')"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="${GITHUB_RUN_NUMBER:-$(date +%Y%m%d%H%M)}"
fi

find_signing_identity() {
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$CODESIGN_IDENTITY"
    return 0
  fi

  security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' \
    | head -1 \
    | sed 's/.*"\(.*\)"/\1/'
}

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
elif [[ ! -d "$PROJECT" ]]; then
  echo "xcodegen is required because $PROJECT does not exist."
  exit 1
fi

swift test

SIGNING_IDENTITY=""
if [[ "$REQUIRE_SIGNING" == "1" ]]; then
  SIGNING_IDENTITY="$(find_signing_identity || true)"
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "No Developer ID Application signing identity found."
    echo "Set CODESIGN_IDENTITY or use REQUIRE_SIGNING=0 for a local unsigned smoke build."
    exit 1
  fi
else
  SIGNING_IDENTITY="$(find_signing_identity || true)"
fi

rm -rf "$BUILD_ROOT" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -resolvePackageDependencies

build_settings=(
  MARKETING_VERSION="$RELEASE_VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
  ENABLE_HARDENED_RUNTIME=YES
)

if [[ -n "$SIGNING_IDENTITY" ]]; then
  build_settings+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
    OTHER_CODE_SIGN_FLAGS="--timestamp"
  )
  if [[ -n "${TEAM_ID:-}" ]]; then
    build_settings+=(DEVELOPMENT_TEAM="$TEAM_ID")
  fi
else
  build_settings+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  clean build \
  "${build_settings[@]}"

BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "Build succeeded, but app bundle was not found at $BUILT_APP"
  exit 1
fi

ditto "$BUILT_APP" "$DIST_APP"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --verify --strict --deep --verbose=2 "$DIST_APP"
  codesign -dv --verbose=4 "$DIST_APP" 2>&1 | grep -E 'Authority=|TeamIdentifier=|Runtime|Timestamp' || true
fi

echo "App bundle created: $DIST_APP"
