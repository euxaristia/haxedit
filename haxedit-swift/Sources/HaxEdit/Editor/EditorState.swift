// MARK: - Editor State
// Central state struct that aggregates all editor state.
// No global mutable state — everything is here.

struct EditorState {
    // File
    var fileHandle: HaxFileHandle!

    // Display mode
    var mode: DisplayMode = .maximized
    var colored: Bool = false

    // Layout
    var lineLength: Int = 0
    var blocSize: Int = 4
    var page: Int = 0
    var colsUsed: Int = 0
    var nAddrDigits: Int = 8
    var normalSpaces: Int = 3

    // Cursor
    var base: Int64 = 0
    var oldBase: Int64 = 0
    var cursor: Int = 0
    var oldCursor: Int = 0
    var cursorOffset: Int = 0  // 0 = high nibble, 1 = low nibble (hex mode)
    var oldCursorOffset: Int = 0
    var editPane: EditPane = .hex

    // Model
    var edits: EditTracker = EditTracker()
    var viewport: Viewport = Viewport(pageSize: 0)
    var selection: Selection = Selection()
    var clipboard: Clipboard = Clipboard()

    // Remembered strings for prompts
    var lastFindFile: String? = nil
    var lastYankToAFile: String? = nil
    var lastAskHexString: String? = nil
    var lastAskAsciiString: String? = nil
    var lastFillWithStringHexa: String? = nil
    var lastFillWithStringAscii: String? = nil

    // First-time help
    var firstTimeHelpShown: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - Computed Properties

    var nbBytes: Int {
        get { viewport.nbBytes }
        set { viewport.nbBytes = newValue }
    }

    var isReadOnly: Bool {
        fileHandle?.isReadOnly ?? true
    }

    var baseName: String {
        fileHandle?.baseName ?? ""
    }

    var fileName: String {
        get { fileHandle?.fileName ?? "" }
    }

    var lastEditedLoc: Int64 {
        edits.lastEditedLoc
    }

    var biggestLoc: Int64 {
        get { fileHandle?.biggestLoc ?? 0 }
    }

    var fileSize: Int64 {
        fileHandle?.fileSize ?? 0
    }

    func getfilesize() -> Int64 {
        return max(lastEditedLoc, biggestLoc)
    }

    // MARK: - Layout Computation

    /// Compute the X position for a cursor at a given offset in a given pane
    func computeCursorXPos(cursor: Int, pane: EditPane) -> Int {
        var r = nAddrDigits + 3
        let x = cursor % lineLength
        let h = pane.isHex ? x : lineLength - 1

        r += normalSpaces * (h % blocSize) + (h / blocSize) * (normalSpaces * blocSize + 1)
        if pane.isHex {
            r += cursorOffset
        }

        if pane.isAscii {
            r += x + normalSpaces + 1
        }

        return r
    }

    func computeCursorXCurrentPos() -> Int {
        return computeCursorXPos(cursor: cursor, pane: editPane)
    }

    func computeLineSize() -> Int {
        return computeCursorXPos(cursor: lineLength - 1, pane: .ascii) + 1
    }

    /// Initialize display layout based on terminal size
    mutating func initDisplay(termSize: TerminalSize) throws {
        if mode == .bySector {
            let params = modeDefaults[.bySector]!
            lineLength = params.lineLength
            page = params.page
            page = Int(myfloor(Int64((termSize.rows - 1) * lineLength), Int64(page)))
            blocSize = params.blocSize
            if computeLineSize() > termSize.cols {
                throw HaxEditError.terminalTooSmall("width for sector view")
            }
            if page == 0 {
                throw HaxEditError.terminalTooSmall("height for sector view")
            }
        } else {
            if termSize.rows <= 4 {
                throw HaxEditError.terminalTooSmall("height")
            }
            blocSize = modeDefaults[.maximized]!.blocSize

            if lineLength == 0 {
                // Auto-fit: find largest lineLength that fits
                lineLength = blocSize
                while computeLineSize() <= termSize.cols {
                    lineLength += blocSize
                }
                lineLength -= blocSize
                if lineLength == 0 {
                    throw HaxEditError.terminalTooSmall("width")
                }
            } else {
                if computeLineSize() > termSize.cols {
                    throw HaxEditError.terminalTooSmall("width for selected line length")
                }
            }
            page = lineLength * (termSize.rows - 1)
        }
        colsUsed = computeLineSize()

        // Resize viewport
        viewport = Viewport(pageSize: page)
    }

    // MARK: - File Operations

    mutating func openFile(_ name: String, forceReadOnly: Bool = false) throws {
        fileHandle = try HaxFileHandle(fileName: name, forceReadOnly: forceReadOnly)
        selection.clear()
        base = 0
        cursor = 0
        cursorOffset = 0

        nAddrDigits = computeNDigits(UInt64(fileHandle.biggestLoc))
        if nAddrDigits < 8 { nAddrDigits = 8 }
    }

    mutating func readFile() {
        guard fileHandle != nil else { return }
        viewport.read(
            from: fileHandle,
            at: base,
            edits: edits,
            markSet: selection.isSet,
            markMin: selection.min,
            markMax: selection.max
        )
    }

    // MARK: - Byte Editing

    mutating func setToChar(_ i: Int, _ c: UInt8) {
        if i >= nbBytes {
            viewport.buffer[i] = c
            viewport.attributes[i].insert(.modified)
            edits.add(base: base + Int64(i), vals: [c])
            viewport.nbBytes = i + 1
        } else if viewport.buffer[i] != c {
            viewport.buffer[i] = c
            viewport.attributes[i].insert(.modified)
            edits.add(base: base + Int64(i), vals: [c])
        }
    }

    /// Process a character input in hex or ASCII mode.
    /// Returns true if the character was accepted.
    mutating func setTo(_ c: UInt8) -> Bool {
        guard cursor <= nbBytes else { return false }

        let val: Int
        if editPane.isHex {
            guard isHexDigit(c) else { return false }
            let hexVal = hexCharToInt(c)
            val = cursorOffset == 0
                ? setHighBits(Int(viewport.buffer[cursor]), hexVal)
                : setLowBits(Int(viewport.buffer[cursor]), hexVal)
        } else {
            val = Int(c)
        }

        guard !isReadOnly else { return false }

        setToChar(cursor, UInt8(val & 0xFF))
        return true
    }

    // MARK: - Save state for undo tracking

    mutating func saveOldState() {
        oldCursor = cursor
        oldCursorOffset = cursorOffset
        oldBase = base
    }
}
