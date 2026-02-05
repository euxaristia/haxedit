// MARK: - Core Types and Enums

/// Which editing column the cursor is in
enum EditPane: Int {
    case hex = 1    // hexOrAscii = TRUE (1) in original
    case ascii = 0  // hexOrAscii = FALSE (0) in original

    mutating func toggle() {
        self = (self == .hex) ? .ascii : .hex
    }

    var isHex: Bool { self == .hex }
    var isAscii: Bool { self == .ascii }
}

/// Display layout mode
enum DisplayMode: Int, CaseIterable {
    case bySector = 0
    case maximized = 1
}

/// Mode-specific layout parameters
struct ModeParams {
    let blocSize: Int
    let lineLength: Int
    let page: Int
}

let modeDefaults: [DisplayMode: ModeParams] = [
    .bySector: ModeParams(blocSize: 8, lineLength: 16, page: 256),
    .maximized: ModeParams(blocSize: 4, lineLength: 0, page: 0),
]

/// Per-byte display attributes (bitmask)
struct ByteAttribute: OptionSet {
    let rawValue: Int

    static let normal   = ByteAttribute([])
    static let modified = ByteAttribute(rawValue: 1 << 0)  // A_BOLD in original
    static let marked   = ByteAttribute(rawValue: 1 << 1)  // A_REVERSE in original
}

/// Byte color classification for colored mode
enum ByteColor {
    case null       // 0x00 → red
    case control    // 0x01-0x1F → green
    case normal     // 0x20-0x7E → default
    case extended   // 0x7F-0xFF → blue

    init(byte: UInt8) {
        switch byte {
        case 0:
            self = .null
        case 1...0x1F:
            self = .control
        case 0x20...0x7E:
            self = .normal
        default:
            self = .extended
        }
    }
}

/// Parsed keyboard input
enum KeyEvent: Equatable {
    case char(UInt8)                  // printable ASCII character
    case ctrl(UInt8)                  // Ctrl+letter (raw 0x01-0x1F)
    case alt(UInt8)                   // Alt+letter (ESC + char)
    case ctrlAlt(UInt8)              // Ctrl+Alt combination
    case arrow(ArrowDirection)        // arrow keys
    case altArrow(ArrowDirection)     // Alt+arrow keys
    case functionKey(Int)             // F1-F12
    case home
    case end
    case pageUp
    case pageDown
    case insert
    case delete
    case backspace
    case enter
    case tab
    case escape
    case mouse(MouseButton, MouseEventType, Int, Int) // button, event type, row, col
    case resize                       // SIGWINCH
    case none                         // no input / timeout
}

enum MouseButton: Equatable {
    case left, middle, right, none
}

enum MouseEventType: Equatable {
    case press, release, drag
}

enum ArrowDirection: Equatable {
    case up, down, left, right
}

/// Semantic editor actions
enum EditorAction {
    // Movement
    case forwardChar
    case backwardChar
    case nextLine
    case previousLine
    case forwardChars        // move by blocSize
    case backwardChars
    case nextLines           // move by lineLength * blocSize
    case previousLines
    case beginningOfLine
    case endOfLine
    case scrollUp            // page down (forward in file)
    case scrollDown          // page up (backward in file)
    case beginningOfBuffer
    case endOfBuffer
    case mouseEvent(row: Int, col: Int, type: MouseEventType)

    // Editing
    case insertChar(UInt8)
    case deleteBackwardChar
    case deleteBackwardChars
    case quotedInsert

    // Mode
    case toggleHexAscii
    case recenter
    case redisplay

    // File
    case save
    case findFile
    case truncateFile

    // Navigation
    case gotoChar
    case gotoSector

    // Search
    case searchForward
    case searchBackward

    // Mark / Clipboard
    case setMark
    case copyRegion
    case yank
    case yankToFile
    case fillWithString

    // Control
    case help
    case suspend
    case undo
    case quit
    case askSaveAndQuit
}

