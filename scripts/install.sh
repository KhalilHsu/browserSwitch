#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrowserRouter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_APP="${REPO_ROOT}/.build/${APP_NAME}.app"
TARGET_APP="/Applications/${APP_NAME}.app"
BUNDLE_ID="local.browser-router"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
DRY_RUN=false
OPEN_AFTER_INSTALL=true

usage() {
  cat <<EOF
Usage: scripts/install.sh [--dry-run] [--no-open]

Build and install ${APP_NAME} to:
  ${TARGET_APP}

Options:
  --dry-run   Check prerequisites and build the app without changing /Applications.
  --no-open   Install without launching the app afterward.
  -h, --help  Show this help.
EOF
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --no-open)
      OPEN_AFTER_INSTALL=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

command -v swift >/dev/null 2>&1 || fail "Swift is not available. Install Xcode Command Line Tools with: xcode-select --install"
command -v codesign >/dev/null 2>&1 || fail "codesign is not available. Install Xcode Command Line Tools with: xcode-select --install"
command -v osascript >/dev/null 2>&1 || fail "osascript is not available on this system."
command -v open >/dev/null 2>&1 || fail "open is not available on this system."

cd "${REPO_ROOT}"

for app in "${REPO_ROOT}"/.build/BrowserRouter*.app; do
  case "${app}" in
    "${SOURCE_APP}")
      continue
      ;;
  esac

  if [ -d "${app}" ]; then
    "${LSREGISTER}" -u "${app}" >/dev/null 2>&1 || true
    rm -rf "${app}"
  fi
done

log "Building ${APP_NAME}..."
"${SCRIPT_DIR}/build-app.sh" >/dev/null

[ -d "${SOURCE_APP}" ] || fail "Build completed but ${SOURCE_APP} was not created."

if [ "${DRY_RUN}" = true ]; then
  log "Dry run completed. Built app bundle at ${SOURCE_APP}"
  exit 0
fi

if [ ! -d /Applications ] || [ ! -w /Applications ]; then
  fail "/Applications is not writable. Re-run with sudo or install from an admin account."
fi

log "Stopping any running ${APP_NAME} instance..."
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
pkill -f "${TARGET_APP}/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 || true
sleep 0.5

if [ -d "${TARGET_APP}" ]; then
  log "Replacing ${TARGET_APP}..."
  rm -rf "${TARGET_APP}" || fail "Could not remove ${TARGET_APP}. Re-run with sudo or remove it manually."
else
  log "Installing to ${TARGET_APP}..."
fi

cp -R "${SOURCE_APP}" /Applications/ || fail "Could not copy ${SOURCE_APP} to /Applications. Re-run with sudo or install from an admin account."
"${LSREGISTER}" -f "${TARGET_APP}" >/dev/null 2>&1 || true

if [ "${OPEN_AFTER_INSTALL}" = true ]; then
  open "${TARGET_APP}"
  log "Installed and launched ${TARGET_APP}"
else
  log "Installed ${TARGET_APP}"
fi
