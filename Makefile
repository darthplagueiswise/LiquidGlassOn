TARGET := iphone:clang:16.2:15.0
INSTALL_TARGET_PROCESSES = WhatsApp
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidGlassOn

LIQUIDGLASSON_SRC_FILES := $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \))

$(TWEAK_NAME)_FILES = $(LIQUIDGLASSON_SRC_FILES) modules/fishhook/fishhook.c
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security QuartzCore
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -include src/WAPrefix.h
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none
$(TWEAK_NAME)_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
