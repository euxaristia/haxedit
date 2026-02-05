# #️⃣ HaxEdit

A modern, pure Swift reimplementation of the classic [HexEdit](http://rigaux.org/hexedit.html) tool.

HaxEdit maintains the features of the original `hexedit` while providing a modern, maintainable codebase and type safety.

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
    - Undo/Redo support.
    - Cut, Copy, Paste (internal clipboard).
    - Fill selection with pattern.
- **Display**:
    - Colored output support (`--color`).
    - Sector view (`--sector`).
    - Customizable line length.
    - Resizable terminal support (SIGWINCH).

## Installation

### From Source

Requirements: Swift 5.9+

```bash
git clone https://github.com/euxaristia/haxedit.git
cd haxedit
swift build -c release
cp .build/release/HaxEdit /usr/local/bin/haxedit
```

## Usage

```bash
haxedit [options] <filename>
```

**Options:**
- `-s`, `--sector`: Format the display to have entire sectors.
- `-m`, `--maximize`: Maximize the display.
- `-l<n>`, `--linelength <n>`: Explicitly set the number of bytes to display per line.
- `--color`: Display colors (if supported).
- `-h`, `--help`: Show usage.

**Key Bindings:**
- `F1` / `Ctrl+H`: Help
- `F2` / `Ctrl+W`: Save
- `F3` / `Ctrl+O`: Open another file
- `Tab`: Switch between Hex and ASCII
- `Ctrl+S` / `/`: Search forward
- `Ctrl+R`: Search backward
- `Ctrl+G`: Go to position
- `Ctrl+Z`: Suspend
- `Ctrl+C`: Quit (without saving)
- `Ctrl+X`: Save and Quit

See the in-app help (`F1`) for a full list of commands.

## Legacy

The original C implementation of `hexedit` by Pascal Rigaux has been moved to the `legacy/` directory.

## License

GPL (Inherited from the original project).
