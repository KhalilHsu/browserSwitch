#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrowserRouter"
BUILD_DIR=".build/release"
APP_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

mkdir -p "${BUILD_DIR}"
swiftc -parse-as-library \
  Sources/BrowserRouter/main.swift \
  -o "${BUILD_DIR}/${APP_NAME}" \
  -framework AppKit \
  -framework CoreGraphics

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"

codesign --force --deep --sign - "${APP_DIR}" >/dev/null
echo "${APP_DIR}"
