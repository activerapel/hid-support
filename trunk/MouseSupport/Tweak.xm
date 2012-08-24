/**
 * New maintainer/developer: Matthias Ringwald (mringwal)
 * see README for details
 *
 * Current version: svn.r204
 *
 */

/**
 * Name: Mouse
 * Type: iPhone OS 3.x SpringBoard extension (MobileSubstrate-based)
 * Description: Support for controlling touches externally;
 *              translates of position/clicks, provides a visible mouse pointer
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-05-22 19:41:54
 */

/**
 * Copyright (C) 2009-2010  Lance Fetters (aka. ashikase)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#include <substrate.h>
#include <mach/mach.h>

#import <GraphicsServices/GraphicsServices.h>
#import <QuartzCore/QuartzCore.h>

typedef struct {
    float x, y;
    int buttons;
    BOOL absolute;
} MouseEvent;

typedef enum {
    MouseMessageTypeEvent,
    MouseMessageTypeSetEnabled,
} MouseMessageType;

@interface CAWindowServer : NSObject
@property(readonly, assign) NSArray *displays;
+ (id)serverIfRunning;
@end

@interface CAWindowServerDisplay : NSObject
- (unsigned)clientPortAtPosition:(CGPoint)position;
@end

@interface CAContext : NSObject
@end

typedef struct {} Context;

@interface CAContextImpl : CAContext
- (Context *)renderContext;
@end

@interface SpringBoard : UIApplication
- (void)resetIdleTimerAndUndim:(BOOL)fp8;
@end

@interface SBAwayController : NSObject
+ (id)sharedAwayController;
- (BOOL)undimsDisplay;
- (id)awayView;
- (void)lock;
- (void)_unlockWithSound:(BOOL)fp8;
- (void)unlockWithSound:(BOOL)fp8;
- (void)unlockWithSound:(BOOL)fp8 alertDisplay:(id)fp12;
- (void)loadPasscode;
- (id)devicePasscode;
- (BOOL)isPasswordProtected;
- (void)activationChanged:(id)fp8;
- (BOOL)isDeviceLockedOrBlocked;
- (void)setDeviceLocked:(BOOL)fp8;
- (void)applicationRequestedDeviceUnlock;
- (void)cancelApplicationRequestedDeviceLockEntry;
- (BOOL)isBlocked;
- (BOOL)isPermanentlyBlocked:(double *)fp8;
- (BOOL)isLocked;
- (void)attemptUnlock;
- (BOOL)isAttemptingUnlock;
- (BOOL)attemptDeviceUnlockWithPassword:(id)fp8 alertDisplay:(id)fp12;
- (void)cancelDimTimer;
- (void)restartDimTimer:(float)fp8;
- (id)dimTimer;
- (BOOL)isDimmed;
- (void)finishedDimmingScreen;
- (void)dimScreen:(BOOL)fp8;
- (void)undimScreen;
- (void)userEventOccurred;
- (void)activate;
- (void)deactivate;
@end

// #if !defined(__IPHONE_3_2) || __IPHONE_3_2 > __IPHONE_OS_VERSION_MAX_ALLOWED
typedef enum {
    UIUserInterfaceIdiomPhone,           // iPhone and iPod touch style UI
    UIUserInterfaceIdiomPad,             // iPad style UI
} UIUserInterfaceIdiom;
@interface UIDevice (privateAPI)
- (BOOL) userInterfaceIdiom;
@end
// #endif

@interface UIView (Private)
@property(assign) CGPoint origin;
@end

@interface UIWindow (Private)
- (void)setHidden:(BOOL)fp8;
@end

@interface UIDevice (Private)
- (BOOL)isWildcat;
@end

@interface UIScreen (fourZeroAndLater)
+(UIScreen*) mainScreen;
@property(nonatomic,readonly) CGFloat scale;
@end


@interface SpringBoard (Mouse)
- (void)mouseUndim;
- (void)setMousePointerEnabled:(BOOL)enabled;
- (void)handleMouseEventAtPoint:(CGPoint)point buttons:(int)buttons;
- (void)handleMouseEventWithX:(float)x Y:(float)y buttons:(int)buttons;
- (void)moveMousePointerToPoint:(CGPoint)point;
- (CGPoint)mouseInterfacePointForDisplayPoint:(CGPoint)point;
- (CGPoint)mouseLocation;
@end

#define APP_ID "jp.ashikase.mousesupport"
#define MACH_PORT_NAME APP_ID

static CFDataRef mouseCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef cfData, void *info);

// View objects for the pointer
static UIWindow *mouseWin = nil;
static UIImageView *mouseView = nil;
static Context *mouseRenderContext = NULL;
static CGSize mouseImageSize;

// Screen limits (portrait)
static float screen_width = 0, screen_height = 0;

// bounds for current orientation
static float max_x = 0, max_y = 0;
static CGPoint lastMouseLocation = { 0, 0};

// Define button values
#define BUTTON_PRIMARY   0x01
#define BUTTON_SECONDARY 0x02
#define BUTTON_TERTIARY  0x04
static BOOL swapButtonsTwoThree = NO;
static BOOL swapButtonsOneTwo = NO;
static char buttonClick = BUTTON_PRIMARY;
static char buttonHome  = BUTTON_SECONDARY;
static char buttonLock  = BUTTON_TERTIARY;

// cloaking works
static BOOL cloakingSupport = NO;

// iPad support
static BOOL is_iPad = NO;

// iOS 5
static BOOL is_50 = NO;

// Window server uses bitmap coordinates
static float retina_factor = 1.0f;

// Pointer orientation
static int orientation_ = 0;

// Speed is used with relative mouse positioning
static float mouseSpeed = 1.0f;

static Class $SBAwayController = objc_getClass("SBAwayController");

//==============================================================================

// NOTE: Swiped from Jay Freeman (saurik)'s Veency
static mach_port_t (*GSTakePurpleSystemEventPort)(void);
static bool PurpleAllocated;

//==============================================================================

static void loadPreferences()
{
    // defaults
    swapButtonsOneTwo = NO;
    swapButtonsTwoThree = NO;
    mouseSpeed = 1.0f;

    NSArray *keys = [NSArray arrayWithObjects:@"swapButtonsOneTwo", @"swapButtonsTwoThree", @"mouseSpeed", nil];
    NSDictionary *dict = (NSDictionary *)CFPreferencesCopyMultiple((CFArrayRef)keys, CFSTR(APP_ID),
        kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    NSLog(@"MouseSupport prefs %@", dict);
    if (dict) {
        NSArray *values = [dict objectsForKeys:keys notFoundMarker:[NSNull null]];
        id obj;

        obj = [values objectAtIndex:0];
        if ([obj isKindOfClass:[NSNumber class]])
            swapButtonsOneTwo = [obj boolValue];

        obj = [values objectAtIndex:1];
        if ([obj isKindOfClass:[NSNumber class]])
            swapButtonsTwoThree = [obj boolValue];

        obj = [values objectAtIndex:2];
        if ([obj isKindOfClass:[NSNumber class]])
            mouseSpeed = [obj floatValue];

        [dict release];
    }

    // set mouse buttons
    if (swapButtonsOneTwo) {
        buttonClick = BUTTON_SECONDARY;
        if (swapButtonsTwoThree){
            buttonHome = BUTTON_TERTIARY;
            buttonLock = BUTTON_PRIMARY;
        } else {
            buttonHome = BUTTON_PRIMARY;
            buttonLock = BUTTON_TERTIARY;
        }
    } else {
        buttonClick = BUTTON_PRIMARY;
        if (swapButtonsTwoThree){
            buttonHome = BUTTON_TERTIARY;
            buttonLock = BUTTON_SECONDARY;
        } else {
            buttonHome = BUTTON_SECONDARY;
            buttonLock = BUTTON_TERTIARY;
        }
    }
}

static void reloadPreferences(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    // NOTE: Must synchronize preferences from disk
    CFPreferencesAppSynchronize(CFSTR(APP_ID));
    loadPreferences();
}

static void updateOrientation()
{
    mouseView.transform = CGAffineTransformMakeRotation(orientation_ * M_PI / 180.0f);

    // Update screen limits
    switch (orientation_){
        case  90:
        case -90: 
        case 270:
            max_x = screen_height - 1;;
            max_y = screen_width - 1;
            break;
        default:    // 0/180/...
            max_x = screen_width - 1;
            max_y = screen_height - 1;;
            break;
    }
}

#define QuartzCore "/System/Library/Frameworks/QuartzCore.framework/QuartzCore"
// NOTE: The mouse pointer image interferes with hit tests as the pointer
//       covers the point being clicked. To work around this, make hit tests
//       on the render context of the mouse pointer always return NULL;

// CA::Render::Context::hit_test(CGPoint, unsigned int) 
MSHook(void *, _ZN2CA6Render7Context8hit_testE7CGPointj, Context *context, CGPoint point, unsigned int unknown)
{
    return (context == mouseRenderContext) ? NULL : __ZN2CA6Render7Context8hit_testE7CGPointj(context, point, unknown);
}
// CA::Render::Context::hit_test(CA::Vec2<float> const&, unsigned int)
MSHook(void *, _ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj, Context *context, void * point, unsigned int unknown)
{
    return (context == mouseRenderContext) ? NULL : __ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj(context, point, unknown);
}

%hook SpringBoard

%new(v@:)
-(void)mouseUndim {
     // from BTstack Keyboard                    
    bool wasDimmed = [[$SBAwayController sharedAwayController] isDimmed ];
    bool wasLocked = [[$SBAwayController sharedAwayController] isLocked ];
    
    // prevent dimming - from BTstack Keyboard
    [self resetIdleTimerAndUndim:true];
    
    // handle user unlock
    if ( wasDimmed || wasLocked ){
        [[$SBAwayController sharedAwayController] attemptUnlock];
        [[$SBAwayController sharedAwayController] unlockWithSound:NO];
    }
}


%new(v@:c)
- (void)setMousePointerEnabled:(BOOL)enabled
{
    if (enabled) {

        [self mouseUndim];

        if (mouseWin == nil) {
            // Create a transparent window that will float above everything else
            // NOTE: The window level value was not chosen scientifically; it is
            //       assumed to be large enough (the largest values used by
            //       SpringBoard seen so far have been less than 2000).
            mouseWin = [[UIWindow alloc] initWithFrame:CGRectZero];
            mouseWin.windowLevel = 3000;

            [mouseWin setUserInteractionEnabled:NO];
            [mouseWin setHidden:NO];

            // Create a mouse pointer and add to the window
            mouseView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MousePointer.png"]];
            mouseImageSize = mouseView.bounds.size;
            NSLog(@"image size %f,%f", mouseImageSize.width, mouseImageSize.height);
            
            [mouseWin addSubview:mouseView];
            
            // Set the initial orientation and limits for the pointer
            updateOrientation();

            if (cloakingSupport) {
                // Store the address of the window's render context to cloak it from clicks
                CAContextImpl *&_layerContext = MSHookIvar<CAContextImpl *>(mouseWin, "_layerContext");
                if (&_layerContext != NULL)
                    mouseRenderContext = [_layerContext renderContext];
            }
        }
    } else {
        mouseRenderContext = NULL;
        [mouseView release];
        mouseView = nil;
        [mouseWin release];
        mouseWin = nil;
    }
}

// handles size of mouse pointer
%new(v@:{CGPoint=ff})
-(void)moveMousePointerToPoint:(CGPoint)point
{
    lastMouseLocation = point;

    // Get pos of on-screen pointer
    CGPoint mousePoint;
    switch(orientation_){
        default:
        case 0:
            mousePoint.x = point.x;
            mousePoint.y = point.y;
            break;
        case 90:
            mousePoint.x = point.x - mouseImageSize.height;
            mousePoint.y = point.y;
            break;
        case 180:
            mousePoint.x = point.x - mouseImageSize.width;
            mousePoint.y = point.y - mouseImageSize.height;
            break;
        case -90: // Home button left
        case 270: 
            mousePoint.x = point.x;
            mousePoint.y = point.y - mouseImageSize.width;
            break;
    }
    mouseView.origin = mousePoint;
}

%new({CGPoint=ff}@:)
- (CGPoint)mouseLocation{
    return lastMouseLocation;
}

%new({CGPoint=ff}@:{CGPoint=ff})
-(CGPoint)mouseInterfacePointForDisplayPoint:(CGPoint)point {

    // Translate the point to match the current orientation
    float temp;
    switch (orientation_) {
        case 0: // Home button bottom
            break;
        case 90: // Home button right
            temp = point.x;
            point.x = screen_width - point.y;
            point.y = temp;
            break;
        case -90: // Home button left
            temp = point.x;
            point.x = point.y;
            point.y = screen_height - temp;
            break;
        case 180: // Home button top
            point.x = screen_width - point.x;
            point.y = screen_height - point.y;
            break;
        default:
            break;
    }
    return point;
}

// NOTE: Swiped and modified from Jay Freeman (saurik)'s Veency
%new(v@:{CGPoint=ff}i)
- (void)handleMouseEventAtPoint:(CGPoint)point buttons:(int)buttons
{
    // NSLog(@"handleMouseEventAtPoint %f andY %f", point.x, point.y);

    // NOTE: Must store button state for comparision, port for
    //       mouse dragging and button up
    static int buttons_;

    int diff = buttons_ ^ buttons;
    bool twas((buttons_ & buttonClick) != 0);
    bool tis ((buttons  & buttonClick) != 0);
    buttons_ = buttons;

    // Round point values to prevent subpixel coordinates
    point.x = roundf(point.x);
    point.y = roundf(point.y);

    // Get pos of on-screen pointer
    [self moveMousePointerToPoint:point];

    // Check for mouse button events
    mach_port_t purple(0);

    if ((diff & 0x10) != 0) {
        // Simulate Headset button press
        struct GSEventRecord record;

        memset(&record, 0, sizeof(record));

        record.type = (buttons & 0x10) != 0 ?
            GSEventTypeHeadsetButtonDown :
            GSEventTypeHeadsetButtonUp;

        record.timestamp = GSCurrentEventTimestamp();

        GSSendSystemEvent(&record);
    }

    if ((diff & buttonHome) != 0) {
        // Simulate Home button press
        struct GSEventRecord record;

        memset(&record, 0, sizeof(record));

        record.type = (buttons & buttonHome) != 0 ?
            GSEventTypeMenuButtonDown :
            GSEventTypeMenuButtonUp;

        record.timestamp = GSCurrentEventTimestamp();

        GSSendSystemEvent(&record);
    }

    if ((diff & buttonLock) != 0) {
        // Simulate Sleep/Wake button press
        struct GSEventRecord record;

        memset(&record, 0, sizeof(record));

        record.type = (buttons & buttonLock) != 0 ?
            GSEventTypeLockButtonDown :
            GSEventTypeLockButtonUp;

        record.timestamp = GSCurrentEventTimestamp();

        GSSendSystemEvent(&record);
    }

    if (twas != tis || tis) {
        // Main (left button) state changed, or was dragged
        struct {
            struct GSEventRecord record;
            struct {
                struct GSEventRecordInfo info;
                struct GSPathInfo path;
            } data;
        } event;

        memset(&event, 0, sizeof(event));

        event.record.type = GSEventTypeMouse;
        event.record.locationInWindow = point;
        event.record.timestamp = GSCurrentEventTimestamp();
        event.record.size = sizeof(event.data);

        event.data.info.handInfo.type = twas == tis ?
            GSMouseEventTypeDragged :
        tis ?
            GSMouseEventTypeDown :
            GSMouseEventTypeUp;

        event.data.info.handInfo.x34 = 0x1;
        event.data.info.handInfo.x38 = tis ? 0x1 : 0x0;

        if (is_50){
            event.data.info.x52 = 1;
        } else {
            event.data.info.pathPositions = 1;
        }

        event.data.path.x00 = 0x01;
        event.data.path.x01 = 0x02;
        event.data.path.x02 = tis ? 0x03 : 0x00;
        event.data.path.position = event.record.locationInWindow;

        if (!cloakingSupport){
            if (point.x >= 1.0) point.x -= 1.0f;
            if (point.y >= 1.0) point.y -= 1.0f;
        }

        static mach_port_t port_(0);
        if (twas != tis && tis) {
            // Button down and was not down before
            port_ = 0;

            // NSLog(@"point %f,%f - mouseView.origin %f,%f (o=%d)", point.x, point.y, mouseView.origin.x, mouseView.origin.y, orientation_);
            if (CAWindowServer *server = [CAWindowServer serverIfRunning]) {
                NSArray *displays([server displays]);
                if (displays != nil && [displays count] != 0) {
                    if (CAWindowServerDisplay *display = [displays objectAtIndex:0]) {
                        CGPoint point2;
                        if (is_iPad) {
                            point2.x = screen_height - 1 - point.y;
                            point2.y = point.x;
                        } else {
                            point2.x = point.x;
                            point2.y = point.y;
                        }
                        point2.x *= retina_factor;
                        point2.y *= retina_factor;
                        port_ = [display clientPortAtPosition:point2];
                        NSLog(@"orientation %d, screen (%f, %f), coord (%f, %f), coord2 (%f,%f) -> port %x", orientation_, screen_width, screen_height, point.x, point.y, point2.x, point2.y, (int) port_);
                    }
                }
            }

            if (port_ == 0) {
                // Is SpringBoard
                if (purple == 0)
                    purple = (*GSTakePurpleSystemEventPort)();
                port_ = purple;
            }
        }
        // NSLog(@"point %f,%f - port %p", point.x, point.y, port_);

        GSSendEvent(&event.record, port_);
    }

    if (purple != 0 && PurpleAllocated)
        mach_port_deallocate(mach_task_self(), purple);
}

// NOTE: Values of x and y are relative to the previous value, not absolute
%new(v@:{CGPoint=ff}i)
- (void)handleMouseEventWithX:(float)x Y:(float)y buttons:(int)buttons
{
    static float x_ = 0, y_ = 0;
    
    // NSLog(@"handleMouseEventWithX %f andY %f (max: %f, %f)", x, y, max_x, max_y); 
    x_ += x * mouseSpeed;
    x_ = (x_ < 0) ? 0 : x_;
    x_ = (x_ > max_x) ? max_x : x_;

    y_ += y * mouseSpeed;
    y_ = (y_ < 0) ? 0 : y_;
    y_ = (y_ > max_y) ? max_y : y_;

    CGPoint point = [self mouseInterfacePointForDisplayPoint:CGPointMake(x_, y_)];

    // NSLog(@"handleMouseEventWithX %f/%f", point.x, point.y);
    [self handleMouseEventAtPoint:point buttons:buttons];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;

    // Apply settings
    // FIXME: Read from preferences
    loadPreferences();

    // Add observer for changes made to preferences
    CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, reloadPreferences, CFSTR(APP_ID"-settings"),
            NULL, 0);

    // Setup a mach port for receiving mouse events from outside of SpringBoard
    // NOTE: Using kCFRunLoopDefaultMode causes issues when dragging SpringBoard's
    //       scrollview; why kCFRunLoopCommonModes fixes the issue, I do not know.
    CFMessagePortRef local = CFMessagePortCreateLocal(NULL, CFSTR(MACH_PORT_NAME), mouseCallBack, NULL, NULL);
    CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, local, 0);
    //CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);

    // Get initial screen size
    // FIXME: Consider adding support for TVOut* users
    CGRect rect = [[UIScreen mainScreen] bounds];
    screen_width = rect.size.width;
    screen_height = rect.size.height;
    max_x = screen_width - 1;
    max_y = screen_height - 1;
    NSLog(@"Initial screen size: %f x %f", max_x, max_y);
    
    // iPad has rotated framebuffer
    if ([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)]){
        is_iPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    }
}

%end

//==============================================================================

%group GFirmware3x
// NOTE: Only hooked for firmware < 3.2

%hook SpringBoard

- (void)noteUIOrientationChanged:(int)orientation display:(id)display
{
    %orig;

    // Update pointer orientation
    orientation_ = orientation;
    updateOrientation();

   [self moveMousePointerToPoint:lastMouseLocation];
}

// NOTE: no need to detect retina display or iPad 

%end 

%end // GFirmware3x

%group GFirmware32x
// NOTE: Only hooked for firmware >= 3.2

%hook SpringBoard

- (void)noteInterfaceOrientationChanged:(int)orientation
{
    %orig;

    // Update pointer orientation
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            orientation_ = 180;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            orientation_ = -90;
            break;
        case UIInterfaceOrientationLandscapeRight:
            orientation_ = 90;
            break;
        case UIInterfaceOrientationPortrait:
        default:
            orientation_ = 0;
    }

    updateOrientation();
    
   [self moveMousePointerToPoint:lastMouseLocation];
}

-(void)applicationDidFinishLaunching:(id)fp8 {

    %orig;
    
    // iPad has rotated framebuffer
    if ([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)]){
        is_iPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    }

    // handle retina devices (checks for iOS4.x)
    if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)]){
        UIScreen *mainScreen = [UIScreen mainScreen];
        retina_factor = mainScreen.scale;
        NSLog(@" MouseSupport: retina factor %f", retina_factor);
    }
}
%end

%end // GFirmware32x

//==============================================================================

static CFDataRef mouseCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef cfData, void *info)
{
    // orig:
    // static BOOL idleTimerDisabled = NO;

    // NOTE: Handle the most common case first
    if (msgid == MouseMessageTypeEvent) {
        // Handle the mouse event
        if (CFDataGetLength(cfData) == sizeof(MouseEvent)) {
            MouseEvent *event = (MouseEvent *)[(NSData *)cfData bytes];
            if (event != NULL) {
                SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
                if (event->absolute)
                    [springBoard handleMouseEventAtPoint:CGPointMake(event->x, event->y) buttons:event->buttons];
                else
                    [springBoard handleMouseEventWithX:event->x Y:event->y buttons:event->buttons];
                    
                    // from BTstack Keyboard                    
                    bool wasDimmed = [[$SBAwayController sharedAwayController] isDimmed ];
                    bool wasLocked = [[$SBAwayController sharedAwayController] isLocked ];
                    
                    // prevent dimming - from BTstack Keyboard
                    [(SpringBoard *) [UIApplication sharedApplication] resetIdleTimerAndUndim:true];
                    
                    // handle user unlock
                    if ( wasDimmed || wasLocked ){
                        [[$SBAwayController sharedAwayController] attemptUnlock];
                        [[$SBAwayController sharedAwayController] unlockWithSound:NO];
                    }

            }
        }
    } else if (msgid == MouseMessageTypeSetEnabled) {
        // Make sure pointer is visible and matches device orientation
        if (CFDataGetLength(cfData) == sizeof(BOOL)) {
            BOOL *enabled = (BOOL *)[(NSData *)cfData bytes];
            if (enabled != NULL) {
                SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
                [springBoard setMousePointerEnabled:(*enabled)];
            }
        }
    } else {
        NSLog(@"Mouse: Unknown message type: %x", msgid); 
    }

    // Do not return a reply to the caller
	return NULL;
}

//==============================================================================

template <typename Type_>
static inline void lookupSymbol(const char *libraryFilePath, const char *symbolName, Type_ &function)
{
    // Lookup the function
    struct nlist nl[2];
    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *)symbolName;
    nlist(libraryFilePath, nl);

    // Check whether it is ARM or Thumb
    uintptr_t value = nl[0].n_value;
    if ((nl[0].n_desc & N_ARM_THUMB_DEF) != 0)
        value |= 0x00000001;

    function = reinterpret_cast<Type_>(value);
}

__attribute__((constructor)) static void init()
{
    MSHookSymbol(GSTakePurpleSystemEventPort, "GSGetPurpleSystemEventPort");
    if (GSTakePurpleSystemEventPort == NULL) {
        MSHookSymbol(GSTakePurpleSystemEventPort, "GSCopyPurpleSystemEventPort");
        PurpleAllocated = true;
    }

    void * (*_ZN2CA6Render7Context8hit_testE7CGPointj)(Context *, CGPoint, unsigned int);
    lookupSymbol(QuartzCore, "__ZN2CA6Render7Context8hit_testE7CGPointj",   _ZN2CA6Render7Context8hit_testE7CGPointj);
    if (_ZN2CA6Render7Context8hit_testE7CGPointj) {
        MSHookFunction(_ZN2CA6Render7Context8hit_testE7CGPointj, MSHake(_ZN2CA6Render7Context8hit_testE7CGPointj));
        cloakingSupport = YES;
    }
    
    void * (*_ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj)(Context *, void *, unsigned int);
    lookupSymbol(QuartzCore, "__ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj",   _ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj);
    if (!cloakingSupport && _ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj) {
        MSHookFunction(_ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj, MSHake(_ZN2CA6Render7Context8hit_testERKNS_4Vec2IfEEj));
        cloakingSupport = YES;
    }
    
    if (!cloakingSupport){
        NSLog(@"Hit test not found, simulating cloaking support");
    }
    
    Class $SpringBoard = objc_getClass("SpringBoard");
    if (class_getInstanceMethod($SpringBoard, @selector(noteInterfaceOrientationChanged:))) {
        // Firmware >= 3.2
        %init(GFirmware32x);
    } else {
        // Firmware < 3.2
        %init(GFirmware3x);
    }

    if (dlsym(RTLD_DEFAULT, "GSLibraryCopyGenerationInfoValueForKey")){
        is_50 = YES;
    }
    NSLog(@"is_50 = %u");
    
    %init;
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
