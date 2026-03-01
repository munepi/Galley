APP_NAME := GalleyPDF
VERSION := 0.0

BUNDLE_NAME := $(APP_NAME).app
BUILD_PATH := .build/apple/Products/Release/$(APP_NAME)
CONTENTS_DIR := $(BUNDLE_NAME)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

TAG_EXISTS := $(shell git rev-parse -q --verify refs/tags/v$(VERSION) >/dev/null && echo yes || echo no)

ifeq ($(TAG_EXISTS),yes)
GIT_SUFFIX =
else
GIT_SUFFIX = -$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
endif

PKG_NAME := $(APP_NAME).pkg
DMG_FILENAME := $(APP_NAME)_$(VERSION)$(GIT_SUFFIX).dmg
VOL_NAME := $(APP_NAME)

PKG_TEMP_DIR := .build/pkg_temp
COMPONENT_PKG := $(PKG_TEMP_DIR)/component.pkg
DIST_XML := $(PKG_TEMP_DIR)/Distribution.xml
RESOURCES_DIR_PKG := $(PKG_TEMP_DIR)/Resources

all: app

.PHONY: clean
clean:
	rm -rf .build
	rm -rf $(BUNDLE_NAME)
	rm -f *.dmg
	rm -f *.pkg
	find . -name '*~' -delete

.PHONY: nativebuild
nativebuild:
	swift build -c release

.PHONY: build
build:
	swift build -c release --arch arm64 --arch x86_64

.PHONY: app
app $(APP_NAME).app: build $(APP_NAME).icns
	@echo "Packaging $(BUNDLE_NAME)..."
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)/en.lproj
	echo 'CFBundleName = "Galley";\nCFBundleDisplayName = "Galley";' > $(RESOURCES_DIR)/en.lproj/InfoPlist.strings
	cp $(BUILD_PATH) $(MACOS_DIR)/
	cp Info.plist $(CONTENTS_DIR)/
	cp $(APP_NAME).icns $(RESOURCES_DIR)/
	cp $(APP_NAME).png $(RESOURCES_DIR)/
	cp displayline.bash $(MACOS_DIR)/displayline
	chmod +x $(MACOS_DIR)/$(APP_NAME)
	chmod +x $(MACOS_DIR)/displayline
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

.PHONY: uninstall
uninstall:
	@echo "Uninstalling $(BUNDLE_NAME) from /Applications/..."
	rm -rf /Applications/$(BUNDLE_NAME)
	@echo "Uninstallation complete!"

.PHONY: pkg
pkg $(PKG_NAME): app
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

.PHONY: dmg
dmg: pkg
	@echo "Creating disk image ($(DMG_FILENAME)) in ULMO format..."
	@rm -f $(DMG_FILENAME)
	@mkdir -p .build/dmg_temp
	@cp $(PKG_NAME) .build/dmg_temp/
	@cp README.md .build/dmg_temp/README.txt
	hdiutil create -volname $(VOL_NAME) -srcfolder .build/dmg_temp -ov -format ULMO $(DMG_FILENAME)
	@rm -rf .build/dmg_temp
	@echo "Done! $(DMG_FILENAME) created."
