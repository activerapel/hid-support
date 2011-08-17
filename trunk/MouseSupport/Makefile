export GO_EASY_ON_ME = 1

TWEAK_NAME = MouseSupport
MouseSupport_OBJCC_FILES = Tweak.mm
MouseSupport_LDFLAGS = -L.
MouseSupport_CFLAGS = -I../iphone-private-saurik/ -F$(SYSROOT)/System/Library/PrivateFrameworks -F$(SYSROOT)/System/Library/CoreServices -I.
MouseSupport_FRAMEWORKS = UIKit QuartzCore CoreGraphics
MouseSupport_PRIVATE_FRAMEWORKS = GraphicsServices

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
