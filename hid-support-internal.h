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

#pragma once

#if defined __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include "hid-support.h"

#define HID_SUPPORT_PORT_NAME "ch.ringwald.hidsupport"

typedef enum hid_event_type {
	TEXT = 1,
	KEY,
	REMOTE,
	MOUSE,
	TOUCH,
	ACCELEROMETER
} hid_event_type_t;

typedef enum hid_mouse_type {
	KEEP_ALIVE = 1,
	REL_MOVE,
	ABS_MOVE
} hid_mouse_type_t;

typedef struct key_event {
    uint16_t modifier;
    uint32_t code;
    uint16_t down;
} key_event_t;

typedef struct remote_action {
    uint16_t down;
    uint16_t action;
} remote_action_t;

typedef struct mouse_event {
    HID_MOUSE_TYPE_t type;
    float x;
    float y;
    uint16_t button;
} mouse_event_t;

typedef struct touche_vent {
	uint16_t  num_touches;
	HID_Touch touches[0];  
} touch_event_t;

typedef struct accelerometer {
    float x;
	float y;
    float z;
} accelerometer_t;

typedef union hid_event_type {
    char   text[0];
    struct KeyEvent      keyEvent;
    struct RemoteAction  remoteAction;
    struct MousePointer  mosuePointer;
    struct Accelerometer accelerometer;   
	struct TouchEvent    touchEvent;
} hid_event_t;
	
#if defined __cplusplus
}
#endif

