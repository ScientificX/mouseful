#ifndef MOUSELESS_MACOS_H
#define MOUSELESS_MACOS_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ML_EVT_NONE = 0,
  ML_EVT_ACTIVATION = 1,
  ML_EVT_KEY = 2
} MLEventType;

typedef struct {
  MLEventType type;
  char key;
} MLEvent;

typedef struct {
  int32_t x;
  int32_t y;
  int32_t w;
  int32_t h;
  char label[16];
} MLGridCell;

/* Initialize NSApplication, overlay, and global event tap.
   Returns 0 on success, -1 if Accessibility permission is missing. */
int mouseless_init(void);

void mouseless_shutdown(void);

const char *mouseless_last_error(void);

int32_t mouseless_screen_width(void);
int32_t mouseless_screen_height(void);

int32_t mouseless_cursor_x(void);
int32_t mouseless_cursor_y(void);

void mouseless_warp_cursor(int32_t x, int32_t y);
void mouseless_click(int32_t button); /* 0=left, 1=right, 2=middle */
void mouseless_beep(void);

void mouseless_show_overlay(const MLGridCell *cells, size_t count);
void mouseless_hide_overlay(void);

/* Block until the next keyboard event (activation or key char). */
void mouseless_wait_event(MLEvent *out);

#ifdef __cplusplus
}
#endif

#endif
