TARGET := iphone:clang:16.2
INSTALL_TARGET_PROCESSES = WhatsApp WhatsAppBusiness
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WALiquidGlassRyuk

RYUKGRAM_SRC_FILES := $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

$(TWEAK_NAME)_FILES = $(RYUKGRAM_SRC_FILES)

# SideStore-only: legacy sideload compat patch (keychain, app groups).
ifdef SIDESTORE
	$(TWEAK_NAME)_FILES += modules/SideloadPatch/SideloadPatch.xm
endif

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore AVFoundation AVKit UniformTypeIdentifiers CoreLocation MapKit
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode)
ifdef SIDELOAD
	$(TWEAK_NAME)_SUBPROJECTS += modules/flexing
endif