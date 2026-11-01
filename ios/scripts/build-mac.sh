#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/build/Voca.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INSTALL_APP=false

if [[ "${1:-}" == "--install" ]] || [[ "${INSTALL_TO_APPLICATIONS:-0}" == "1" ]]; then
  INSTALL_APP=true
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "==> Building Voca for macOS..."

SDK_PATH="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"

swiftc \
  -target "${ARCH}-apple-macosx14.0" \
  -sdk "${SDK_PATH}" \
  -O \
  -module-name Voca \
  -lsqlite3 \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework Carbon \
  -framework CoreSpotlight \
  -framework PDFKit \
  -framework ServiceManagement \
  -framework UniformTypeIdentifiers \
  -framework UserNotifications \
  -framework Vision \
  -framework WebKit \
  -framework WidgetKit \
  "${ROOT_DIR}/Shared/WidgetSharedStore.swift" \
  $(find "${ROOT_DIR}/VocaMac" -name "*.swift") \
  $(find "${ROOT_DIR}/Voca/Core/Auth" "${ROOT_DIR}/Voca/Core/Cache" "${ROOT_DIR}/Voca/Core/Models" "${ROOT_DIR}/Voca/Core/Networking" "${ROOT_DIR}/Voca/Core/Services" -name "*.swift") \
  -o "${MACOS_DIR}/Voca"

echo "==> Building Voca Widget Extension for macOS..."
PLUGINS_DIR="${CONTENTS_DIR}/PlugIns"
WIDGET_APPEX="${PLUGINS_DIR}/VocaWidget.appex"
WIDGET_CONTENTS="${WIDGET_APPEX}/Contents"
WIDGET_MACOS="${WIDGET_CONTENTS}/MacOS"
WIDGET_RESOURCES="${WIDGET_CONTENTS}/Resources"

mkdir -p "${WIDGET_MACOS}" "${WIDGET_RESOURCES}"

swiftc \
  -target "${ARCH}-apple-macosx14.0" \
  -sdk "${SDK_PATH}" \
  -O \
  -module-name VocaWidgetExtension \
  -framework SwiftUI \
  -framework WidgetKit \
  -framework AppIntents \
  "${ROOT_DIR}/VocaWidget/VocaWidget.swift" \
  "${ROOT_DIR}/Shared/WidgetSharedStore.swift" \
  -o "${WIDGET_MACOS}/VocaWidget"

cat << 'EOF' > "${WIDGET_CONTENTS}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Voca Từ vựng</string>
	<key>CFBundleExecutable</key>
	<string>VocaWidget</string>
	<key>CFBundleIdentifier</key>
	<string>com.voca.mac.widget</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>VocaWidget</string>
	<key>CFBundlePackageType</key>
	<string>XPC!</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${WIDGET_APPEX}"

if [ -d "${ROOT_DIR}/Voca/Resources/HanziWriter" ]; then
  rm -rf "${RESOURCES_DIR}/HanziWriter"
  cp -R "${ROOT_DIR}/Voca/Resources/HanziWriter" "${RESOURCES_DIR}/HanziWriter"
fi

if [ -f "${ROOT_DIR}/VocaMac/SupportingFiles/AppIcon.icns" ]; then
  cp "${ROOT_DIR}/VocaMac/SupportingFiles/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

sed \
  -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
  -e 's/$(EXECUTABLE_NAME)/Voca/g' \
  -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.voca.mac/g' \
  -e 's/$(PRODUCT_NAME)/Voca/g' \
  -e 's/$(MARKETING_VERSION)/2.3.1/g' \
  -e 's/$(CURRENT_PROJECT_VERSION)/5/g' \
  "${ROOT_DIR}/VocaMac/SupportingFiles/Info.plist" > "${CONTENTS_DIR}/Info.plist"

printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

codesign --force --deep --sign - "${APP_BUNDLE}"

pluginkit -a "${WIDGET_APPEX}" 2>/dev/null || true

echo "==> Built successfully: ${APP_BUNDLE}"

if [[ "${INSTALL_APP}" == "true" ]]; then
  DEST_APP="/Applications/Voca.app"
  echo "==> Replacing ${DEST_APP}..."
  osascript -e 'tell application "Voca" to quit' >/dev/null 2>&1 || true
  pkill -x "Voca" >/dev/null 2>&1 || true
  sleep 0.4
  rm -rf "${DEST_APP}"
  ditto "${APP_BUNDLE}" "${DEST_APP}"
  codesign --force --deep --sign - "${DEST_APP}"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${DEST_APP}" >/dev/null 2>&1 || true
  pluginkit -a "${DEST_APP}/Contents/PlugIns/VocaWidget.appex" 2>/dev/null || true
  echo "==> Installed successfully: ${DEST_APP}"
fi
