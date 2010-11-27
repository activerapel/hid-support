#include <stdint.h>

typedef struct hid_touch {
	float x,
	float y
}  hid_touch_t;

typedef enum hid_key_modifier {
	CMD = 0x01,
	ALT = 0x02
} hid_key_modifier_t;

int hid_inject_text(const char * utf8_text);

int hid_inject_key_down(uint32_t unicode, uint16_t key_modifier);
int hid_inject_key_up(uint32_t unicode);

int hid_inject_remote_down(uint16_t action);
int hid_inject_remote_up(uint16_t action);

int hid_inject_mouse_keep_alive();
int hid_inject_mouse_rel_move(uint8_t buttons, float dx, float dy);
int hid_inject_mouse_abs_move(uint8_t buttons, float ax, float ay);

int hid_inject_touches(uint8_t num_touches, hid_touch_t *touches);

int hid_inject_accelerometer(float x, float y, float z);


