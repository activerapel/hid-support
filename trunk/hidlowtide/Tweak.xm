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
	NSLog(@"hidsupport callback, msg %u", msgid);
    const char *data = (const char *) CFDataGetBytePtr(cfData);
    UInt16 dataLen = CFDataGetLength(cfData);
	char *buffer;
    NSString * text;
    BREvent *event = nil;
	NSDictionary * eventDictionary;
	// have pointers ready
    key_event_t     * key_event;
    remote_action_t * remote_action;
	unichar			  theChar;
    // mouse_event_t   * mouse_event;
	// touch_event_t   * touch_event;
    // accelerometer_t * acceleometer;   

	switch ( (hid_event_type_t) msgid){

		case TEXT:
			// regular text
			if (dataLen == 0 || !data) break;
			// append \0 byte for NSString conversion
			buffer = (char*) malloc( dataLen + 1);
			if (!buffer); break;
			memcpy(buffer, data, dataLen);
			buffer[dataLen] = 0;
			text = [NSString stringWithUTF8String:buffer];
			// NSLog(@"Injecting text: %@", text);
			eventDictionary = [NSDictionary dictionaryWithObject:text forKey:@"kBRKeyEventCharactersKey"];
			event = [$BREvent eventWithAction:BRRemoteActionKey value:1 atTime:7400.0 originator:5 eventDictionary:eventDictionary allowRetrigger:1];
			[$BRWindow dispatchEvent:event];
			free(buffer);
			break;
			
		case KEY:
			// individual key events
			key_event = (key_event_t*) data;
			key_event->down = key_event->down ? 1 : 0;
			// NSLog(@"Injecting single char: %C (%x), down: %u", key_event->unicode, key_event->unicode, key_event->down);
			theChar = key_event->unicode;
			text = [NSString stringWithCharacters:&theChar length:1];
			eventDictionary = [NSDictionary dictionaryWithObject:text forKey:@"kBRKeyEventCharactersKey"];
			event = [$BREvent eventWithAction:BRRemoteActionKey value:key_event->down atTime:7400.0 originator:5 eventDictionary:eventDictionary allowRetrigger:1];
			[$BRWindow dispatchEvent:event];
			break;
			
		case REMOTE:
			// simple remote actions
			remote_action = (remote_action_t*) data;
			// NSLog(@"Injecting action: %d down: %u", remote_action->down, remote_action->action);
			remote_action->down = remote_action->down ? 1 : 0;
			event = [$BREvent eventWithAction:remote_action->action value:remote_action->down atTime:7400.0 originator:5 eventDictionary:nil allowRetrigger:1];
			[$BRWindow dispatchEvent:event];
			break;
			
		default:
			NSLog(@"HID_SUPPORT_PORT_NAME server, msgid %u not supported", msgid);
	}
	return NULL;  // as stated in header, both data and returnData will be released for us after callback returns
}

#if 0
%hook BRWindow
+ (BOOL)dispatchEvent:(id)event { 
    NSLog(@"dispatchEvent with event:%@", event);
    return %orig;
}
%end
#endif

%hook LTAppDelegate
-(void)applicationDidFinishLaunching:(id)fp8 {
NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    CFMessagePortRef local = CFMessagePortCreateLocal(NULL, CFSTR(HID_SUPPORT_PORT_NAME), myCallBack, NULL, false);
    CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(NULL, local, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    [pool release]; 
    %log;
    %orig;
    // %orig does not return
}
%end
