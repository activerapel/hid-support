/*
 * Copyright (C) 2010 by Matthias Ringwald
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY MATTHIAS RINGWALD AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL MATTHIAS
 * RINGWALD OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */

	
#import <CoreFoundation/CoreFoundation.h>

#include "../hid-support-internal.h"

static CFMessagePortRef hid_support_message_port = 0;

static int hid_send_message(hid_event_type_t cmd, uint16_t dataLen, uint8_t *data, CFDataRef *resultData){
	// check for port
	if (!hid_support_message_port || !CFMessagePortIsValid(hid_support_message_port)) {
		hid_support_message_port = CFMessagePortCreateRemote(NULL, CFSTR(HID_SUPPORT_PORT_NAME));
	}
	if (!hid_support_message_port) {
		printf("hid_send_message cannot find server" HID_SUPPORT_PORT_NAME "\n");
		return kCFMessagePortIsInvalid;
	}
	// create and send message
	CFDataRef cfData = CFDataCreate(NULL, data, dataLen);
	CFStringRef replyMode = NULL;
	if (resultData) {
		replyMode = kCFRunLoopDefaultMode;
	}
	int result = CFMessagePortSendRequest(hid_support_message_port, cmd, cfData, 1, 1, replyMode, resultData);
	CFRelease(cfData);
	return result;
}

int hid_inject_text(const char * utf8_text){
	return hid_send_message(TEXT, strlen(utf8_text), (uint8_t *) utf8_text, 0);
}

int hid_inject_key_down(uint32_t unicode, uint16_t key_modifier) {
	key_event_t event;
	event.down = 1;
	event.modifier = key_modifier;
	event.unicode = unicode;
	return hid_send_message(KEY, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_key_up(uint32_t unicode){
	key_event_t event;
	event.modifier = 0;
	event.down = 0;
	event.unicode = unicode;
	return hid_send_message(KEY, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_remote_down(uint16_t action) {
	remote_action_t event;
	event.down = 1;
	event.action = action;
	return hid_send_message(KEY, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_remote_up(uint16_t action){
	remote_action_t event;
	event.down = 0;
	event.action = action;
	return hid_send_message(KEY, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_mouse_keep_alive(){
	mouse_event_t event;
	event.type = KEEP_ALIVE;
	return hid_send_message(MOUSE, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_mouse_rel_move(uint8_t buttons, float dx, float dy){
	mouse_event_t event;
	event.type = REL_MOVE;
	event.buttons = buttons;
	event.x = dx;
	event.y = dy;
	return hid_send_message(MOUSE, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_mouse_abs_move(uint8_t buttons, float ax, float ay){
	mouse_event_t event;
	event.type = ABS_MOVE;
	event.buttons = buttons;
	event.x = ax;
	event.y = ay;
	return hid_send_message(MOUSE, sizeof(event), (uint8_t*) &event, 0);
}

int hid_inject_touches(uint8_t num_touches, hid_touch_t *touches){
	if (num_touches > 10) num_touches = 10;
	uint16_t event_size = num_touches * sizeof(hid_touch_t) + sizeof(uint16_t);
	uint8_t event_buffer[event_size];
	touch_event_t *event = (touch_event_t *) event_buffer;
	event->num_touches = num_touches;
	memcpy(event->touches, touches, num_touches * sizeof(hid_touch_t));
	return hid_send_message(TOUCH, event_size, (uint8_t*) event, 0);
}

int hid_inject_accelerometer(float x, float y, float z){
	accelerometer_t event;
	event.x = x;
	event.y = y;
	event.z = z;
	return hid_send_message(ACCELEROMETER, sizeof(event), (uint8_t*) &event, 0);
}
	


