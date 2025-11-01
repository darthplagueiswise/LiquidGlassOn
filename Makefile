ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = WhatsApp WhatsAppSMB

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EnableLiquidGlass
EnableLiquidGlass_FILES = Tweak.xm
EnableLiquidGlass_FRAMEWORKS = UIKit Foundation
EnableLiquidGlass_LIBRARIES = substrate
EnableLiquidGlass_LDFLAGS += -install_name "@executable_path/Frameworks/EnableLiquidGlass.dylib"

include $(THEOS_MAKE_PATH)/tweak.mk
