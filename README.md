# mouseless

Keyboard-only mouse control for macOS, written in Haskell. Inspired by Vim easymotion / Homerow-style labeling.

## How it works

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> GridOverlay: F19
  GridOverlay --> GridOverlay: type label chars
  GridOverlay --> FineGrid: coarse cell selected
  FineGrid --> Idle: fine cell selected (warp)
  GridOverlay --> Idle: Esc
  Idle --> CursorControl: m
  CursorControl --> Idle: Esc
```

1. **Activation** — press **F19** (global hotkey) to show a coarse grid overlay over the screen.
2. **Label selection** — each cell shows a key sequence (e.g. `a`, `s`, `aa`). Type the sequence to select; after a coarse cell, a **fine grid** opens inside that region for precision.
3. **Free movement** — from idle, `h` `j` `k` `l` nudge the cursor by pixel steps (default 8px).
4. **Grid-step movement** — press `m` to toggle between free-range and larger grid-aligned steps within a region.
5. **Click** — `Space` / `Enter` left-clicks at the cursor.

## Architecture

Pure functional core, imperative shell:

| Layer | Modules | Role |
|-------|---------|------|
| Core | `Geometry`, `Grid`, `Charset`, `Input`, `State`, `Commands` | Pure state machine + effects |
| Platform | `Platform.Class`, `Platform.MacOS`, `Platform.MacOS.FFI`, `Platform.Mock` | Screen, events, cursor I/O |
| Native | `cbits/mouseless_macos.m` | NSPanel overlay, CGEventTap, cursor warp/click |
| App | `App`, `Main` | Event loop |

The `step` function in `Mouseless.Core.State` is the entire logic: `(Config, AppState, Event) -> (AppState, [Effect])`.

## Setup

Install [GHCup](https://www.haskell.org/ghcup/) then:

```bash
cd ~/mouseless
stack build
stack test
stack exec mouseless
```

On first launch macOS will prompt for **Accessibility** permission (required for global hotkeys and synthetic clicks). Enable it in System Settings → Privacy & Security → Accessibility.

Mock mode (no native layer, for testing the pure core):

```bash
stack exec mouseless -- --mock
```

## Native macOS layer

`cbits/mouseless_macos.m` implements:

- **CGEventTap** — global key listener; F19 activates grid, keys captured while overlay is visible
- **NSPanel overlay** — full-screen transparent window with labeled grid cells (mouse-transparent)
- **CGWarpMouseCursorPosition** — cursor warp on cell selection / hjkl movement
- **CGEventPost** — synthetic left/right/middle clicks

Haskell binds this via `Mouseless.Platform.MacOS.FFI`.

## Key bindings (default)

| Key | Action |
|-----|--------|
| **F19** | Show grid overlay (global, works from any app) |
| `a`–`m`, `q`–`p`, etc. | Grid label input (while overlay active) |
| `h` `j` `k` `l` | Move cursor left/down/up/right |
| `m` | Toggle free-range ↔ grid-step movement |
| `Space` / `Enter` | Left click |
| `Esc` | Cancel overlay / exit move mode |
| `q` | Quit (global) |

## Configuration

Edit `defaultConfig` in `src/Mouseless/Core/State.hs`:

- `cfgGrid` — coarse/fine column and row counts
- `cfgFreeStep` — pixel step for free movement (default 8)
- `cfgGridStep` — pixel step for grid movement (default 24)
- `cfgAutoFineGrid` — open fine grid after coarse selection (default `True`)

To change the activation key, edit `kActivationKeyCode` in `cbits/mouseless_macos.m`.

## License

MIT
