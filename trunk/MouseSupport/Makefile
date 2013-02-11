export THEOS=/Projects/iPhone/theos

export ARCHS=armv6

THEOS_PACKAGE_DIR_NAME=debs

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MouseSupport
MouseSupport_FILES = Tweak.xm
MouseSupport_CFLAGS = -I. -I.. -I../../iphone-private-saurik/
MouseSupport_LDFLAGS = -L../_/usr/local/lib/ -lhidsupport
MouseSupport_FRAMEWORKS = UIKit QuartzCore CoreGraphics
MouseSupport_PRIVATE_FRAMEWORKS = GraphicsServices

include $(THEOS_MAKE_PATH)/tweak.mk
