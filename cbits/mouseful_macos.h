#ifndef MOUSEFUL_MACOS_H
#define MOUSEFUL_MACOS_H

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
int mouseful_init(void);

void mouseful_shutdown(void);

const char *mouseful_last_error(void);

int32_t mouseful_screen_width(void);
int32_t mouseful_screen_height(void);

int32_t mouseful_cursor_x(void);
int32_t mouseful_cursor_y(void);

void mouseful_warp_cursor(int32_t x, int32_t y);
void mouseful_click(int32_t button); /* 0=left, 1=right, 2=middle */
void mouseful_beep(void);

void mouseful_show_overlay(const MLGridCell *cells, size_t count);
void mouseful_hide_overlay(void);

/* Block until the next keyboard event (activation or key char). */
void mouseful_wait_event(MLEvent *out);

#ifdef __cplusplus
}
#endif

#endif
