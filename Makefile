ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AXHideJB
AXHideJB_FILES = axhidejb.xm hide.mm
AXHideJB_CFLAGS = -fobjc-arc -std=c++17 -I. -Wno-error
AXHideJB_FRAMEWORKS = Foundation UIKit
AXHideJB_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk