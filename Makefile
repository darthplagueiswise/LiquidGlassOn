TARGET := iphone:clang:16.2
INSTALL_TARGET_PROCESSES = WhatsApp
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WAGram

WAGR_SRC := $(shell find src -type f \( -name "*.x" -o -name "*.xm" -o -name "*.m" \))

$(TWEAK_NAME)_FILES = $(WAGR_SRC) modules/fishhook/fishhook.c

ifdef SIDESTORE
    $(TWEAK_NAME)_FILES += modules/SideloadPatch/WASideloadPatch.xm
endif

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -include src/WAGramPrefix.h -Wno-deprecated-declarations
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

include $(THEOS_MAKE_PATH)/tweak.mk
