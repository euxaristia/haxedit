# HolyC Parity Checklist

Tracks user-visible behavior parity against the legacy implementation.

## CLI and Startup

- [x] `-h`, `--help` usage output
- [x] `-r`, `--readonly`
- [x] `-s`, `--sector`
- [x] `-m`, `--maximize`
- [x] `-lN`, `--linelength N`
- [x] `--linelength 0` (auto)
- [x] `--color`
- [x] `--` option terminator
- [x] Prompt for file when no filename provided

## Navigation and View

- [x] Arrows / Ctrl+F/B/N/P
- [x] Alt+Arrows / Alt+F/B/N/P (including CSI modifier variants)
- [x] Home/End and Ctrl+A/Ctrl+E
- [x] Page up/down (`PgUp`, `PgDn`, `Ctrl+V`, `Alt+V`, `F5`, `F6`)
- [x] Buffer bounds (`<`, `>`, `Alt+<`, `Alt+>`, `G` in hex pane)
- [x] Recenter (`Alt+L`)
- [x] Mouse click/drag selection

## Editing and Data Ops

- [x] Hex nibble editing
- [x] ASCII editing
- [x] Pane toggle (`Tab`, `Ctrl+T`)
- [x] Backspace delete and block delete (`Ctrl+Alt+H`)
- [x] Quoted insert (`Ctrl+Q`, `Alt+Q`)
- [x] Undo (`Ctrl+U`, `Ctrl+_`)
- [x] Mark/copy/paste (`v`, `y`, `p`, Ctrl variants, function keys)
- [x] Clipboard persistence across `Ctrl+O` file-open transitions
- [x] Vim-key scope parity (`w`,`b`,`h`,`j`,`k`,`l`,`y`,`p`) by pane
- [x] Fill region (`Alt+I`, `F12`)
- [x] Truncate (`Alt+T`)

## Search and Goto

- [x] Search forward (`/`, `Ctrl+S`)
- [x] Search backward (`Ctrl+R`)
- [x] Goto offset (`Ctrl+G`, `F4`, `Enter` non-sector)
- [x] Goto sector (`Enter` in sector mode)

## File and Process

- [x] Open file prompt (`Ctrl+O`, `F3`, `Alt+O`)
- [x] Open-file dirty guard (save/cancel prompt before replacing buffer)
- [x] Save (`Ctrl+W`, `F2`)
- [x] Save+quit (`Ctrl+X`, `F10`)
- [x] Quit flow with unsaved confirmation (`Ctrl+C`)
- [x] Suspend (`Ctrl+Z`)

## Output and Display

- [x] Status line with cursor/size/percent
- [x] Sector status suffix in sector mode
- [x] Colorized byte classes under `--color`
- [x] Preserve color mode across open-file prompt transitions
- [x] Selection and ghost-highlight rendering

## Automation

- [x] `make smoke` automated PTY regression checks
- [x] `make test` delegates to smoke for HolyC target
