ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk
TWEAK_NAME = DynamicIslandCore
DynamicIslandCore_FILES = Tweak.xm
DynamicIslandCore_CFLAGS = -fobjc-arc
DynamicIslandCore_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
