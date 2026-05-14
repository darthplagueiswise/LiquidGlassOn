ARCHS = arm64 arm64e
TARGET = iphone:clang:16.2:14.0
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = WhatsApp WhatsAppBusiness

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WALiquidGlassRyuk

WALiquidGlassRyuk_FILES = src/WASideloadKeychainPatch.xm src/WAEmployeeDogfoodHooks.xm src/WAABPropsObserver.xm src/WALiquidGlassHooks.xm src/WAMenu.xm
WALiquidGlassRyuk_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-objc-property-no-attribute
WALiquidGlassRyuk_FRAMEWORKS = UIKit Security Foundation
WALiquidGlassRyuk_PRIVATE_FRAMEWORKS = MobileCoreServices

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WhatsApp || true"
	install.exec "killall -9 WhatsAppBusiness || true"