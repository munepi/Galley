APP_NAME = Leaf
BUNDLE_NAME = $(APP_NAME).app
BUILD_PATH = .build/apple/Products/Release/$(APP_NAME)
CONTENTS_DIR = $(BUNDLE_NAME)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
DMG_NAME = $(APP_NAME).dmg
VOL_NAME = $(APP_NAME)

.PHONY: all build app clean install uninstall dmg

all: app

nativebuild:
	swift build -c release

build:
	swift build -c release --arch arm64 --arch x86_64

app $(APP_NAME).app: build
	@echo "Packaging $(BUNDLE_NAME)..."
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp $(BUILD_PATH) $(MACOS_DIR)/
	cp Info.plist $(CONTENTS_DIR)/
	cp displayline-leaf.bash $(CONTENTS_DIR)/displayline-leaf
	chmod +x $(MACOS_DIR)/$(APP_NAME)
	chmod +x $(CONTENTS_DIR)/displayline-leaf
	touch $(BUNDLE_NAME)
	@echo "Done! You can find $(BUNDLE_NAME) in the current directory."

install: app
	@echo "Installing $(BUNDLE_NAME) to /Applications/..."
	rm -rf /Applications/$(BUNDLE_NAME)
	cp -R $(BUNDLE_NAME) /Applications/
	xattr -rc /Applications/$(BUNDLE_NAME)
	@echo "Installation complete!"

uninstall:
	@echo "Uninstalling $(BUNDLE_NAME) from /Applications/..."
	rm -rf /Applications/$(BUNDLE_NAME)
	@echo "Uninstallation complete!"

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

clean:
	rm -rf .build
	rm -rf $(BUNDLE_NAME)
	rm -f $(DMG_NAME)
	find . -name '*~' -delete
