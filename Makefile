APP_NAME := GalleyPDF
BUNDLE_ID := com.github.munepi.galley
VERSION := $(shell head -n 1 version)
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 0)

# Default signing identities (override on command line if needed)
CODE_SIGN_IDENTITY ?= 
INSTALLER_CODE_SIGN_IDENTITY ?= 

BUNDLE_NAME := $(APP_NAME).app
BUILD_PATH := .build/apple/Products/Release/$(APP_NAME)
# The galleypdf command. Built as GalleyPDFCLI because the build directory is
# case-insensitive on APFS and `galleypdf` would collide with `GalleyPDF`.
CLI_BUILD_PATH := .build/apple/Products/Release/$(APP_NAME)CLI
CONTENTS_DIR := $(BUNDLE_NAME)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
# Auxiliary executables live under Contents/MacOS per Apple's nested code
# layout; the same shape as Emacs.app/Contents/MacOS/bin/emacsclient.
CLI_DIR := $(MACOS_DIR)/bin
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
FRAMEWORKS_DIR := $(CONTENTS_DIR)/Frameworks

# Sparkle (auto-update) ----------------------------------------------------
# Channel-specific values. Override on the command line for the pro channel:
#   make app SU_FEED_URL=https://example.com/pro-appcast.xml SU_PUBLIC_ED_KEY=...
SU_FEED_URL ?= https://munepi.github.io/Galley/appcast.xml
SU_PUBLIC_ED_KEY ?= WXbMltcSsSAHafSIrJv/VJ9WYXUP7W5F5Y+2Eldrask=

SPARKLE_ROOT := .build/artifacts/sparkle/Sparkle
SPARKLE_FW := $(SPARKLE_ROOT)/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework
SPARKLE_BIN := $(SPARKLE_ROOT)/bin
# --------------------------------------------------------------------------

TAG_EXISTS := $(shell git rev-parse -q --verify refs/tags/v$(VERSION) >/dev/null && echo yes || echo no)

ifeq ($(TAG_EXISTS),yes)
GIT_SUFFIX =
else
GIT_SUFFIX = -$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
endif

PKG_NAME := $(APP_NAME)_$(VERSION)$(GIT_SUFFIX).pkg
DMG_FILENAME := $(APP_NAME)_$(VERSION)$(GIT_SUFFIX).dmg
VOL_NAME := $(APP_NAME)

# Where `make install-cli` symlinks the galleypdf command for source builds.
# Homebrew users get the same symlink from the cask's `binary` stanza instead.
CLI_PREFIX ?= /usr/local

PKG_TEMP_DIR := .build/pkg_temp
COMPONENT_PKG := $(PKG_TEMP_DIR)/component.pkg
DIST_XML := $(PKG_TEMP_DIR)/Distribution.xml
RESOURCES_DIR_PKG := $(PKG_TEMP_DIR)/Resources

all: app

.PHONY: clean
clean:
	rm -rf .build
	rm -rf $(BUNDLE_NAME)
	rm -f Info.plist
	rm -f *.dmg
	rm -f *.pkg
	find . -name '.DS_Store' -delete
	find . -name '*~' -delete

Info.plist: Info.plist.in version
	sed -e 's/@@VERSION@@/$(VERSION)/g' \
	    -e 's/@@BUILD_NUMBER@@/$(BUILD_NUMBER)/g' \
	    -e 's|@@SU_FEED_URL@@|$(SU_FEED_URL)|g' \
	    -e 's|@@SU_PUBLIC_ED_KEY@@|$(SU_PUBLIC_ED_KEY)|g' \
	    Info.plist.in > Info.plist

.PHONY: nativebuild
nativebuild:
	swift build -c release

.PHONY: build
build:
	swift build -c release --arch arm64 --arch x86_64

