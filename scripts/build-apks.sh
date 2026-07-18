#!/usr/bin/env bash
#
# build-apks.sh — build the Homely customer + seller (kitchen) Android APKs
# and drop them into shareable-apks/ with friendly, shareable names.
#
#   customer_app  ->  shareable-apks/homely-customer.apk
#   kitchen_app   ->  shareable-apks/homely-seller.apk
#
# Usage:
#   scripts/build-apks.sh                  # build both (release)
#   scripts/build-apks.sh customer         # only the customer app
#   scripts/build-apks.sh seller           # only the seller/kitchen app
#   scripts/build-apks.sh kitchen          # alias for seller
#   scripts/build-apks.sh both             # explicit "both"
#
# Flags:
#   --api-url <url>  backend base URL baked into the APK (default:
#                    http://10.0.2.2:3000/api — emulator-only). Use your
#                    machine's LAN IP or deployed URL for real devices,
#                    e.g. --api-url https://api.homely.app/api
#                    Can also be set via the API_BASE_URL env var.
#   --debug          build the debug variant instead of release
#   --no-clean       skip `flutter clean` (faster, reuses build cache)
#   -h, --help       show this help
#
set -euo pipefail

# --- Resolve repo root (this script lives in <root>/scripts) -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$ROOT_DIR/shareable-apks"

# --- Defaults ----------------------------------------------------------------
TARGET="both"
BUILD_MODE="release"   # release | debug
DO_CLEAN=1
# Base URL baked into the APK. Falls back to the API_BASE_URL env var if set;
# empty means "don't pass --dart-define" so the app's own default applies.
API_URL="${API_BASE_URL:-}"

usage() {
  sed -n '3,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- Parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    customer)            TARGET="customer" ;;
    seller|kitchen)      TARGET="seller" ;;
    both)                TARGET="both" ;;
    --debug)             BUILD_MODE="debug" ;;
    --no-clean)          DO_CLEAN=0 ;;
    --api-url)
      shift
      [[ $# -gt 0 ]] || { echo "error: --api-url requires a URL argument" >&2; exit 1; }
      API_URL="$1"
      ;;
    --api-url=*)         API_URL="${1#*=}" ;;
    -h|--help)           usage 0 ;;
    *) echo "error: unknown argument '$1'" >&2; usage 1 ;;
  esac
  shift
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter is not on PATH." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# --- Build one app -----------------------------------------------------------
# args: <app-dir-name> <output-apk-name> <friendly-label>
build_one() {
  local app_dir_name="$1" out_name="$2" label="$3"
  local app_dir="$ROOT_DIR/apps/$app_dir_name"

  echo ""
  echo "==> Building $label ($app_dir_name, $BUILD_MODE)"

  if [[ ! -d "$app_dir" ]]; then
    echo "error: app directory not found: $app_dir" >&2
    exit 1
  fi

  pushd "$app_dir" >/dev/null

  flutter pub get
  if [[ "$DO_CLEAN" -eq 1 ]]; then
    flutter clean
    flutter pub get
  fi

  local -a build_args=(build apk --"$BUILD_MODE")
  if [[ -n "$API_URL" ]]; then
    build_args+=(--dart-define=API_BASE_URL="$API_URL")
  fi
  flutter "${build_args[@]}"

  # Flutter writes to build/app/outputs/flutter-apk/app-<mode>.apk
  local built_apk="build/app/outputs/flutter-apk/app-$BUILD_MODE.apk"
  if [[ ! -f "$built_apk" ]]; then
    echo "error: expected APK not found at $app_dir/$built_apk" >&2
    exit 1
  fi

  cp "$built_apk" "$OUT_DIR/$out_name"
  popd >/dev/null

  local size
  size="$(du -h "$OUT_DIR/$out_name" | cut -f1)"
  echo "==> $label done -> shareable-apks/$out_name ($size)"
}

# --- Run ---------------------------------------------------------------------
echo "Repo root: $ROOT_DIR"
echo "Output:    $OUT_DIR"
echo "Mode:      $BUILD_MODE | clean: $([[ $DO_CLEAN -eq 1 ]] && echo yes || echo no) | target: $TARGET"
echo "API URL:   ${API_URL:-<app default: http://10.0.2.2:3000/api>}"

if [[ "$TARGET" == "customer" || "$TARGET" == "both" ]]; then
  build_one "customer_app" "homely-customer.apk" "Customer app"
fi
if [[ "$TARGET" == "seller" || "$TARGET" == "both" ]]; then
  build_one "kitchen_app" "homely-seller.apk" "Seller (kitchen) app"
fi

echo ""
echo "All done. APKs in: $OUT_DIR"
ls -lh "$OUT_DIR"/*.apk 2>/dev/null || true
