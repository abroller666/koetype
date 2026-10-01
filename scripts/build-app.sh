#!/bin/bash
# swift build → KoeType.app バンドル組み立て → ad-hoc 署名
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/KoeType.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KoeType "$APP/Contents/MacOS/KoeType"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# ad-hoc 署名(マイク・アクセシビリティの TCC 許可に必要)
codesign --force --sign - "$APP"

echo "Built: $(pwd)/$APP"
echo "起動: open $APP"