.PHONY: app
app $(APP_NAME).app: build $(APP_NAME).icns Info.plist
	@echo "Packaging $(BUNDLE_NAME)..."
	mkdir -p $(MACOS_DIR)
	mkdir -p $(CLI_DIR)
	mkdir -p $(RESOURCES_DIR)/en.lproj
	mkdir -p $(FRAMEWORKS_DIR)
	echo 'CFBundleName = "Galley";\nCFBundleDisplayName = "Galley";' > $(RESOURCES_DIR)/en.lproj/InfoPlist.strings
	cp $(BUILD_PATH) $(MACOS_DIR)/
	cp Info.plist $(CONTENTS_DIR)/
	cp $(APP_NAME).icns $(RESOURCES_DIR)/
	cp $(APP_NAME).png $(RESOURCES_DIR)/
	chmod +x $(MACOS_DIR)/$(APP_NAME)
	# --- Command line front end (symlinked onto PATH by the Homebrew cask) ---
	cp $(CLI_BUILD_PATH) $(CLI_DIR)/galleypdf
	chmod +x $(CLI_DIR)/galleypdf
	# --- Embed Sparkle.framework (required for runtime) ---
	@echo "Embedding Sparkle.framework..."
	rsync -a --delete $(SPARKLE_FW) $(FRAMEWORKS_DIR)/
	# Galley is not sandboxed, so XPCServices are unnecessary.
	# Remove both the directory and the top-level symlink to avoid dangling links.
	rm -rf $(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B/XPCServices
	rm -f $(FRAMEWORKS_DIR)/Sparkle.framework/XPCServices
	touch $(BUNDLE_NAME)
	@echo "Done! You can find $(BUNDLE_NAME) in the current directory."

.PHONY: icns
icns $(APP_NAME).icns: make_icon.bash
	./make_icon.bash

.PHONY: install
install: app
	@echo "Installing $(BUNDLE_NAME) to /Applications/..."
	rm -rf /Applications/$(BUNDLE_NAME)
	cp -R $(BUNDLE_NAME) /Applications/
	xattr -rc /Applications/$(BUNDLE_NAME)
	@echo "Installation complete!"

.PHONY: install-cli
install-cli:
	@echo "Linking galleypdf into $(CLI_PREFIX)/bin/..."
	mkdir -p $(CLI_PREFIX)/bin
	ln -sf /Applications/$(BUNDLE_NAME)/Contents/MacOS/bin/galleypdf $(CLI_PREFIX)/bin/galleypdf
	@echo "Done! Run 'galleypdf --help' to get started."

.PHONY: uninstall
uninstall: uninstall-cli
	@echo "Uninstalling $(BUNDLE_NAME) from /Applications/..."
	rm -rf /Applications/$(BUNDLE_NAME)
	@echo "Uninstallation complete!"

.PHONY: uninstall-cli
uninstall-cli:
	@rm -f $(CLI_PREFIX)/bin/galleypdf 2>/dev/null || \
	    echo "Skipped $(CLI_PREFIX)/bin/galleypdf (not writable; rerun with sudo if needed)."

.PHONY: codesign
codesign: app
	CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
	    scripts/codesign.sh $(BUNDLE_NAME)

.PHONY: pkg
pkg $(PKG_NAME): codesign
	@echo "Building package $(PKG_NAME)..."
	@rm -f $(PKG_NAME)
	@rm -rf $(PKG_TEMP_DIR)
	@mkdir -p $(RESOURCES_DIR_PKG)
	pkgbuild --component $(BUNDLE_NAME) --install-location /Applications $(COMPONENT_PKG)
	productbuild --synthesize --package $(COMPONENT_PKG) $(DIST_XML)
	cp README.md $(RESOURCES_DIR_PKG)/README.txt
	cp LICENSE $(RESOURCES_DIR_PKG)/LICENSE.txt
	@sed -i '' -e 's|<installer-gui-script.*>|&<title>$(APP_NAME)</title><readme file="README.txt"/><license file="LICENSE.txt"/>|' $(DIST_XML)
	productbuild --distribution $(DIST_XML) --package-path $(PKG_TEMP_DIR) --resources $(RESOURCES_DIR_PKG) $(PKG_NAME)
	@rm -rf $(PKG_TEMP_DIR)
	@echo "Package $(PKG_NAME) created."

.PHONY: codesign-pkg
codesign-pkg: pkg
	INSTALLER_CODE_SIGN_IDENTITY="$(INSTALLER_CODE_SIGN_IDENTITY)" \
	    scripts/codesign-pkg.sh $(PKG_NAME)

# The disk image carries GalleyPDF.app itself (plus the customary
# /Applications symlink) so that `brew install --cask` can mount it and copy
# the bundle straight out. The guided installer ships as a separate .pkg.
.PHONY: dmg
dmg: codesign
	@echo "Creating disk image ($(DMG_FILENAME)) in ULMO format..."
	@rm -f $(DMG_FILENAME)
	@rm -rf .build/dmg_temp
	@mkdir -p .build/dmg_temp
	ditto $(BUNDLE_NAME) .build/dmg_temp/$(BUNDLE_NAME)
	@ln -s /Applications .build/dmg_temp/Applications
	@cp README.md .build/dmg_temp/README.txt
	hdiutil create -volname $(VOL_NAME) -srcfolder .build/dmg_temp -ov -format ULMO $(DMG_FILENAME)
	@rm -rf .build/dmg_temp
	@echo "Done! $(DMG_FILENAME) created."

.PHONY: notarize
notarize: dmg codesign-pkg
	xcrun notarytool submit $(DMG_FILENAME) \
	    --keychain-profile "$(NOTARIZE_PROFILE)" --wait
	xcrun stapler staple $(DMG_FILENAME)
	xcrun notarytool submit $(PKG_NAME) \
	    --keychain-profile "$(NOTARIZE_PROFILE)" --wait
	xcrun stapler staple $(PKG_NAME)
	@echo "Notarization complete."

.PHONY: log
log:
	log stream --predicate 'subsystem == "$(BUNDLE_ID)"' --level info

.PHONY: notarized-dmg
notarized-dmg: dmg notarize

# Sparkle helpers ----------------------------------------------------------

.PHONY: sparkle-generate-keys
sparkle-generate-keys:
	@echo "Generating EdDSA key pair (private key stored in macOS Keychain)..."
	@$(SPARKLE_BIN)/generate_keys
	@echo ""
	@echo "Copy the public key above into Info.plist.in (SU_PUBLIC_ED_KEY)"
	@echo "or pass it via 'make app SU_PUBLIC_ED_KEY=...'"

.PHONY: sparkle-export-key
sparkle-export-key:
	@echo "Exporting private EdDSA key (KEEP SECRET)..."
	@$(SPARKLE_BIN)/generate_keys -x sparkle_private_key.txt
	@echo "Saved to sparkle_private_key.txt — store as a CI secret and delete locally."

.PHONY: sign-update
sign-update:
	@if [ ! -f "$(DMG_FILENAME)" ]; then \
	    echo "Error: $(DMG_FILENAME) not found. Run 'make dmg' first."; \
	    exit 1; \
	fi
	@echo "Signing $(DMG_FILENAME) with EdDSA..."
	@$(SPARKLE_BIN)/sign_update $(DMG_FILENAME)

.PHONY: appcast
appcast: sign-update
	@echo ""
	@echo "Add the sparkle:edSignature/length attributes above to your appcast.xml"
	@echo "  enclosure URL: https://github.com/munepi/Galley/releases/download/v$(VERSION)/$(DMG_FILENAME)"
