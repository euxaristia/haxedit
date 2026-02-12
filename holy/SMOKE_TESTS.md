# HolyC Smoke Tests

Quick TTY checks for key-dispatch and behavior parity.

## Automated

- Run `make smoke`
- Expected output: `Smoke OK`
- `make test` runs the same smoke suite
- Includes checks for:
  - CLI parsing (`--help`, invalid/negative line lengths, `--` terminator, `--linelength 0`, `-l1`)
  - Readonly-mode edit blocking
  - Dirty-buffer open-file guard (`Ctrl+O` cancel and save-then-open paths)
  - Clipboard persistence across open-file (`Ctrl+O`) transitions
  - `>`, `<`, `G`, and `Enter` goto offset
  - Search forward/reverse (`/`, `Ctrl+R`) and invalid-pattern handling
  - Invalid truncate-input handling
  - System clipboard failure path handling (test hook)
  - Sector-mode goto/navigation (`Enter`, `Alt+F`, `Ctrl+V`)
  - CSI-modifier compatibility (`Alt+Right` via `CSI 1;3C`, `Ctrl+Alt+H` via `CSI u`)
  - `--color` byte-class highlights
  - Vim-key scope parity (hex-pane `w`, ASCII-pane literal `y/h/p/u` inserts)

## Prereqs

- Build: `make build`
- Use a real TTY (not a plain pipe)
- Test file: `printf '\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff' > /tmp/haxedit-smoke.bin`

## Run

- Start editor: `./haxedit /tmp/haxedit-smoke.bin`
- Validate `>`:
  - Press `>`
  - Expect status cursor `0x10/0x10`
- Validate `<`:
  - Press `<`
  - Expect status cursor `0x0/0x10`
- Validate `G` (hex pane):
  - Press `G`
  - Expect status cursor `0x10/0x10`
- Validate `Enter` goto:
  - Press `Enter`
  - At prompt, input `0x3` and press `Enter`
  - Expect status cursor `0x3/0x10`
- Quit:
  - Press `Ctrl+C`

## Expected Result

All four key paths move cursor to the expected offsets without crashes or raw-mode corruption.

## Sector Mode (`-s`)

- Prepare a 2048-byte file: `dd if=/dev/zero of=/tmp/haxedit-sector.bin bs=1 count=2048 status=none`
- Start editor: `./haxedit -s /tmp/haxedit-sector.bin`
- Press `Enter`
  - Expect prompt `goto sector:`
- Input `1` then `Enter`
  - Expect status cursor `0x200/0x800` and `--sector 1`
- Press `Enter`, input `5`, then `Enter`
  - Expect cursor unchanged (invalid sector rejected)
- Press `Alt+F`
  - Expect cursor to advance by `0x8` bytes
- Press `Ctrl+V`
  - Expect cursor to advance by `0x100` bytes (sector-mode page step)
