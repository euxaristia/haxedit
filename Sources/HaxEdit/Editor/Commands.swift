import Foundation

#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif

// MARK: - Commands
// Executes editor actions. Port of interact.c command functions.

struct Commands {

    /// Execute an editor action. Returns false if the editor should quit.
    @discardableResult
    static func execute(
        _ action: EditorAction,
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) -> Bool {
        switch action {
        // Movement
        case .forwardChar: state.forwardChar()
        case .backwardChar: state.backwardChar()
        case .nextLine: state.nextLine()
        case .previousLine: state.previousLine()
        case .forwardChars: state.forwardChars()
        case .backwardChars: state.backwardChars()
        case .nextLines: state.nextLines()
        case .previousLines: state.previousLines()
        case .beginningOfLine: state.beginningOfLine()
        case .endOfLine: state.endOfLine()
        case .scrollUp: state.scrollUp()
        case .scrollDown: state.scrollDown()
        case .beginningOfBuffer: state.beginningOfBuffer()
        case .endOfBuffer: state.endOfBuffer()
        case .recenter: state.recenter()

        case .mouseEvent(let row, let col, let type):
            if let result = state.findOffsetFrom(row: row, col: col) {
                state.cursor = result.cursor
                state.editPane = result.pane
                state.cursorOffset = result.offset
                let newPos = state.base + Int64(state.cursor)

                if type == .press {
                    // Just record where the drag might start - don't create a selection yet
                    state.viewport.unmarkAll()
                    state.selection.clear()
                    state.mouseDragStart = newPos
                } else if type == .drag {
                    // Now we're actually creating/extending a selection
                    if let startPos = state.mouseDragStart {
                        if !state.selection.isSet {
                            // First drag movement - create the selection
                            state.selection.isSet = true
                            state.selection.min = min(startPos, newPos)
                            state.selection.max = max(startPos, newPos)
                        } else {
                            // Update selection to span from start to current
                            state.selection.min = min(startPos, newPos)
                            state.selection.max = max(startPos, newPos)
                        }
                        state.viewport.markRegion(
                            base: state.base,
                            min: state.selection.min,
                            max: state.selection.max
                        )
                    }
                }
            }

        // Editing
        case .insertChar(let c):
            if !state.setTo(c) {
                if state.isReadOnly {
                    Prompt.displayMessageAndWaitForKey(
                        "File is read-only!", state: state, terminal: terminal,
                        inputParser: inputParser, termSize: termSize
                    )
                } else if !state.firstTimeHelpShown {
                    state.firstTimeHelpShown = true
                    Prompt.displayMessageAndWaitForKey(
                        "Unknown command, press F1 for help",
                        state: state, terminal: terminal,
                        inputParser: inputParser, termSize: termSize
                    )
                }
            } else {
                state.forwardChar()
            }

        case .deleteBackwardChar:
            state.backwardChar()
            state.edits.remove(base: state.base + Int64(state.cursor), size: 1)
            state.readFile()
            state.cursorOffset = 0
            if !state.fileHandle.tryloc(
                state.base + Int64(state.cursor), lastEditedLoc: state.lastEditedLoc)
            {
                state.endOfBuffer()
            }

        case .deleteBackwardChars:
            state.backwardChars()
            state.edits.remove(base: state.base + Int64(state.cursor), size: state.blocSize)
            state.readFile()
            state.cursorOffset = 0
            if !state.fileHandle.tryloc(
                state.base + Int64(state.cursor), lastEditedLoc: state.lastEditedLoc)
            {
                state.endOfBuffer()
            }

        case .quotedInsert:
            let key = inputParser.readKey()
            if case .char(let c) = key {
                _ = state.setTo(c)
                state.forwardChar()
            }

        // Mode
        case .toggleHexAscii:
            state.editPane.toggle()
            state.cursorOffset = 0

        case .redisplay:
            // Full redraw handled by main loop
            break

        // File operations
        case .save:
            saveBuffer(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .findFile:
            findFile(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .truncateFile:
            truncateFile(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        // Navigation
        case .gotoChar:
            gotoChar(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .gotoSector:
            gotoSector(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        // Search
        case .searchForward:
            Search.forward(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .searchBackward:
            Search.backward(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        // Mark / Clipboard
        case .setMark:
            setMark(state: &state)

        case .copyRegion:
            copyRegion(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .copyToSystemClipboard:
            copyToSystemClipboard(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .yank:
            yank(state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .yankToFile:
            yankToFile(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .fillWithString:
            fillWithString(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        // Control
        case .help:
            showHelp(state: state, terminal: terminal, inputParser: inputParser, termSize: termSize)

        case .suspend:
            terminal.suspend()

        case .undo:
            state.edits.discardAll()
            if state.base + Int64(state.cursor) > state.biggestLoc {
                state.setCursor(state.biggestLoc)
            }
            if state.selection.max >= state.biggestLoc {
                state.selection.max = state.biggestLoc - 1
            }
            state.readFile()

        case .quit:
            return false

        case .askSaveAndQuit:
            return !askAboutSaveAndQuit(
                state: &state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
        }

        return true
    }

    // MARK: - Save

    static func saveBuffer(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        if let error = state.edits.save(to: state.fileHandle) {
            Prompt.displayMessageAndWaitForKey(
                error, state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            Prompt.displayMessageAndWaitForKey(
                "Unwritten changes have been discarded",
                state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            state.readFile()
            if state.cursor > state.nbBytes {
                state.setCursor(state.getfilesize())
            }
        }
        // Clear modified attributes
        for i in 0..<state.viewport.attributes.count {
            state.viewport.attributes[i].remove(.modified)
        }
        if state.selection.isSet {
            state.viewport.markRegion(
                base: state.base,
                min: state.selection.min,
                max: state.selection.max
            )
        }
    }

    // MARK: - Ask About Save

    /// Returns true if the user wants to quit
    static func askAboutSave(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) -> Int {
        guard state.edits.hasEdits else { return -1 }

        Prompt.displayOneLineMessage(
            "Save changes (Yes/No/Cancel) ?",
            state: state, terminal: terminal, termSize: termSize
        )

        let key = inputParser.readKey()
        switch key {
        case .char(UInt8(ascii: "y")), .char(UInt8(ascii: "Y")):
            saveBuffer(
                state: &state, terminal: terminal, inputParser: inputParser, termSize: termSize)
            return 1
        case .char(UInt8(ascii: "n")), .char(UInt8(ascii: "N")):
            state.edits.discardAll()
            return 1
        default:
            return 0
        }
    }

    /// Returns true if the editor should quit
    static func askAboutSaveAndQuit(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) -> Bool {
        let result = askAboutSave(
            state: &state, terminal: terminal,
            inputParser: inputParser, termSize: termSize
        )
        return result != 0
    }

    // MARK: - Goto

    static func gotoChar(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        // Pre-fill with "0x"
        guard
            let input = Prompt.displayMessageAndGetString(
                "New position ? ",
                lastValue: "0x",
                state: state,
                terminal: terminal,
                inputParser: inputParser,
                termSize: termSize
            )
        else { return }

        // Parse the number
        let trimmed = trimWhitespace(input)
        var value: Int64?
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            if let v = UInt64(String(trimmed.dropFirst(2)), radix: 16) {
                value = Int64(v)
            }
        } else {
            if let v = UInt64(trimmed) {
                value = Int64(v)
            }
        }

        if let v = value {
            if !state.setCursor(v) {
                Prompt.displayMessageAndWaitForKey(
                    "Invalid position!", state: state, terminal: terminal,
                    inputParser: inputParser, termSize: termSize
                )
            }
        } else {
            Prompt.displayMessageAndWaitForKey(
                "Invalid position!", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
        }
    }

    static func gotoSector(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard
            let input = Prompt.displayMessageAndGetString(
                "New sector ? ",
                lastValue: nil,
                state: state,
                terminal: terminal,
                inputParser: inputParser,
                termSize: termSize
            )
        else { return }

        if let sector = UInt64(trimWhitespace(input)) {
            let pos = Int64(sector) * sectorSize
            if state.setBase(pos) {
                state.setCursor(pos)
            } else {
                Prompt.displayMessageAndWaitForKey(
                    "Invalid sector!", state: state, terminal: terminal,
                    inputParser: inputParser, termSize: termSize
                )
            }
        } else {
            Prompt.displayMessageAndWaitForKey(
                "Invalid sector!", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
        }
    }

    // MARK: - Find File

    static func findFile(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        // Ask about unsaved changes first
        let saveResult = askAboutSave(
            state: &state, terminal: terminal,
            inputParser: inputParser, termSize: termSize
        )
        if saveResult == 0 { return }
        if saveResult == 1 {
            state.readFile()
        }

        guard
            let name = Prompt.displayMessageAndGetString(
                "File name: ",
                lastValue: state.lastFindFile,
                state: state,
                terminal: terminal,
                inputParser: inputParser,
                termSize: termSize
            )
        else { return }

        guard isFile(name) else {
            Prompt.displayMessageAndWaitForKey(
                "No such file or directory", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        state.lastFindFile = state.fileName
        do {
            try state.openFile(name, forceReadOnly: state.isReadOnly)
            state.readFile()
        } catch {
            Prompt.displayMessageAndWaitForKey(
                "\(error)", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
        }
    }

    // MARK: - Truncate

    static func truncateFile(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        Prompt.displayOneLineMessage(
            "Really truncate here? (y/N)",
            state: state, terminal: terminal, termSize: termSize
        )

        let key = inputParser.readKey()
        guard case .char(let c) = key, c == UInt8(ascii: "y") || c == UInt8(ascii: "Y") else {
            return
        }

        let truncPos = state.base + Int64(state.cursor)

        if state.biggestLoc > truncPos {
            do {
                try state.fileHandle.truncate(at: truncPos)
            } catch {
                Prompt.displayMessageAndWaitForKey(
                    "\(error)", state: state, terminal: terminal,
                    inputParser: inputParser, termSize: termSize
                )
                return
            }
        }

        state.edits.remove(base: truncPos, size: Int(state.lastEditedLoc - truncPos))

        if state.selection.isSet {
            if state.selection.min >= truncPos || state.selection.max >= truncPos {
                state.viewport.unmarkAll()
                state.selection.clear()
            }
        }

        state.readFile()
    }

    // MARK: - Mark / Selection

    static func setMark(state: inout EditorState) {
        state.viewport.unmarkAll()
        state.selection.toggle(at: state.base + Int64(state.cursor))
        if state.selection.isSet {
            state.viewport.markIt(state.cursor)
        }
    }

    // MARK: - Copy Region

    static func copyRegion(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard state.selection.isSet else {
            Prompt.displayMessageAndWaitForKey(
                "Nothing to copy", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        let size = Int(state.selection.max - state.selection.min + 1)
        if size <= 0 { return }

        if size > biggestCopying {
            Prompt.displayTwoLineMessage(
                "Hey, don't you think that's too big?!",
                "Really copy (Yes/No)",
                state: state, terminal: terminal, termSize: termSize
            )
            let key = inputParser.readKey()
            guard case .char(let c) = key, c == UInt8(ascii: "y") || c == UInt8(ascii: "Y") else {
                return
            }
        }

        let copyData = state.getSelectedData()
        state.clipboard.set(copyData)
        state.viewport.unmarkAll()
        state.selection.clear()
    }

    // MARK: - Copy to System Clipboard

    static func copyToSystemClipboard(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard state.selection.isSet else {
            Prompt.displayMessageAndWaitForKey(
                "Nothing to copy", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        let data = state.getSelectedData()
        guard !data.isEmpty else { return }

        let stringToCopy: String
        if state.editPane.isHex {
            // Format as hex string: "48 65 6c 6c 6f"
            stringToCopy = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        } else {
            // Format as ASCII string
            stringToCopy = String(decoding: data, as: UTF8.self)
        }

        terminal.setSystemClipboard(stringToCopy)

        // Don't unmark selection for system copy, as it's often used repeatedly
        Prompt.displayMessageAndWaitForKey(
            "Copied to system clipboard", state: state, terminal: terminal,
            inputParser: inputParser, termSize: termSize
        )
    }

    // MARK: - Yank (Paste)

    static func yank(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard let data = state.clipboard.data, !data.isEmpty else {
            Prompt.displayMessageAndWaitForKey(
                "Nothing to paste", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        if state.isReadOnly {
            Prompt.displayMessageAndWaitForKey(
                "File is read-only!", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        state.edits.add(base: state.base + Int64(state.cursor), vals: data)
        state.readFile()
    }

    // MARK: - Yank to File

    static func yankToFile(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard let data = state.clipboard.data, !data.isEmpty else {
            Prompt.displayMessageAndWaitForKey(
                "Nothing to paste", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        guard
            let name = Prompt.displayMessageAndGetString(
                "File name: ",
                lastValue: state.lastYankToAFile,
                state: state,
                terminal: terminal,
                inputParser: inputParser,
                termSize: termSize
            )
        else { return }

        state.lastYankToAFile = name

        // Check if file exists
        if isFile(name) {
            Prompt.displayTwoLineMessage(
                "File exists", "Overwrite it (Yes/No)",
                state: state, terminal: terminal, termSize: termSize
            )
            let key = inputParser.readKey()
            guard case .char(let c) = key, c == UInt8(ascii: "y") || c == UInt8(ascii: "Y") else {
                return
            }
        }

        let fd = platformOpen(name, platformO_WRONLY | platformO_CREAT | platformO_TRUNC, 0o666)
        guard fd >= 0 else {
            Prompt.displayMessageAndWaitForKey(
                platformStrerror(platformErrno()),
                state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        data.withUnsafeBufferPointer { buf in
            _ = platformWrite(fd, buf.baseAddress!, data.count)
        }
        _ = platformClose(fd)
    }

    // MARK: - Fill with String

    static func fillWithString(
        state: inout EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard state.selection.isSet else { return }

        if state.isReadOnly {
            Prompt.displayMessageAndWaitForKey(
                "File is read-only!", state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
            return
        }

        let msg =
            state.editPane.isHex ? "Hexa string to fill with: " : "Ascii string to fill with: "
        let lastValue =
            state.editPane.isHex ? state.lastFillWithStringHexa : state.lastFillWithStringAscii

        guard
            let input = Prompt.displayMessageAndGetString(
                msg,
                lastValue: lastValue,
                state: state,
                terminal: terminal,
                inputParser: inputParser,
                termSize: termSize
            )
        else { return }

        if state.editPane.isHex {
            state.lastFillWithStringHexa = input
        } else {
            state.lastFillWithStringAscii = input
        }

        var pattern: [UInt8]
        if state.editPane.isHex {
            if input.count == 1 {
                // Single hex digit
                guard let c = input.first, c.isHexDigit else {
                    Prompt.displayMessageAndWaitForKey(
                        "Invalid hexa string", state: state, terminal: terminal,
                        inputParser: inputParser, termSize: termSize
                    )
                    return
                }
                let val = hexCharToInt(UInt8(c.asciiValue!))
                pattern = [UInt8(val)]
            } else {
                guard let result = hexStringToBinString(input) else { return }
                if let err = result.errorMessage {
                    Prompt.displayMessageAndWaitForKey(
                        err, state: state, terminal: terminal,
                        inputParser: inputParser, termSize: termSize
                    )
                    return
                }
                pattern = result.data
            }
        } else {
            pattern = Array(input.utf8)
        }

        guard !pattern.isEmpty else { return }

        let fillSize = Int(state.selection.max - state.selection.min + 1)
        var fillData = [UInt8](repeating: 0, count: fillSize)

        var i = 0
        while i < fillSize {
            let remaining = fillSize - i
            let copyLen = min(pattern.count, remaining)
            for j in 0..<copyLen {
                fillData[i + j] = pattern[j]
            }
            i += pattern.count
        }

        state.edits.add(base: state.selection.min, vals: fillData)
        state.readFile()
    }

    // MARK: - Help

    static func showHelp(
        state: EditorState,
        terminal: TerminalProtocol,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        let helpText = """
            HaxEdit - Hex Editor Key Bindings

            Movement:
              Arrows / Ctrl+F/B/N/P  Move cursor
              Alt+F/B/N/P            Move by block/line*block
              Ctrl+A / Home          Beginning of line
              Ctrl+E / End           End of line
              Ctrl+V / PgDn / F6     Page down
              Alt+V / PgUp / F5      Page up
              < / Alt+<              Beginning of file
              > / Alt+>              End of file
              Alt+L                  Recenter

            Editing:
              Tab / Ctrl+T           Toggle hex/ascii
              Alt+Q                  Quoted insert
              Backspace              Delete backward
              Ctrl+U / Ctrl+_        Undo all

            File:
              Ctrl+W / F2            Save
              Ctrl+O / F3            Open file
              Ctrl+G / F4 / Enter    Goto position
              Alt+T                  Truncate
              Ctrl+X / F10           Save & quit
              Ctrl+C                 Quit

            Search:
              / / Ctrl+S             Search forward
              Ctrl+R                 Search backward

            Mark/Copy:
              Ctrl+Space / F9        Set mark
              Ctrl+D / Alt+W / F7    Copy region
              Ctrl+Shift+C           Copy to system clipboard
              Ctrl+Y / F8            Paste
              Alt+Y / F11            Paste to file
              F12 / Alt+I            Fill with string

            Other:
              Ctrl+Z                 Suspend
              Ctrl+L                 Redisplay
              F1 / Alt+H             This help
            """

        // Clear screen and show help
        terminal.writeString(ANSIRenderer.clearScreen)
        terminal.writeString(ANSIRenderer.moveTo(row: 0, col: 0))
        terminal.writeString(ANSIRenderer.resetAttributes)
        terminal.writeString(helpText)
        terminal.writeString("\n\n" + pressAnyKey)
        terminal.flush()
        _ = inputParser.readKey()
    }
}
