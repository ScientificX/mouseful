#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import "mouseful_macos.h"

#include <pthread.h>
#include <string.h>

/* Cmd+7 activation combo — keycode 26 is the '7' key, checked with Command modifier. */
static const CGKeyCode kActivationKeyCode = 26;
/* Cmd+8 free-range combo — keycode 28 is the '8' key, checked with Command modifier. */
static const CGKeyCode kFreeRangeKeyCode = 28;

typedef struct {
    MLEventType type;
    char key;
} QueuedEvent;

static char g_last_error[256] = {0};

static id g_overlayPanel = nil;
static id g_overlayView = nil;
static CFMachPortRef g_eventTap = NULL;
static CFRunLoopSourceRef g_runLoopSource = NULL;
static CFRunLoopRef g_tapRunLoop = NULL;

static QueuedEvent *g_eventBuffer = NULL;
static size_t g_eventCapacity = 0;
static size_t g_eventHead = 0;
static size_t g_eventTail = 0;
static pthread_mutex_t g_eventMutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_eventCond = PTHREAD_COND_INITIALIZER;

static BOOL g_overlayVisible = NO;
static MLGridCell *g_overlayCells = NULL;
static size_t g_overlayCellCount = 0;
static pthread_mutex_t g_overlayMutex = PTHREAD_MUTEX_INITIALIZER;

static void set_error(const char *msg) {
    strncpy(g_last_error, msg, sizeof(g_last_error) - 1);
    g_last_error[sizeof(g_last_error) - 1] = '\0';
}

static void enqueue_event(MLEventType type, char key) {
    pthread_mutex_lock(&g_eventMutex);
    size_t next = (g_eventTail + 1) % g_eventCapacity;
    if (next == g_eventHead) {
        /* Drop oldest event on overflow. */
        g_eventHead = (g_eventHead + 1) % g_eventCapacity;
    }
    g_eventBuffer[g_eventTail].type = type;
    g_eventBuffer[g_eventTail].key = key;
    g_eventTail = next;
    pthread_cond_signal(&g_eventCond);
    pthread_mutex_unlock(&g_eventMutex);
}

static BOOL dequeue_event(QueuedEvent *out) {
    pthread_mutex_lock(&g_eventMutex);
    while (g_eventHead == g_eventTail) {
        pthread_cond_wait(&g_eventCond, &g_eventMutex);
    }
    *out = g_eventBuffer[g_eventHead];
    g_eventHead = (g_eventHead + 1) % g_eventCapacity;
    pthread_mutex_unlock(&g_eventMutex);
    return YES;
}

static char keycode_to_char(CGKeyCode keycode) {
    static const struct {
        CGKeyCode code;
        char ch;
    } map[] = {
        {0, 'a'},  {1, 's'},  {2, 'd'},  {3, 'f'},  {4, 'h'},  {5, 'g'},
        {6, 'z'},  {7, 'x'},  {8, 'c'},  {9, 'v'},  {11, 'b'},
        {12, 'q'}, {13, 'w'}, {14, 'e'}, {15, 'r'}, {16, 'y'}, {17, 't'},
        {31, 'o'}, {32, 'u'}, {34, 'i'}, {35, 'p'},
        {37, 'l'}, {38, 'j'}, {40, 'k'}, {45, 'n'}, {46, 'm'},
        {49, ' '}, {36, '\r'}, {53, '\x1b'},
    };
    for (size_t i = 0; i < sizeof(map) / sizeof(map[0]); i++) {
        if (map[i].code == keycode) {
            return map[i].ch;
        }
    }
    return 0;
}

@interface MousefulOverlayView : NSView
@end

@implementation MousefulOverlayView

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.10] setFill];
    NSRectFill(self.bounds);

    pthread_mutex_lock(&g_overlayMutex);
    size_t count = g_overlayCellCount;
    MLGridCell *cells = g_overlayCells;
    pthread_mutex_unlock(&g_overlayMutex);

    if (!cells || count == 0) {
        return;
    }

    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:18.0],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:1.0 green:0.2 blue:0.2 alpha:1.0],
    };

    for (size_t i = 0; i < count; i++) {
        MLGridCell cell = cells[i];
        NSRect rect = NSMakeRect(cell.x, cell.y, cell.w, cell.h);

        [[NSColor colorWithCalibratedRed:1.0 green:0.15 blue:0.15 alpha:0.85] setStroke];
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect];
        [path setLineWidth:1.5];
        [path stroke];

        NSString *label = [NSString stringWithUTF8String:cell.label];
        NSSize textSize = [label sizeWithAttributes:attrs];
        NSPoint textOrigin = NSMakePoint(
            cell.x + (cell.w - textSize.width) / 2.0,
            cell.y + (cell.h - textSize.height) / 2.0
        );
        [label drawAtPoint:textOrigin withAttributes:attrs];
    }
}

