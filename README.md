# #️⃣ HaxEdit

A modern HolyC reimplementation of the classic [HexEdit](http://rigaux.org/hexedit.html) tool.

HaxEdit maintains the features of the original `hexedit` while providing a modern, maintainable codebase.

## Features

- **View and Edit**: Browse and modify files in Hex and ASCII simultaneously.
- **Search**: Fast forward and backward search for Hex strings or ASCII text.
- **Navigation**: 
    - Jump to file offset or sector.
    - Scroll by line or page.
    - Mark and copy regions.
- **Editing**:
    - Modify bytes in Hex or ASCII mode.
    - Insert/Delete bytes (with shift).
    - Undo support.
    - Cut, Copy, Paste (internal clipboard).
    - Fill selection with pattern.
- **Display**:
    - Colored output support (`--color`).
    - Sector view (`--sector`).
    - Customizable line length.
    - Resizable terminal support (SIGWINCH).

## Installation

### From Source

Requirements: Linux x86_64 and `hcc` (HolyC compiler)

```bash
git clone https://github.com/euxaristia/haxedit.git
cd haxedit
make build
cp ./haxedit /usr/local/bin/haxedit
```

The repository now ships a HolyC-only implementation targeting Linux.

## Usage

```bash
haxedit [options] <filename>
```

**Options:**
- `-s`, `--sector`: Sector layout with fixed 16-byte lines.
- `-m`, `--maximize`: Maximize the display.
- `-l<n>`, `--linelength <n>`: Explicitly set the number of bytes to display per line.
- `-r`, `--readonly`: Open file in read-only mode.
- `--color`: Display colors (if supported).
- `-h`, `--help`: Show usage.

**Key Bindings:**

*   **Movement**
    *   `Arrows` / `Ctrl+F/B/N/P`: Move cursor
    *   `Alt+Arrows` / `Alt+F/B/N/P`: Move by block/line
    *   `Home` / `Ctrl+A`: Start of line
    *   `End` / `Ctrl+E`: End of line
    *   `PgUp` / `Alt+V` / `F5`: Page up
    *   `PgDn` / `Ctrl+V` / `F6`: Page down
    *   `<` / `Alt+<`: Start of file
    *   `>` / `Alt+>`: End of file
    *   `Alt+L`: Recenter view

*   **Editing**
    *   `Tab` / `Ctrl+T`: Toggle Hex/ASCII pane
    *   `Backspace`: Delete backward
    *   `Ctrl+Alt+H`: Delete backward block
    *   `Alt+Q` / `Ctrl+Q`: Quoted insert
    *   `Ctrl+U` / `Ctrl+_`: Undo all

*   **File Operations**
    *   `Ctrl+W` / `F2`: Save
    *   `Ctrl+O` / `F3`: Open file
    *   `Ctrl+G` / `F4` / `Enter`: Goto position/sector
    *   `Alt+T`: Truncate file
    *   `Ctrl+X` / `F10`: Save and Quit
    *   `Ctrl+C`: Quit

*   **Search**
    *   `/` / `Ctrl+S`: Search forward
    *   `Ctrl+R`: Search backward

*   **Mark / Copy / Paste**
    *   `Ctrl+Space` / `F9`: Set mark
    *   `Ctrl+D` / `Alt+W` / `F7`: Copy region
    *   `Ctrl+Shift+C`: Copy to system clipboard
    *   `Ctrl+Y` / `F8`: Paste
    *   `Alt+Y` / `F11`: Paste to file
    *   `Alt+I` / `F12`: Fill with string

*   **Vim-like (Hex Pane)**
    *   `h`/`j`/`k`/`l`: Move cursor
    *   `w`/`b`: Move by block
    *   `v`: Set mark
    *   `y`: Copy
    *   `p`: Paste
    *   `G`: End of file

See the in-app help (`F1`) for details.

## Testing

Run the automated PTY smoke checks:

```bash
make smoke
```

This validates key-dispatch parity scenarios in normal and sector mode and fails on regressions.

The `test` target now runs the same smoke suite:

```bash
make test
```

## License

GPL (Inherited from the original project).
