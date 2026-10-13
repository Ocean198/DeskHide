APP     := DeskHide
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" config/Info.plist)
BUNDLE  := build/$(APP).app
BINARY  := $(BUNDLE)/Contents/MacOS/$(APP)
ZIP     := dist/$(APP)-$(VERSION).zip
SWIFTC  := swiftc -O -swift-version 5 -target arm64-apple-macos14.0
PREFIX  ?= /Applications

# A Developer ID certificate in the keychain is picked up by itself. Without one the build is
# signed ad hoc, which is fine on this Mac but gets blocked on any other.
IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $$2; exit}')
# Keychain profile holding the notarization login; created once with
# `xcrun notarytool store-credentials $(NOTARY_PROFILE)`.
NOTARY_PROFILE ?= DeskHide

.PHONY: build test install dist icon screenshots clean

build: $(BINARY)

# Signed with the hardened runtime: no injected libraries, no debugger attaching.
$(BINARY): $(wildcard src/*.swift) config/Info.plist assets/AppIcon.icns Makefile
	mkdir -p $(dir $@) $(BUNDLE)/Contents/Resources
	$(SWIFTC) src/*.swift -o $@
	cp config/Info.plist $(BUNDLE)/Contents/Info.plist
	cp assets/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	codesign --force --options runtime $(if $(IDENTITY),--timestamp --sign "$(IDENTITY)",--sign -) $(BUNDLE)

test:
	mkdir -p build
	$(SWIFTC) -parse-as-library src/DesktopSettings.swift src/Hotkey.swift tests/*.swift -o build/tests
	build/tests

# SIGTERM lets a running copy restore the icons before it is replaced.
install: build
	-pkill -x $(APP) && sleep 1
	ditto $(BUNDLE) $(PREFIX)/$(APP).app
	open $(PREFIX)/$(APP).app

# Apple notarizes an upload, hence the first zip. The ticket it issues is then stapled to the
# app itself, so the zip that gets handed out has to be made again afterwards.
dist: build
	@test -n "$(IDENTITY)" || { echo "No Developer ID Application certificate in the keychain."; exit 1; }
	mkdir -p dist
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	xcrun notarytool submit $(ZIP) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(BUNDLE)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	spctl --assess --type execute --verbose=2 $(BUNDLE)

# Both are drawn by script, so the artwork can be regenerated instead of edited by hand.
icon:
	mkdir -p build
	swiftc -O scripts/make-icon.swift -o build/make-icon
	build/make-icon assets

screenshots:
	mkdir -p build
	swiftc -O -swift-version 5 -parse-as-library scripts/make-screenshots.swift src/Onboarding.swift -o build/make-screenshots
	build/make-screenshots assets

clean:
	rm -rf build dist
