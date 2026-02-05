// MARK: - Cursor Navigation
// Port of cursor movement from display.c (move_cursor, set_cursor, move_base, set_base).

extension EditorState {

    // MARK: - Move Cursor

    /// Move cursor by delta bytes. Returns true on success.
    @discardableResult
    mutating func moveCursor(_ delta: Int64) -> Bool {
        return setCursor(base + Int64(cursor) + delta)
    }

    /// Set cursor to absolute position. Returns true on success.
    @discardableResult
    mutating func setCursor(_ loc: Int64) -> Bool {
        var loc = loc

        if loc < 0 && base % Int64(lineLength) != 0 {
            loc = 0
        }

        guard fileHandle.tryloc(loc, lastEditedLoc: lastEditedLoc) else {
            return false
        }

        if loc < base {
            let baseMod = base % Int64(lineLength)
            if loc - baseMod < 0 {
                guard setBase(0) else { return false }
            } else {
                let newBase = myfloor(loc - baseMod, Int64(lineLength)) + baseMod
                guard moveBase(newBase - base) else { return false }
            }
            cursor = Int(loc - base)
        } else if loc >= base + Int64(page) {
            let baseMod = base % Int64(lineLength)
            let newBase = myfloor(loc - baseMod, Int64(lineLength)) + baseMod - Int64(page) + Int64(lineLength)
            guard moveBase(newBase - base) else { return false }
            cursor = Int(loc - base)
        } else if loc > base + Int64(nbBytes) {
            return false
        } else {
            cursor = Int(loc - base)
        }

        if selection.isSet {
            selection.update(
                oldPos: oldBase + Int64(oldCursor),
                newPos: base + Int64(cursor),
                fileSize: getfilesize(),
                viewport: &viewport,
                base: base
            )
        }

        return true
    }

    // MARK: - Move Base

    /// Move base by delta. Returns true on success.
    @discardableResult
    mutating func moveBase(_ delta: Int64) -> Bool {
        var delta = delta
        if mode == .bySector {
            if delta > 0 && delta < Int64(page) {
                delta = Int64(page)
            } else if delta < 0 && delta > -Int64(page) {
                delta = -Int64(page)
            }
        }
        return setBase(base + delta)
    }

    /// Set base to absolute position. Returns true on success.
    @discardableResult
    mutating func setBase(_ loc: Int64) -> Bool {
        var loc = loc
        if loc < 0 { loc = 0 }

        guard fileHandle.tryloc(loc, lastEditedLoc: lastEditedLoc) else {
            return false
        }

        base = loc
        readFile()

        if mode != .bySector && nbBytes < page - lineLength && base != 0 {
            base -= Int64(myfloor(Int64(page - nbBytes - lineLength), Int64(lineLength)))
            if base < 0 { base = 0 }
            readFile()
        }

        if cursor > nbBytes { cursor = nbBytes }
        return true
    }

    // MARK: - Interactive Movement Functions

    mutating func forwardChar() {
        if editPane.isAscii || cursorOffset != 0 {
            moveCursor(1)
        }
        if editPane.isHex {
            cursorOffset = (cursorOffset + 1) % 2
        }
    }

    mutating func backwardChar() {
        if editPane.isAscii || cursorOffset == 0 {
            moveCursor(-1)
        }
        if editPane.isHex {
            cursorOffset = (cursorOffset + 1) % 2
        }
    }

    mutating func nextLine() {
        moveCursor(Int64(lineLength))
    }

    mutating func previousLine() {
        moveCursor(Int64(-lineLength))
    }

    mutating func forwardChars() {
        moveCursor(Int64(blocSize))
    }

    mutating func backwardChars() {
        moveCursor(Int64(-blocSize))
    }

    mutating func nextLines() {
        moveCursor(Int64(lineLength * blocSize))
    }

    mutating func previousLines() {
        moveCursor(Int64(-lineLength * blocSize))
    }

    mutating func beginningOfLine() {
        cursorOffset = 0
        moveCursor(Int64(-(cursor % lineLength)))
    }

    mutating func endOfLine() {
        cursorOffset = 0
        if !moveCursor(Int64(lineLength - 1 - cursor % lineLength)) {
            moveCursor(Int64(nbBytes - cursor))
        }
    }

    mutating func scrollUp() {
        moveBase(Int64(page))
        if selection.isSet {
            selection.update(
                oldPos: oldBase + Int64(oldCursor),
                newPos: base + Int64(cursor),
                fileSize: getfilesize(),
                viewport: &viewport,
                base: base
            )
        }
    }

    mutating func scrollDown() {
        moveBase(Int64(-page))
        if selection.isSet {
            selection.update(
                oldPos: oldBase + Int64(oldCursor),
                newPos: base + Int64(cursor),
                fileSize: getfilesize(),
                viewport: &viewport,
                base: base
            )
        }
    }

    mutating func beginningOfBuffer() {
        cursorOffset = 0
        setCursor(0)
    }

    mutating func endOfBuffer() {
        let s = getfilesize()
        cursorOffset = 0
        if mode == .bySector {
            setBase(myfloor(s, Int64(page)))
        }
        setCursor(s)
    }

    mutating func recenter() {
        if cursor != 0 {
            base = base + Int64(cursor)
            cursor = 0
            readFile()
        }
    }
}
