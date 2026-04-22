#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrowserRouter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_APP="/Applications/${APP_NAME}.app"
BUNDLE_ID="local.browser-router"
USER_HOME="${HOME}"
if [ "${SUDO_USER:-}" != "" ] && [ "${SUDO_USER}" != "root" ]; then
  USER_HOME="$(eval echo "~${SUDO_USER}")"
fi
CONFIG_DIR="${USER_HOME}/Library/Application Support/${APP_NAME}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
REMOVE_CONFIG=false
YES=false
DRY_RUN=false
RESTORE_DEFAULT=true

usage() {
  cat <<EOF
Usage: scripts/uninstall.sh [--remove-config] [--yes] [--dry-run] [--skip-restore]

Uninstall ${APP_NAME} from:
  ${TARGET_APP}

Options:
  --remove-config  Also delete local configuration at ${CONFIG_DIR}.
  --yes            Do not prompt before deleting files.
  --dry-run        Show what would be removed without deleting anything.
  --skip-restore   Do not try to restore the previous default browser.
  -h, --help       Show this help.
EOF
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

confirm() {
  [ "${YES}" = true ] && return 0

  printf '%s [y/N] ' "$1"
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --remove-config)
      REMOVE_CONFIG=true
      ;;
    --yes)
      YES=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --skip-restore)
      RESTORE_DEFAULT=false
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

command -v osascript >/dev/null 2>&1 || fail "osascript is not available on this system."

log "Before uninstalling, use BrowserRouter Settings to restore your previous default browser if BrowserRouter is currently the default."

if [ "${DRY_RUN}" = true ]; then
  log "Dry run:"
  [ -d "${TARGET_APP}" ] && log "Would remove ${TARGET_APP}" || log "${TARGET_APP} is not installed."
  [ "${RESTORE_DEFAULT}" = true ] && BROWSERROUTER_HOME="${USER_HOME}" swift "${SCRIPT_DIR}/restore-default-browser.swift" --dry-run || true
  [ "${REMOVE_CONFIG}" = true ] && [ -d "${CONFIG_DIR}" ] && log "Would remove ${CONFIG_DIR}"
  [ "${REMOVE_CONFIG}" = true ] && [ ! -d "${CONFIG_DIR}" ] && log "${CONFIG_DIR} does not exist."
  exit 0
fi

if ! confirm "Continue uninstalling ${APP_NAME}?"; then
  log "Uninstall cancelled."
  exit 0
fi

if [ "${RESTORE_DEFAULT}" = true ]; then
  log "Restoring previous default browser..."
  if BROWSERROUTER_HOME="${USER_HOME}" swift "${SCRIPT_DIR}/restore-default-browser.swift" --quiet; then
    log "Previous default browser restored."
  else
    log "Warning: could not automatically restore the previous default browser. Use macOS System Settings to choose a default browser."
  fi
fi

log "Stopping any running ${APP_NAME} instance..."
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
pkill -f "${TARGET_APP}/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 || true
sleep 0.5

if [ -d "${TARGET_APP}" ]; then
  "${LSREGISTER}" -u "${TARGET_APP}" >/dev/null 2>&1 || true
  rm -rf "${TARGET_APP}" || fail "Could not remove ${TARGET_APP}. Re-run with sudo or remove it manually."
  log "Removed ${TARGET_APP}"
else
  log "${TARGET_APP} is not installed."
fi

if [ "${REMOVE_CONFIG}" = true ]; then
  if [ -d "${CONFIG_DIR}" ]; then
    rm -rf "${CONFIG_DIR}" || fail "Could not remove ${CONFIG_DIR}."
    log "Removed ${CONFIG_DIR}"
  else
    log "${CONFIG_DIR} does not exist."
  fi
else
  log "Kept local configuration at ${CONFIG_DIR}"
fi
