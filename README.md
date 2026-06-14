# 🖱️ Mouseful

Control the mouse cursor entirely from the keyboard. A grid is overlaid on the screen, labeled with keys. Type a key combination to jump the mouse to the corresponding grid cell, then refine with smaller grids until the cursor is exactly where you want it.

## Project Structure

- `Mouseful.Core.Grid`
- `Mouseful.Core.Geometry`
- `Mouseful.Core.Charset`
- `Mouseful.Core.Input`
- `Mouseful.Core.State`
- `Mouseful.Core.Commands`
- `Mouseful.App`
- `Mouseful.Platform.Class`
- `Mouseful.Platform.MacOS`
- `Mouseful.Platform.Mock`

```
src/Mouseful/
├── App.hs
├── Platform/
│   ├── Class.hs
│   ├── MacOS.hs
│   ├── Mock.hs
│   └── MacOS/
│       └── FFI.hs
└── Core/
    ├── Charset.hs
    ├── Commands.hs
    ├── Geometry.hs
    ├── Grid.hs
    ├── Input.hs
    └── State.hs
```

- **`app/Main.hs`**: Entry point, delegates to `Mouseful.App.run`.

This Haskell project is built using `stack`. It wraps an Objective-C library (`cbits/mouseful_macos.m`) for low-level macOS accessibility APIs.

## Requirements

- [Haskell Stack](https://docs.haskellstack.org/en/stable/)
- macOS 10.14+ (uses Accessibility API)

## Setup

```
stack setup
stack build
stack test
stack run
```

## Usage

```
stack run
```

Press Enter to activate the grid overlay. The grid divides the screen into labeled sections. Type the label keys to progressively narrow down the target region until the cursor is positioned, then click or right-click with the `f` and `d` keys.

Type `:help` for available commands.