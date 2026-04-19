#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrowserRouter"
BUILD_DIR=".build/release"
FALLBACK_DIR=".build/fallback"
DIRECT_BUILD_DIR="${FALLBACK_DIR}/direct"
SWIFTPM_LOG="${FALLBACK_DIR}/swiftpm-build.log"
GENERATED_ICON="${FALLBACK_DIR}/BrowserRouter.icns"
APP_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
BINARY_PATH="${BUILD_DIR}/${APP_NAME}"

mkdir -p "${BUILD_DIR}" "${FALLBACK_DIR}"
rm -f "${GENERATED_ICON}"
swift scripts/generate-icon.swift "${GENERATED_ICON}"
if ! swift build -c release --product "${APP_NAME}" >"${SWIFTPM_LOG}" 2>&1; then
  echo "SwiftPM build failed; falling back to direct swiftc build. Details: ${SWIFTPM_LOG}" >&2
  rm -rf "${DIRECT_BUILD_DIR}"
  mkdir -p "${DIRECT_BUILD_DIR}"
  swiftc -parse-as-library \
    -whole-module-optimization \
    -emit-module \
    -emit-object \
    -module-name BrowserRouterCore \
    -emit-module-path "${DIRECT_BUILD_DIR}/BrowserRouterCore.swiftmodule" \
    Sources/BrowserRouterCore/*.swift \
    -o "${DIRECT_BUILD_DIR}/BrowserRouterCore.o"
  swiftc -parse-as-library \
    -I "${DIRECT_BUILD_DIR}" \
    Sources/BrowserRouter/*.swift \
    "${DIRECT_BUILD_DIR}/BrowserRouterCore.o" \
    -o "${BINARY_PATH}" \
    -framework AppKit \
    -framework CoreGraphics \
    -framework CoreServices
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${CONTENTS_DIR}/Resources"
cp "${BINARY_PATH}" "${MACOS_DIR}/${APP_NAME}"
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${GENERATED_ICON}" "${CONTENTS_DIR}/Resources/BrowserRouter.icns"

codesign --force --deep --sign - "${APP_DIR}" >/dev/null
echo "${APP_DIR}"
