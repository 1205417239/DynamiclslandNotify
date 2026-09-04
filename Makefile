TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamiclslandNotify
DynamiclslandNotify_FILES = Tweak.xm
DynamiclslandNotify_CFLAGS = -fobjc-arc
DynamiclslandNotify_FRAMEWORKS = UIKit UserNotifications

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += DynamiclslandNotifyPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
