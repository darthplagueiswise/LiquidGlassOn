TARGET := iphone:clang:16.2
INSTALL_TARGET_PROCESSES = WhatsApp
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidGlassOn

LIQUIDGLASSON_SRC_FILES = \
	src/Tweak.x \
	src/Menu/WAGramMenuVC.m \
	src/Hooks/WAABPropsObserver.xm \
	src/Hooks/WAEmployeeDogfoodHooks.xm \
	src/Hooks/WALiquidGlassHooks.xm \
	src/Hooks/WASideloadKeychainPatch.xm

$(TWEAK_NAME)_FILES  = $(LIQUIDGLASSON_SRC_FILES) modules/fishhook/fishhook.c

# SideStore-only: sideload keychain / app-group compat patch.
ifdef SIDESTORE
	$(TWEAK_NAME)_FILES += modules/SideloadPatch/WASideloadPatch.xm
endif

$(TWEAK_NAME)_FRAMEWORKS         = UIKit Foundation CoreGraphics Security
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(TWEAK_NAME)_CFLAGS             = \
	-fobjc-arc \
	-Wno-unsupported-availability-guard \
	-Wno-unused-value \
	-Wno-deprecated-declarations \
	-Wno-nullability-completeness \
	-Wno-unused-function \
	-Wno-incompatible-pointer-types \
	-Imodules/fishhook \
	-include src/WAGramPrefix.h

$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk


after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram"
	@cp -f resources/*.json "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/" 2>/dev/null || true
	@for f in resources/*.json.gz; do [ -f "$$f" ] && gzip -dc "$$f" > "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/$$(basename "$$f" .gz)" || true; done
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/docs"
	@cp -f docs/*.md "$(THEOS_STAGING_DIR)/Library/Application Support/WAGram/docs/" 2>/dev/null || true
