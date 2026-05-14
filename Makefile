TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := WhatsApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := LiquidGlassOn
LiquidGlassOn_FILES := \
  src/Tweak.xm \
  src/WAUtils.m \
  src/WAKeychainPatch.xm \
  src/WALiquidGlassHooks.xm \
  src/WAEmployeeDogfoodHooks.xm

LiquidGlassOn_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations
LiquidGlassOn_FRAMEWORKS := Foundation UIKit Security
LiquidGlassOn_LIBRARIES := substrate

include $(THEOS_MAKE_PATH)/tweak.mk
