ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = WhatsApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EnableLiquidGlass
EnableLiquidGlass_FILES = Tweak.xm
EnableLiquidGlass_CFLAGS = -fobjc-arc
EnableLiquidGlass_FRAMEWORKS = UIKit
EnableLiquidGlass_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
