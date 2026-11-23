.PHONY: all icons clean build_clean

# Product name shown to the user / used for the packaged app
APP_NAME = GTAVIJB

# The Xcode target keeps its original name, so do the on-disk .app and its executable
BUILD_APP = build/Build/Products/Debug-iphoneos/Dopamine.app

all: $(APP_NAME).ipa

# Draw the GTA VI JB app icon from the theme photograph
icons:
	@echo Generating $(APP_NAME) app icons
	@swift ../scripts/generate_app_icons.swift

$(APP_NAME).ipa: icons $(BUILD_APP)
	@echo Ad-Hoc signing $(APP_NAME)
	xattr -rc $(BUILD_APP)
	ldid -SDopamine/Dopamine.entitlements $(BUILD_APP)/Dopamine
	ldid -s $(BUILD_APP)
	rm -rf Payload $(APP_NAME).ipa $(APP_NAME).tipa
	mkdir Payload
	cp -r $(BUILD_APP) Payload/Dopamine.app
	zip -Ar $(APP_NAME).ipa Payload
	rm -rf Payload
	cp $(APP_NAME).ipa $(APP_NAME).tipa

ifeq ($(NIGHTLY), 1)
$(BUILD_APP): FORCE
	xcodebuild -scheme Dopamine -derivedDataPath build -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO GCC_PREPROCESSOR_DEFINITIONS='NIGHTLY=1 COMMIT_HASH=\"$(COMMIT_HASH)\"'
else
$(BUILD_APP): FORCE
	xcodebuild -scheme Dopamine -derivedDataPath build -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
endif

clean:
	rm -rf build Payload $(APP_NAME).ipa $(APP_NAME).tipa

build_clean:
	rm -rf Payload build

FORCE: ;
