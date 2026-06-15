# Known Bugs

## 1. ESC Cannot Cancel a Right-Click / Dismiss Context Menu

**Severity:** Medium  
**Status:** Open

**Description:**
When a right-click fires, macOS displays a native context menu. Pressing `ESC` should dismiss that menu and return the application to base `Idle` mode. However, this doesn't work for two reasons:

1. **Event tap swallows ESC:** The native event tap (`cbits/mouseful_macos.m`, line 189-193) captures all recognized key events and returns `NULL`, so `ESC` never reaches macOS — the context menu stays open.

2. **No state tracking:** In `Idle` mode, `Cancel` (ESC) just produces a `Beep` via the catch-all handler. There's no way for the state machine to distinguish "ESC after a right-click" from "ESC at any other time in Idle."

**Expected Behavior:**
After a right-click is performed, pressing `ESC` should:
- Pass through to macOS so it can dismiss the native context menu
- Transition the application state to `Idle`

**Relevant Code:**
- `cbits/mouseful_macos.m` — `event_tap_callback` function, lines 189-193: all recognized keys are captured and returned as `NULL`
- `cbits/mouseful_macos.m` — `keycode_to_char` function, line 79: keycode 53 maps to `'\x1b'` (ESC)
- `src/Mouseful/Core/State.hs` — `step` function: `(Idle, Cancel)` is not explicitly matched, falls through to `_ -> (st, [Beep])`

**Possible Approach:**
Two changes needed:

**A) C event tap** — Pass ESC through to macOS when overlay is not visible:

```c
// In event_tap_callback, after keycode_to_char:
char ch = keycode_to_char(keycode);
if (ch != 0) {
    if (ch == '\x1b' && !g_overlayVisible) {
        enqueue_event(ML_EVT_KEY, ch);
        return event;  // let macOS also process ESC (dismiss context menu, etc.)
    }
    enqueue_event(ML_EVT_KEY, ch);
    return NULL;
}
```

**B) Haskell state machine** — Handle `Cancel` in `Idle` as a no-op transition to `Idle`:

```haskell
-- In step:
(Idle, Cancel) -> (st, [])   -- reset to Idle, no beep
```

Or alternatively, track whether the last action was a right-click and only suppress the beep in that case.

---

## 2. Grid Multi-Key Selection Resolves Too Eagerly

**Severity:** High  
**Status:** Open

**Description:**
When typing multi-key sequences in the grid overlay, shorter exact matches are resolved immediately, preventing the user from typing the full sequence. For example, if the grid has cells labeled `"a"` and `"as"`, typing `"a"` immediately resolves to cell `"a"` — the user never gets a chance to type `"s"` to reach cell `"as"`.

**Relevant Code:**
- `src/Mouseful/Core/State.hs` — `resolveSelection` function, lines 168-177:

```haskell
resolveSelection :: [LabeledCell] -> [Key] -> SelectionResult
resolveSelection cells typed =
  case filter ((== typed) . cellLabel) cells of
    [cell] -> Resolved cell          -- BUG: resolves even when longer labels exist
    _ ->
      let matches = filter ((typed `isPrefixOf`) . cellLabel) cells
       in case matches of
            [] -> NoMatch
            [cell] -> Resolved cell   -- BUG: resolves when only one prefix match remains
            _ -> Incomplete typed
```

**Root Cause:**
The first branch checks for exact match (`== typed`) and resolves immediately. It does not check whether there are *other* cells whose labels have `typed` as a proper prefix. Example: labels `["a", "as", "ad"]` — typing `'a'` immediately resolves to `"a"`, the user can never reach `"as"` or `"ad"`.

**Possible Approach:**
```haskell
resolveSelection :: [LabeledCell] -> [Key] -> SelectionResult
resolveSelection cells typed =
  let exactMatches = filter ((== typed) . cellLabel) cells
      prefixMatches = filter ((typed `isPrefixOf`) . cellLabel) cells
      hasLongerMatches = any ((> length typed) . length . cellLabel) prefixMatches
  in case (exactMatches, prefixMatches) of
    ([cell], False) -> Resolved cell   -- exact match, no longer labels share prefix
    ([cell], True)  -> Incomplete typed -- exact match exists, but longer labels also match
    ([], [])        -> NoMatch
    ([], [cell])    -> Resolved cell
    _               -> Incomplete typed