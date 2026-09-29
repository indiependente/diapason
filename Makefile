PROJECT := Diapason.xcodeproj
SCHEME := Diapason
DESTINATION := platform=macOS
ICON_SOURCE := Resources/AppIcon.png
ICON_SET := Sources/Diapason/Assets.xcassets/AppIcon.appiconset
ICON_SIZES := 16 32 64 128 256 512 1024
INSTALL_PATH := /Applications/$(SCHEME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: gen build run test test-e2e lint format clean icons install

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
test-e2e: gen
	set -o pipefail && \
	TEST_RUNNER_DIAPASON_TEST_SERVER="$(DIAPASON_TEST_SERVER)" \
	TEST_RUNNER_DIAPASON_TEST_USER="$(DIAPASON_TEST_USER)" \
	TEST_RUNNER_DIAPASON_TEST_PASSWORD="$(DIAPASON_TEST_PASSWORD)" \
	TEST_RUNNER_DIAPASON_SCREENSHOT_DIR="$(DIAPASON_SCREENSHOT_DIR)" \
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:DiapasonUITests \
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
