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

# UNIVERSAL=1 builds an arm64 + x86_64 binary for release packaging.
SWIFT_BUILD_ARGS=(-c release --product "${APP_NAME}")
if [ "${UNIVERSAL:-0}" = "1" ]; then
  SWIFT_BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

mkdir -p "${BUILD_DIR}" "${FALLBACK_DIR}"
rm -f "${GENERATED_ICON}"
swift scripts/generate-icon.swift "${GENERATED_ICON}"
if swift build "${SWIFT_BUILD_ARGS[@]}" >"${SWIFTPM_LOG}" 2>&1; then
  BINARY_PATH="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)/${APP_NAME}"
elif [ "${UNIVERSAL:-0}" = "1" ]; then
  echo "Universal SwiftPM build failed. Details: ${SWIFTPM_LOG}" >&2
  exit 1
else
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
if [ -d "Resources" ]; then
  cp -R Resources/. "${CONTENTS_DIR}/Resources/"
fi

codesign --force --deep --sign - "${APP_DIR}" >/dev/null
echo "${APP_DIR}"
