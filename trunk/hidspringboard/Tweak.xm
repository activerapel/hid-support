/**
 * Click injection
 *
 * swiped from and update of Lance Fetter's MouseSupport and Jay Freeman's Veency
 *
 * next steps:
 *   handle device rotation
 *   show mouse cursor - decide on keep-alive
 */
  
#include <objc/runtime.h>
#include <mach/mach_port.h>
#include <mach/mach_init.h>
#include <dlfcn.h>

// kenytm
#import <GraphicsServices/GSEvent.h>

#include "../hid-support-internal.h"

extern "C" uint64_t GSCurrentEventTimestamp(void);
extern "C" GSEventRef _GSCreateSyntheticKeyEvent(UniChar key, BOOL up, BOOL repeating);

// used interface from CAWindowServer & CAWindowServerDisplay
@interface CAWindowServer : NSObject
+ (id)serverIfRunning;
- (id)displays;
@end
@interface CAWindowServerDisplay : NSObject
- (unsigned int)clientPortAtPosition:(struct CGPoint)fp8;
@end

// types for touches
typedef enum __GSHandInfoType2 {
        kGSHandInfoType2TouchDown    = 1,    // first down
        kGSHandInfoType2TouchDragged = 2,    // drag
        kGSHandInfoType2TouchChange  = 5,    // nr touches change
        kGSHandInfoType2TouchFinal   = 6,    // final up
} GSHandInfoType2;

static CFDataRef myCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef cfData, void *info);

// globals

// GS functions
GSEventRef (*$GSEventCreateKeyEvent)(int, CGPoint, CFStringRef, CFStringRef, id, UniChar, short, short);
GSEventRef (*$GSCreateSyntheticKeyEvent)(UniChar, BOOL, BOOL);

// GSEvent being sent
static uint8_t  touchEvent[sizeof(GSEventRecord) + sizeof(GSHandInfo) + sizeof(GSPathInfo)];

// Screen dimension
static float screen_width = 0;
static float screen_height = 0;

// Mouse area (might be rotated)
static float mouse_max_x = 0;
static float mouse_max_y = 0;

// access to system event server
static mach_port_t (*GSTakePurpleSystemEventPort)(void);
static bool PurpleAllocated;
static int Level_;  // < 3.0, 3.0-3.1.x, 3.2+


template <typename Type_>
static void dlset(Type_ &function, const char *name) {
    function = reinterpret_cast<Type_>(dlsym(RTLD_DEFAULT, name));
}

// project GSEventRecord for OS < 3 if needed
void detectOSLevel(){
    if (dlsym(RTLD_DEFAULT, "GSKeyboardCreate")) {
        Level_ = 2;
    } else if (dlsym(RTLD_DEFAULT, "GSEventGetWindowContextId")) {
        Level_ = 1;
    } else {
        Level_ = 0;
    }
}

void FixRecord(GSEventRecord *record) {
    if (Level_ < 1) {
        memmove(&record->windowContextId, &record->windowContextId + 1, sizeof(*record) - (reinterpret_cast<uint8_t *>(&record->windowContextId + 1) - reinterpret_cast<uint8_t *>(record)) + record->infoSize);
    }
}