@end

static void pump_app_events(void) {
    @autoreleasepool {
        for (;;) {
            NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                untilDate:[NSDate distantPast]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (!event) {
                break;
            }
            [NSApp sendEvent:event];
        }
    }
}

static CGEventRef event_tap_callback(CGEventTapProxy proxy,
                                     CGEventType type,
                                     CGEventRef event,
                                     void *userData) {
    (void)proxy;
    (void)userData;

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (g_eventTap) {
            CGEventTapEnable(g_eventTap, true);
        }
        return event;
    }

    if (type != kCGEventKeyDown) {
        return event;
    }

    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

    /* Check for Cmd+7 (grid overlay activation) and Cmd+8 (free-range mode). */
    CGEventFlags flags = CGEventGetFlags(event);
    BOOL cmdHeld = (flags & kCGEventFlagMaskCommand) != 0;

    if (cmdHeld && keycode == kActivationKeyCode) {
        enqueue_event(ML_EVT_ACTIVATION, 0);
        return NULL;
    }
    if (cmdHeld && keycode == kFreeRangeKeyCode) {
        enqueue_event(ML_EVT_FREE_RANGE, 0);
        return NULL;
    }

    /* Capture all recognized keys so the state machine can process them.
       This enables h/j/k/l movement, m for toggle, x/c for clicks,
       space/enter for confirm, esc for cancel, and q for quit. */
    char ch = keycode_to_char(keycode);
    if (ch != 0) {
        enqueue_event(ML_EVT_KEY, ch);
        return NULL;
    }

    return event;
}

static void *event_tap_thread(void *arg) {
    (void)arg;
    g_tapRunLoop = CFRunLoopGetCurrent();
    g_runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, g_eventTap, 0);
    CFRunLoopAddSource(g_tapRunLoop, g_runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(g_eventTap, true);
    CFRunLoopRun();
    return NULL;
}

static int setup_event_tap(void) {
    g_eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        CGEventMaskBit(kCGEventKeyDown),
        event_tap_callback,
        NULL
    );

    if (!g_eventTap) {
        set_error("Failed to create event tap. Grant Accessibility permission.");
        return -1;
    }

    pthread_t thread;
    if (pthread_create(&thread, NULL, event_tap_thread, NULL) != 0) {
        set_error("Failed to start event tap thread.");
        return -1;
    }
    pthread_detach(thread);
    return 0;
}

static void setup_overlay(void) {
    @autoreleasepool {
        NSScreen *screen = [NSScreen mainScreen];
        NSRect frame = [screen frame];

        NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame
                                                    styleMask:NSWindowStyleMaskBorderless
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
        [panel setLevel:NSMainMenuWindowLevel + 20];
        [panel setOpaque:NO];
        [panel setBackgroundColor:[NSColor clearColor]];
        [panel setHasShadow:NO];
        [panel setIgnoresMouseEvents:YES];
        [panel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorStationary |
                                     NSWindowCollectionBehaviorIgnoresCycle];
        [panel setHidesOnDeactivate:NO];

        MousefulOverlayView *view = [[MousefulOverlayView alloc] initWithFrame:frame];
        [panel setContentView:view];

        g_overlayPanel = panel;
        g_overlayView = view;
    }
}

int mouseful_init(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp finishLaunching];

        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options)) {
            set_error("Accessibility permission required for global hotkeys and cursor control.");
            return -1;
        }

        g_eventCapacity = 256;
        g_eventBuffer = calloc(g_eventCapacity, sizeof(QueuedEvent));
        if (!g_eventBuffer) {
            set_error("Out of memory allocating event buffer.");
            return -1;
        }

        setup_overlay();
        return setup_event_tap();
    }
}

