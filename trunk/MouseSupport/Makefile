THEOS=/Projects/iPhone/theos

include $(THEOS)/makefiles/common.mk

export SDKVERSION=5.1

TWEAK_NAME = MouseSupport
MouseSupport_FILES = Tweak.xm
MouseSupport_CFLAGS = -I../iphone-private-saurik/ -I.
MouseSupport_FRAMEWORKS = UIKit QuartzCore CoreGraphics
MouseSupport_PRIVATE_FRAMEWORKS = GraphicsServices

include $(THEOS_MAKE_PATH)/tweak.mk
