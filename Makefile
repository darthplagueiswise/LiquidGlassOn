TARGET := iphone:clang:16.2:15.0
INSTALL_TARGET_PROCESSES = WhatsApp
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidGlassOn

LIQUIDGLASSON_SRC_FILES := $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))
LIQUIDGLASSON_FISHHOOK := $(wildcard modules/fishhook/fishhook.c)

$(TWEAK_NAME)_FILES = $(LIQUIDGLASSON_SRC_FILES) $(LIQUIDGLASSON_FISHHOOK)

ifdef SIDESTORE
$(TWEAK_NAME)_FILES += $(wildcard modules/SideloadPatch/*.xm)
endif

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(TWEAK_NAME)_LIBRARIES = substrate

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -Wno-frame-address -Imodules/fishhook
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram"
	@for f in resources/*.json.gz; do 		[ -f "$$f" ] && gzip -dc "$$f" > "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/$$(basename "$$f" .gz)" 2>/dev/null || true; 	done
	@cp -f resources/*.json "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/" 2>/dev/null || true
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/docs"
	@cp -f docs/*.md "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/docs/" 2>/dev/null || true
