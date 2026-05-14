TARGET := iphone:clang:16.2
INSTALL_TARGET_PROCESSES = WhatsApp
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WAGram

$(TWEAK_NAME)_FILES = $(wildcard src/*.x) $(wildcard src/*.xm) $(wildcard src/*.m) modules/fishhook/fishhook.c

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk