// MARK: - ANSI Escape Sequence Generation

struct ANSIRenderer {
    // MARK: - Cursor Movement
    static func moveTo(row: Int, col: Int) -> String {
        return "\u{1b}[\(row + 1);\(col + 1)H"
    }

    static func moveToColumn(_ col: Int) -> String {
        return "\u{1b}[\(col + 1)G"
    }

    static let cursorUp = "\u{1b}[A"
    static let cursorDown = "\u{1b}[B"
    static let cursorForward = "\u{1b}[C"
    static let cursorBackward = "\u{1b}[D"

    static let hideCursor = "\u{1b}[?25l"
    static let showCursor = "\u{1b}[?25h"
    static let saveCursor = "\u{1b}[s"
    static let restoreCursor = "\u{1b}[u"

    // MARK: - Screen Clearing
    static let clearScreen = "\u{1b}[2J"
    static let clearToEndOfLine = "\u{1b}[K"
    static let clearToEndOfScreen = "\u{1b}[J"
    static let clearLine = "\u{1b}[2K"

    // MARK: - Mouse Tracking
    static let enableMouseTracking = "\u{1b}[?1000h\u{1b}[?1002h\u{1b}[?1006h"
    static let disableMouseTracking = "\u{1b}[?1006l\u{1b}[?1002l\u{1b}[?1000l"

    // MARK: - Keyboard Protocols
    // Kitty keyboard protocol: flag 1 = bit 0 (disambiguate)
    // With flag 1: Ctrl+C comes as CSI u sequence, but plain keys come as raw bytes.
    // - Ctrl+C: ESC [ 99 ; 5 u (modifier 5 = Ctrl)
    // - Ctrl+Shift+C: ESC [ 99 ; 6 u (modifier 6 = Ctrl+Shift)
    static let enableKittyKeyboard = "\u{1b}[>1u\u{1b}[>4;1m"
    static let disableKittyKeyboard = "\u{1b}[<u\u{1b}[>4;0m"

    // MARK: - Text Attributes
    static let resetAttributes = "\u{1b}[0m"
    static let bold = "\u{1b}[1m"
    static let dim = "\u{1b}[2m"
    static let underline = "\u{1b}[4m"
    static let reverse = "\u{1b}[7m"

    // MARK: - Foreground Colors
    static let fgBlack = "\u{1b}[30m"
    static let fgRed = "\u{1b}[31m"
    static let fgGreen = "\u{1b}[32m"
    static let fgYellow = "\u{1b}[33m"
    static let fgBlue = "\u{1b}[34m"
    static let fgMagenta = "\u{1b}[35m"
    static let fgCyan = "\u{1b}[36m"
    static let fgWhite = "\u{1b}[37m"
    static let fgDefault = "\u{1b}[39m"

    // MARK: - Background Colors
    static let bgBlack = "\u{1b}[40m"
    static let bgRed = "\u{1b}[41m"
    static let bgGreen = "\u{1b}[42m"
    static let bgYellow = "\u{1b}[43m"
    static let bgBlue = "\u{1b}[44m"
    static let bgMagenta = "\u{1b}[45m"
    static let bgCyan = "\u{1b}[46m"
    static let bgWhite = "\u{1b}[47m"
    static let bgDefault = "\u{1b}[49m"

    // MARK: - Composite Attribute Builders

    /// Build ANSI sequence for byte display based on attributes and color
    static func attributesFor(
        byteAttr: ByteAttribute,
        byteColor: ByteColor,
        isCursor: Bool,
        colored: Bool,
        showMarked: Bool = true,
        isOtherCursor: Bool = false,
        isOtherMarked: Bool = false
    ) -> String {
        var seq = "\u{1b}[0"  // start with reset

        if isCursor {
            // Active Cursor position: bold blue on yellow
            seq += ";1;34;43"
        } else if isOtherCursor {
            // Corresponding position in other pane: underlined or dim
            seq += ";4"  // Underline
        } else {
            if byteAttr.contains(.modified) {
                seq += ";1"  // bold
            }
            if showMarked && byteAttr.contains(.marked) {
                seq += ";7"  // reverse
            } else if isOtherMarked {
                seq += ";2"  // Dim for "lightly shade"
            }

            if colored && !(showMarked && byteAttr.contains(.marked)) && !isOtherMarked {
                switch byteColor {
                case .null: seq += ";31"  // red
                case .control: seq += ";32"  // green
                case .extended: seq += ";34"  // blue
                case .normal: break
                }
            }
        }

        seq += "m"
        return seq
    }

    /// Format a byte as two hex digits
    static func hexByte(_ byte: UInt8) -> String {
        let hexChars: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7",
            "8", "9", "A", "B", "C", "D", "E", "F",
        ]
        return String(hexChars[Int(byte >> 4)]) + String(hexChars[Int(byte & 0x0F)])
    }

    /// Format an address with given number of hex digits
    static func formatAddress(_ addr: UInt64, digits: Int) -> String {
        let hex = String(addr, radix: 16, uppercase: true)
        let padding = max(0, digits - hex.count)
        return String(repeating: "0", count: padding) + hex
    }

    /// Printable ASCII character or dot
    static func printableChar(_ byte: UInt8) -> Character {
        if byte >= 0x20 && byte < 0x7F {
            return Character(UnicodeScalar(byte))
        }
        return "."
    }
}
