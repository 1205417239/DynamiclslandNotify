TARGET := iphone:clang:latest:15.0
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicIslandNotify

DynamicIslandNotify_FILES = Tweak.xm
DynamicIslandNotify_CFLAGS = -fobjc-arc
DynamicIslandNotify_FRAMEWORKS = UIKit UserNotifications

include $(THEOS_MAKE_PATH)/tweak.mk