/// Errors
enum HaxEditError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case notAFile(String)
    case openFailed(String, String)
    case readFailed(String)
    case writeFailed(String)
    case seekFailed(Int64, Int64)
    case terminalTooSmall(String)
    case terminalError(String)
    case allocationFailed
    case readOnly

    var description: String {
        switch self {
        case .fileNotFound(let name): return "No such file: \(name)"
        case .notAFile(let name): return "\(name): Not a file"
        case .openFailed(let name, let err): return "\(name): \(err)"
        case .readFailed(let err): return "Read error: \(err)"
        case .writeFailed(let err): return "Write error: \(err)"
        case .seekFailed(let got, let wanted): return "Seek failed (\(got) instead of \(wanted))"
        case .terminalTooSmall(let msg): return "Terminal too small: \(msg)"
        case .terminalError(let msg): return "Terminal error: \(msg)"
        case .allocationFailed: return "Can't allocate memory"
        case .readOnly: return "File is read-only!"
        }
    }
}

// MARK: - Constants

let biggestCopying = 1024 * 1024        // 1MB max copy
let blockSearchSize = 4096              // 4KB search blocks
let sectorSize: Int64 = 512
let pressAnyKey = "(press any key)"

let usageMessage = """
    usage: haxedit [-s | --sector] [-m | --maximize] [-l<n> | --linelength <n>] \
    [-r | --readonly] [--color] [-h | --help] filename
    """

// MARK: - Utility Functions

func hexCharToInt(_ c: UInt8) -> Int {
    switch c {
    case UInt8(ascii: "0")...UInt8(ascii: "9"):
        return Int(c - UInt8(ascii: "0"))
    case UInt8(ascii: "a")...UInt8(ascii: "f"):
        return Int(c - UInt8(ascii: "a") + 10)
    case UInt8(ascii: "A")...UInt8(ascii: "F"):
        return Int(c - UInt8(ascii: "A") + 10)
    default:
        return 0
    }
}

func isHexDigit(_ c: UInt8) -> Bool {
    switch c {
    case UInt8(ascii: "0")...UInt8(ascii: "9"),
         UInt8(ascii: "a")...UInt8(ascii: "f"),
         UInt8(ascii: "A")...UInt8(ascii: "F"):
        return true
    default:
        return false
    }
}

func setLowBits(_ p: Int, _ val: Int) -> Int {
    return (p & 0xF0) + val
}

func setHighBits(_ p: Int, _ val: Int) -> Int {
    return (p & 0x0F) + val * 0x10
}

func myfloor(_ a: Int64, _ b: Int64) -> Int64 {
    guard b != 0 else { return a }
    let m = a % b
    return a - (m < 0 ? m + b : m)
}

func computeNDigits(_ maxAddr: UInt64) -> Int {
    var addr = maxAddr
    var digits = 0
    while addr != 0 {
        digits += 2
        addr >>= 8
    }
    return max(digits, 2)
}

/// Convert hex string (like "AABB CC") to binary bytes in-place.
/// Returns the byte data or nil on error.
func hexStringToBinString(_ input: String) -> (data: [UInt8], errorMessage: String?)? {
    var hexChars: [UInt8] = []
    for c in input.utf8 {
        if c == UInt8(ascii: " ") || c == UInt8(ascii: "\t") {
            continue
        }
        if !isHexDigit(c) {
            return ([], "Invalid hexa string")
        }
        hexChars.append(c)
    }
    if hexChars.count % 2 != 0 {
        return ([], "Must be an even number of chars")
    }
    var result: [UInt8] = []
    for i in stride(from: 0, to: hexChars.count, by: 2) {
        let high = hexCharToInt(hexChars[i])
        let low = hexCharToInt(hexChars[i + 1])
        result.append(UInt8(high << 4 | low))
    }
    return (result, nil)
}

/// Memory search forward (equivalent to memmem)
func memorySearch(haystack: UnsafeBufferPointer<UInt8>, needle: [UInt8]) -> Int? {
    let needleCount = needle.count
    let haystackCount = haystack.count
    guard needleCount > 0, haystackCount >= needleCount else { return nil }

    for i in 0...(haystackCount - needleCount) {
        var found = true
        for j in 0..<needleCount {
            if haystack[i + j] != needle[j] {
                found = false
                break
            }
        }
        if found { return i }
    }
    return nil
}

/// Memory search backward (equivalent to memrmem)
func memorySearchReverse(haystack: UnsafeBufferPointer<UInt8>, needle: [UInt8]) -> Int? {
    let needleCount = needle.count
    let haystackCount = haystack.count
    guard needleCount > 0, haystackCount >= needleCount else { return nil }

    for i in stride(from: haystackCount - needleCount, through: 0, by: -1) {
        var found = true
        for j in 0..<needleCount {
            if haystack[i + j] != needle[j] {
                found = false
                break
            }
        }
        if found { return i }
    }
    return nil
}