void mouseful_shutdown(void) {
    mouseful_hide_overlay();

    if (g_tapRunLoop) {
        CFRunLoopStop(g_tapRunLoop);
    }
    if (g_runLoopSource) {
        CFRunLoopSourceInvalidate(g_runLoopSource);
        CFRelease(g_runLoopSource);
        g_runLoopSource = NULL;
    }
    if (g_eventTap) {
        CFRelease(g_eventTap);
        g_eventTap = NULL;
    }

    free(g_eventBuffer);
    g_eventBuffer = NULL;

    pthread_mutex_lock(&g_overlayMutex);
    free(g_overlayCells);
    g_overlayCells = NULL;
    g_overlayCellCount = 0;
    pthread_mutex_unlock(&g_overlayMutex);
}

const char *mouseful_last_error(void) {
    return g_last_error;
}

int32_t mouseful_screen_width(void) {
    @autoreleasepool {
        return (int32_t)[NSScreen mainScreen].frame.size.width;
    }
}

int32_t mouseful_screen_height(void) {
    @autoreleasepool {
        return (int32_t)[NSScreen mainScreen].frame.size.height;
    }
}

int32_t mouseful_cursor_x(void) {
    CGEventRef ev = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(ev);
    CFRelease(ev);
    return (int32_t)p.x;
}

int32_t mouseful_cursor_y(void) {
    CGEventRef ev = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(ev);
    CFRelease(ev);
    return (int32_t)p.y;
}

void mouseful_warp_cursor(int32_t x, int32_t y) {
    CGWarpMouseCursorPosition(CGPointMake((CGFloat)x, (CGFloat)y));
}

void mouseful_click(int32_t button) {
    CGMouseButton btn = kCGMouseButtonLeft;
    CGEventType down = kCGEventLeftMouseDown;
    CGEventType up = kCGEventLeftMouseUp;

    if (button == 1) {
        btn = kCGMouseButtonRight;
        down = kCGEventRightMouseDown;
        up = kCGEventRightMouseUp;
    } else if (button == 2) {
        btn = kCGMouseButtonCenter;
        down = kCGEventOtherMouseDown;
        up = kCGEventOtherMouseUp;
    }

    CGPoint pos = CGPointMake(mouseful_cursor_x(), mouseful_cursor_y());
    CGEventRef downEvent = CGEventCreateMouseEvent(NULL, down, pos, btn);
    CGEventRef upEvent = CGEventCreateMouseEvent(NULL, up, pos, btn);
    CGEventPost(kCGHIDEventTap, downEvent);
    CGEventPost(kCGHIDEventTap, upEvent);
    CFRelease(downEvent);
    CFRelease(upEvent);
}

void mouseful_beep(void) {
    NSBeep();
}

void mouseful_show_overlay(const MLGridCell *cells, size_t count) {
    @autoreleasepool {
        pthread_mutex_lock(&g_overlayMutex);
        free(g_overlayCells);
        g_overlayCellCount = count;
        if (count > 0) {
            g_overlayCells = malloc(count * sizeof(MLGridCell));
            memcpy(g_overlayCells, cells, count * sizeof(MLGridCell));
        } else {
            g_overlayCells = NULL;
        }
        pthread_mutex_unlock(&g_overlayMutex);

        g_overlayVisible = YES;

        NSScreen *screen = [NSScreen mainScreen];
        NSRect frame = [screen frame];
        [(NSPanel *)g_overlayPanel setFrame:frame display:YES];
        [(MousefulOverlayView *)g_overlayView setFrame:frame];
        [(MousefulOverlayView *)g_overlayView setNeedsDisplay:YES];
        [(NSPanel *)g_overlayPanel orderFrontRegardless];
        pump_app_events();
    }
}

void mouseful_hide_overlay(void) {
    @autoreleasepool {
        g_overlayVisible = NO;
        if (g_overlayPanel) {
            [(NSPanel *)g_overlayPanel orderOut:nil];
            pump_app_events();
        }
        pthread_mutex_lock(&g_overlayMutex);
        free(g_overlayCells);
        g_overlayCells = NULL;
        g_overlayCellCount = 0;
        pthread_mutex_unlock(&g_overlayMutex);
    }
}

void mouseful_wait_event(MLEvent *out) {
    QueuedEvent queued;
    dequeue_event(&queued);
    pump_app_events();

    out->type = queued.type;
    out->key = queued.key;
}
