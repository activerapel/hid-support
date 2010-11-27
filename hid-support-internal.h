#include <stdint.h>

#define HID_SUPPORT_PORT_NAME "ch.ringwald.hidsupport"

#include "hid-support.h"

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
