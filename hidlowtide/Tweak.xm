/**
 * Text injection and remote simulation
 * mach server: ch.ringwald.hidrelay
 * msg id 0: inject UTF8 text
 * msd id x: send action x
 */
 
#include <objc/runtime.h>
#include "../hid-support-internal.h"

@interface BRWindow : NSObject
+ (BOOL)dispatchEvent:(id)event;    // 0x315d47b5
@end

@interface BREvent : NSObject
+ (id)eventWithAction:(int)action value:(int)value atTime:(double)time originator:(unsigned)originator eventDictionary:(id)dictionary allowRetrigger:(BOOL)retrigger;   // 0x315d54a5
@end

static Class $BREvent  = objc_getClass("BREvent");
static Class $BRWindow = objc_getClass("BRWindow");

static CFDataRef myCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef cfData, void *info) {
    const char *data = (const char *) CFDataGetBytePtr(cfData);
    UInt16 dataLen = CFDataGetLength(cfData);
    NSString * text;
    BREvent *event = nil;
    if (msgid) {
        // simple remote actions
        NSLog(@"Injecting action: %d", msgid);
        event = [$BREvent eventWithAction:msgid value:1 atTime:7400.0 originator:5 eventDictionary:nil allowRetrigger:1];
        [$BRWindow dispatchEvent:event];
        event = [$BREvent eventWithAction:msgid value:0 atTime:7400.0 originator:5 eventDictionary:nil allowRetrigger:1];
        [$BRWindow dispatchEvent:event];
    } else if (dataLen > 0 && data){
        // text entry
        text = [NSString stringWithUTF8String:data];
        NSLog(@"Injecting text: %@", text);
        for (unsigned int i=0; i<[text length]; i++){
            NSString * singleKey = [text substringWithRange:NSMakeRange(i,1)];
            NSDictionary * eventDictionary = [NSDictionary dictionaryWithObject:singleKey forKey:@"kBRKeyEventCharactersKey"];
            event = [$BREvent eventWithAction:BRRemoteActionKey value:1 atTime:7400.0 originator:5 eventDictionary:eventDictionary allowRetrigger:1];
            [$BRWindow dispatchEvent:event];
        }
    }
    return NULL;  // as stated in header, both data and returnData will be released for us after callback returns
}

%hook BRWindow
+ (BOOL)dispatchEvent:(id)event { 
    NSLog(@"dispatchEvent with event:%@", event);
    return %orig;
}
%end

%hook LTAppDelegate
-(void)applicationDidFinishLaunching:(id)fp8 {
NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    CFMessagePortRef local = CFMessagePortCreateLocal(NULL, CFSTR("ch.ringwald.hidrelay"), myCallBack, NULL, false);
    CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, local, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    [pool release]; 
    %log;
    %orig;
    // %orig does not return
}
%end