static float box(float min, float value, float max){
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

static void sendGSEvent(GSEventRecord *eventRecord, CGPoint point){

    mach_port_t port(0);
    mach_port_t purple(0);
    
    if (CAWindowServer *server = [CAWindowServer serverIfRunning]) {
        NSArray *displays([server displays]);
        if (displays != nil && [displays count] != 0){
            if (CAWindowServerDisplay *display = [displays objectAtIndex:0]) {
                port = [display clientPortAtPosition:point];
            }
        }
    }
    
    if (!port) {
        if (!purple) {
            purple = (*GSTakePurpleSystemEventPort)();
        }
        port = purple;
    }
    
    if (port) {
        // FixRecord(eventRecord);
        GSSendEvent(eventRecord, port);
    }
    
    if (purple && PurpleAllocated){
        mach_port_deallocate(mach_task_self(), purple);
    }
}

// decide on GSHandInfoType
static GSHandInfoType getHandInfoType(int touch_before, int touch_now){
    if (!touch_before) {
        return (GSHandInfoType) kGSHandInfoType2TouchDown;
    }
    if (touch_now) {
        return (GSHandInfoType) kGSHandInfoType2TouchChange;
    }
    return (GSHandInfoType) kGSHandInfoType2TouchFinal;
}

static void postMouseEvent(float x, float y, int click){

    static int prev_click = 0;

    CGPoint location = CGPointMake(x, y);

    // structure of touch GSEvent
    struct GSTouchEvent {
        GSEventRecord record;
        GSHandInfo    handInfo;
    } * event = (struct GSTouchEvent*) &touchEvent;
    bzero(touchEvent, sizeof(touchEvent));
    
    // set up GSEvent
    event->record.type = kGSEventHand;
    event->record.windowLocation = location;
    event->record.timestamp = GSCurrentEventTimestamp();
    event->record.infoSize = sizeof(GSHandInfo) + sizeof(GSPathInfo);
    event->handInfo.type = getHandInfoType(prev_click, click);
    event->handInfo.pathInfosCount = 1;
    bzero(&event->handInfo.pathInfos[0], sizeof(GSPathInfo));
    event->handInfo.pathInfos[0].pathIndex     = 1;
    event->handInfo.pathInfos[0].pathIdentity  = 2;
    event->handInfo.pathInfos[0].pathProximity = click ? 0x03 : 0x00;;
    event->handInfo.pathInfos[0].pathLocation  = location;

    // send GSEvent
    sendGSEvent( (GSEventRecord*) event, location);    
}

static void postKeyEvent(int down, unichar unicode){
    CGPoint location = CGPointMake(100, 100);
    CFStringRef string = NULL;
    GSEventRef  event  = NULL;
    GSEventType type = down ? kGSEventKeyDown : kGSEventKeyUp;
    if ($GSEventCreateKeyEvent) {           // >= 3.2 
        string = CFStringCreateWithCharacters(kCFAllocatorDefault, &unicode, 1);
        // NSLog(@"GSEventCreateKeyEvent type %u for %@", type, string);
        event = (*$GSEventCreateKeyEvent)(type, location, string, string, nil, 0, 0, 1);
    } else if ($GSCreateSyntheticKeyEvent && down) { // < 3.2 - no up events
        // NSLog(@"GSCreateSyntheticKeyEvent down %u for %C", down, unicode);
        event = (*$GSCreateSyntheticKeyEvent)(unicode, down, YES);
        GSEventRecord *record((GSEventRecord*) _GSEventGetGSEventRecord(event));
        record->type = kGSEventSimulatorKeyDown;
    } else return;

    // send GSEvent
    sendGSEvent((GSEventRecord*) _GSEventGetGSEventRecord(event), location);
    
    if (string){
        CFRelease(string);
    }
    CFRelease(event);
}

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)fp8 {

    %orig;

    // GraphicsServices used
    MSHookSymbol(GSTakePurpleSystemEventPort, "GSGetPurpleSystemEventPort");
    if (GSTakePurpleSystemEventPort == NULL) {
        MSHookSymbol(GSTakePurpleSystemEventPort, "GSCopyPurpleSystemEventPort");
        PurpleAllocated = true;
    }
	dlset($GSEventCreateKeyEvent, "GSEventCreateKeyEvent");
    dlset($GSCreateSyntheticKeyEvent, "_GSCreateSyntheticKeyEvent");
    detectOSLevel();

    // Setup a mach port for receiving mouse events from outside of SpringBoard
    // NOTE (by ashikase): Using kCFRunLoopDefaultMode causes issues when dragging SpringBoard's
    //       scrollview; why kCFRunLoopCommonModes fixes the issue, I do not know.
    CFMessagePortRef local = CFMessagePortCreateLocal(NULL, CFSTR(HID_SUPPORT_PORT_NAME), myCallBack, NULL, false);
    CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, local, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);

    // Get initial screen size
    // FIXME: Consider adding support for TVOut* users
    CGRect rect = [[UIScreen mainScreen] bounds];
    screen_width = rect.size.width;
    screen_height = rect.size.height;
    mouse_max_x = screen_width - 1;
    mouse_max_y = screen_height - 1;
}
%end

static CFDataRef myCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef cfData, void *info) {

    static float mouse_x = 0;
    static float mouse_y = 0;

    //NSLog(@"hidsupport callback, msg %u", msgid);
    const char *data = (const char *) CFDataGetBytePtr(cfData);
    uint16_t dataLen = CFDataGetLength(cfData);
    char *buffer;
    NSString * text;
    unsigned int i;
    // have pointers ready
    key_event_t     * key_event;
    // remote_action_t * remote_action;
    // unichar           theChar;
    mouse_event_t   * mouse_event;
    // touch_event_t   * touch_event;
    // accelerometer_t * acceleometer;
       
    switch ( (hid_event_type_t) msgid){
        case TEXT:
            // regular text
            if (dataLen == 0 || !data) break;
            // append \0 byte for NSString conversion
            buffer = (char*) malloc(dataLen + 1);
            if (!buffer) {
                break;
            }
            memcpy(buffer, data, dataLen);
            buffer[dataLen] = 0;
            text = [NSString stringWithUTF8String:buffer];
            for (i=0; i< [text length]; i++){
                // NSLog(@"TEXT: sending %C", [text characterAtIndex:i]);
                postKeyEvent(1, [text characterAtIndex:i]);
                postKeyEvent(0, [text characterAtIndex:i]);
            }
            free(buffer);
            break;
            
        case KEY:
            // individual key events
            key_event = (key_event_t*) data;
            key_event->down = key_event->down ? 1 : 0;
            postKeyEvent(key_event->down, key_event->unicode);
            break;
            
        case MOUSE:
            mouse_event = (mouse_event_t*) data;
            if (mouse_event->type != REL_MOVE) break;
            mouse_event->buttons = mouse_event->buttons ? 1 : 0;
            mouse_x = box(0, mouse_x + mouse_event->x, mouse_max_x);
            mouse_y = box(0, mouse_y + mouse_event->y, mouse_max_y);
            // NSLog(@"MOUSE type %u, button %u, dx %f, dy %f", mouse_event->type, mouse_event->buttons, mouse_event->x, mouse_event->y);
            postMouseEvent(mouse_x, mouse_y, mouse_event->buttons);
            break;
            
        default:
            NSLog(@"HID_SUPPORT_PORT_NAME server, msgid %u not supported", msgid);
            break;
    }
    return NULL;  // as stated in header, both data and returnData will be released for us after callback returns
}