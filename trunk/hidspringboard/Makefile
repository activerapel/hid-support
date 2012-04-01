include $(THEOS)/makefiles/common.mk

# use latest SDK but use iOS 3.0 as deployment target
export TARGET=iphone:latest:3.0

TWEAK_NAME = hidspringboard
hidspringboard_FILES = Tweak.xm
hidspringboard_CFLAGS = -I../3rdParty
hidspringboard_FRAMEWORKS = UIKit
hidspringboard_PRIVATE_FRAMEWORKS = QuartzCore GraphicsServices
include $(THEOS_MAKE_PATH)/tweak.mk
