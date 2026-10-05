PROJECT := Diapason.xcodeproj
SCHEME := Diapason
DESTINATION := platform=macOS
ICON_SOURCE := Resources/AppIcon.png
ICON_SET := Sources/Diapason/Assets.xcassets/AppIcon.appiconset
ICON_SIZES := 16 32 64 128 256 512 1024
INSTALL_PATH := /Applications/$(SCHEME).app
ARCHIVE_PATH := build/Diapason.xcarchive
ARCHIVE_APP := $(ARCHIVE_PATH)/Products/Applications/$(SCHEME).app
EXPORT_DIR := build/Export
DMG_PATH := build/Diapason.dmg
UNSIGNED_DMG_PATH := build/Diapason-unsigned.dmg
# Extra build settings for archive, for example: make dmg-unsigned XCODEBUILD_FLAGS="MARKETING_VERSION=1.2.0"
XCODEBUILD_FLAGS ?=
# Local settings for make test-e2e. Copy .env.example to .env.
-include .env

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: gen build run test test-e2e lint format clean icons install archive export dmg dmg-unsigned appcast release

gen:
	xcodegen generate

build: gen
	set -o pipefail && xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		| xcbeautify

run: build
	@APP_PATH=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings -destination '$(DESTINATION)' 2>/dev/null | awk -F'= ' '/BUILT_PRODUCTS_DIR/ {print $$2; exit}')/$(SCHEME).app; \
		echo "Launching $$APP_PATH"; \
		pkill -f "$(SCHEME).app/Contents/MacOS" 2>/dev/null || true; \
		sleep 1; \
		open -n "$$APP_PATH"

test: gen
	set -o pipefail && xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:DiapasonTests \
		| xcbeautify

# Needs a reachable Jellyfin server: DIAPASON_TEST_SERVER, DIAPASON_TEST_USER, DIAPASON_TEST_PASSWORD.
# ONLY=PlaybackUITests/testSearch runs one test.
test-e2e: gen
	set -o pipefail && \
	TEST_RUNNER_DIAPASON_TEST_SERVER="$(DIAPASON_TEST_SERVER)" \
	TEST_RUNNER_DIAPASON_TEST_USER="$(DIAPASON_TEST_USER)" \
	TEST_RUNNER_DIAPASON_TEST_PASSWORD="$(DIAPASON_TEST_PASSWORD)" \
	TEST_RUNNER_DIAPASON_SCREENSHOT_DIR="$(DIAPASON_SCREENSHOT_DIR)" \
	TEST_RUNNER_DIAPASON_SCREENSHOTS="$(DIAPASON_SCREENSHOTS)" \
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:DiapasonUITests$(if $(ONLY),/$(ONLY)) \
		| xcbeautify

lint:
	swiftlint --strict

format:
	swiftformat .

clean:
	rm -rf $(PROJECT) DerivedData build .swiftpm

icons:
	@test -f $(ICON_SOURCE) || { echo "Missing $(ICON_SOURCE)"; exit 1; }
	@for size in $(ICON_SIZES); do \
		sips -Z $$size $(ICON_SOURCE) --out $(ICON_SET)/icon_$$size.png >/dev/null; \
		echo "  rendered icon_$$size.png"; \
	done

install: build
	@APP_PATH=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings -destination '$(DESTINATION)' 2>/dev/null | awk -F'= ' '/BUILT_PRODUCTS_DIR/ {print $$2; exit}')/$(SCHEME).app; \
		echo "Installing $$APP_PATH → $(INSTALL_PATH)"; \
		pkill -9 -f "$(SCHEME).app/Contents/MacOS" 2>/dev/null || true; \
		sleep 1; \
		$(LSREGISTER) -u "$(INSTALL_PATH)" >/dev/null 2>&1 || true; \
		rm -rf "$(INSTALL_PATH)"; \
		cp -R "$$APP_PATH" "$(INSTALL_PATH)"; \
		$(LSREGISTER) -f "$(INSTALL_PATH)" >/dev/null 2>&1; \
		killall Dock 2>/dev/null || true; \
		echo "Installed."

archive: gen
	set -o pipefail && xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-archivePath $(ARCHIVE_PATH) \
		$(XCODEBUILD_FLAGS) \
		| xcbeautify

export: archive
	@security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application" || { \
		echo "No 'Developer ID Application' identity in the keychain. Install the cert, set DEVELOPMENT_TEAM"; \
		echo "in project.yml and flip ENABLE_HARDENED_RUNTIME to YES, or use 'make dmg-unsigned'."; \
		exit 1; \
	}
	set -o pipefail && xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_DIR) \
		-exportOptionsPlist scripts/ExportOptions.plist \
		| xcbeautify

dmg: export
	scripts/make_dmg.sh $(EXPORT_DIR)/$(SCHEME).app $(DMG_PATH)

# Ad-hoc signed app straight out of the archive. Gatekeeper warns on first launch (right-click, Open).
dmg-unsigned: archive
	scripts/make_dmg.sh $(ARCHIVE_APP) $(UNSIGNED_DMG_PATH)

# Signs the DMG with the EdDSA key in the login keychain and writes build/appcast.xml.
appcast:
	@command -v generate_appcast >/dev/null || { echo "Install Sparkle tools: brew install --cask sparkle"; exit 1; }
	generate_appcast build/ --download-url-prefix https://github.com/indiependente/diapason/releases/latest/download/

release: dmg appcast
	@echo "Upload $(DMG_PATH) and build/appcast.xml to the GitHub release."
