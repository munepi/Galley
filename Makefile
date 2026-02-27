APP_NAME = GalleyPDF
BUNDLE_NAME = $(APP_NAME).app
BUILD_PATH = .build/apple/Products/Release/$(APP_NAME)
CONTENTS_DIR = $(BUNDLE_NAME)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
DMG_NAME = $(APP_NAME).dmg
VOL_NAME = $(APP_NAME)

all: app

.PHONY: clean
clean:
	rm -rf .build
	rm -rf $(BUNDLE_NAME)
	rm -f $(DMG_NAME)
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

.PHONY: dmg
dmg $(DMG_NAME): app
	@echo "Creating disk image ($(DMG_NAME)) in ULMO format..."
	@rm -f $(DMG_NAME)
	@mkdir -p .build/dmg_temp
	@cp -R $(BUNDLE_NAME) .build/dmg_temp/
	@cp README.md .build/dmg_temp/
	# @cp LICENSE .build/dmg_temp/
	@ln -s /Applications .build/dmg_temp/Applications
	hdiutil create -volname $(VOL_NAME) -srcfolder .build/dmg_temp -ov -format ULMO $(DMG_NAME)
	@rm -rf .build/dmg_temp
	@echo "Done! $(DMG_NAME) created."
