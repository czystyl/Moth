.PHONY: build run stop clean dev icon

icon:
	@swift Scripts/generate-icon.swift
	@mkdir -p Resources
	@iconutil --convert icns build/AppIcon.iconset --output Resources/AppIcon.icns
	@echo "Generated: Resources/AppIcon.icns"

build:
	swift build -c release
	@mkdir -p build/Moth.app/Contents/MacOS
	@mkdir -p build/Moth.app/Contents/Resources
	@cp .build/release/Moth build/Moth.app/Contents/MacOS/Moth
	@cp Resources/Info.plist build/Moth.app/Contents/Info.plist
	@test -f Resources/AppIcon.icns && cp Resources/AppIcon.icns build/Moth.app/Contents/Resources/AppIcon.icns || true
	@codesign --force --sign - build/Moth.app
	@echo "Built: build/Moth.app"

run: build
	@-pkill -x Moth 2>/dev/null
	@sleep 0.5
	@echo "Starting Moth..."
	@open build/Moth.app

stop:
	@pkill -x Moth 2>/dev/null && echo "Stopped Moth" || echo "Moth not running"

clean:
	swift package clean
	rm -rf build

dev:
	swift build
	@mkdir -p build/Moth.app/Contents/MacOS
	@mkdir -p build/Moth.app/Contents/Resources
	@cp .build/debug/Moth build/Moth.app/Contents/MacOS/Moth
	@cp Resources/Info.plist build/Moth.app/Contents/Info.plist
	@test -f Resources/AppIcon.icns && cp Resources/AppIcon.icns build/Moth.app/Contents/Resources/AppIcon.icns || true
	@codesign --force --sign - build/Moth.app
	@-pkill -x Moth 2>/dev/null
	@sleep 0.5
	@open build/Moth.app
	@echo "Dev build running"
