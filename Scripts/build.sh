#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building Moth..."
swift build -c release

APP_DIR="build/Moth.app/Contents/MacOS"
mkdir -p "$APP_DIR"
mkdir -p "build/Moth.app/Contents"

cp .build/release/Moth "$APP_DIR/Moth"
cp Resources/Info.plist "build/Moth.app/Contents/Info.plist"

echo "Built: build/Moth.app"
