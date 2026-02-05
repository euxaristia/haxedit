// MARK: - Prompt System
// Dialogs for messages, string input, number input, confirmation.
// Port of display message functions from display.c.

struct Prompt {
    /// Display a centered one-line message
    static func displayOneLineMessage(
        _ msg: String,
        state: EditorState,
        terminal: Terminal,
        termSize: TerminalSize
    ) {
        let center = state.page / state.lineLength / 2
        let output = clearAndCenter(msg: msg, center: center, termSize: termSize)
        terminal.writeString(output)
        terminal.flush()
    }

    /// Display two centered lines
    static func displayTwoLineMessage(
        _ msg1: String,
        _ msg2: String,
        state: EditorState,
        terminal: Terminal,
        termSize: TerminalSize
    ) {
        let center = state.page / state.lineLength / 2
        var out = ""
        out += clearLine(row: center - 2, termSize: termSize)
        out += clearLine(row: center + 1, termSize: termSize)
        out += centerText(msg: msg1, row: center - 1, termSize: termSize)
        out += centerText(msg: msg2, row: center, termSize: termSize)
        terminal.writeString(out)
        terminal.flush()
    }

    /// Display message and wait for any key
    static func displayMessageAndWaitForKey(
        _ msg: String,
        state: EditorState,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        displayTwoLineMessage(msg, pressAnyKey, state: state, terminal: terminal, termSize: termSize)
        _ = inputParser.readKey()
    }

    /// Display message and get string input.
    /// Returns the entered string, or nil if cancelled.
    static func displayMessageAndGetString(
        _ msg: String,
        lastValue: String?,
        state: EditorState,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize
    ) -> String? {
        displayOneLineMessage(msg + (lastValue ?? ""), state: state, terminal: terminal, termSize: termSize)

        // Read input character by character
        var buffer = lastValue ?? ""
        var cursorPos = buffer.count

        // Re-render the prompt with current buffer
        func redraw() {
            let center = state.page / state.lineLength / 2
            var out = centerText(msg: msg + buffer, row: center, termSize: termSize)
            // Position cursor within the input
            let col = (termSize.cols - (msg.count + buffer.count)) / 2 + msg.count + cursorPos
            out += ANSIRenderer.moveTo(row: center, col: col)
            out += ANSIRenderer.showCursor
            terminal.writeString(out)
            terminal.flush()
        }

        redraw()

        while true {
            let key = inputParser.readKey()
            switch key {
            case .enter:
                if buffer.isEmpty {
                    if let last = lastValue, !last.isEmpty {
                        return last
                    }
                    return nil
                }
                return buffer

            case .escape, .ctrl(0x03): // Esc or Ctrl+C
                return nil

            case .backspace:
                if cursorPos > 0 {
                    let idx = buffer.index(buffer.startIndex, offsetBy: cursorPos - 1)
                    buffer.remove(at: idx)
                    cursorPos -= 1
                    redraw()
                }

            case .char(let c):
                let idx = buffer.index(buffer.startIndex, offsetBy: cursorPos)
                buffer.insert(Character(UnicodeScalar(c)), at: idx)
                cursorPos += 1
                redraw()

            case .ctrl(0x15): // Ctrl+U — clear line
                buffer = ""
                cursorPos = 0
                redraw()

            case .arrow(.left):
                if cursorPos > 0 {
                    cursorPos -= 1
                    redraw()
                }

            case .arrow(.right):
                if cursorPos < buffer.count {
                    cursorPos += 1
                    redraw()
                }

            case .resize:
                return nil

            default:
                break
            }
        }
    }

    /// Get a number (hex with 0x prefix, or decimal)
    static func getNumber(
        state: EditorState,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize,
        prompt: String
    ) -> Int64? {
        displayOneLineMessage(prompt, state: state, terminal: terminal, termSize: termSize)

        guard let input = displayMessageAndGetString(
            prompt,
            lastValue: nil,
            state: state,
            terminal: terminal,
            inputParser: inputParser,
            termSize: termSize
        ) else {
            return nil
        }

        let trimmed = trimWhitespace(input)
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            let hexPart = String(trimmed.dropFirst(2))
            if let val = UInt64(hexPart, radix: 16) {
                let result = Int64(bitPattern: val & 0x7FFFFFFFFFFFFFFF)
                return result >= 0 ? result : nil
            }
        } else {
            if let val = UInt64(trimmed) {
                let result = Int64(bitPattern: val & 0x7FFFFFFFFFFFFFFF)
                return result >= 0 ? result : nil
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func clearLine(row: Int, termSize: TerminalSize) -> String {
        return ANSIRenderer.moveTo(row: row, col: 0) + ANSIRenderer.clearLine
    }

    private static func centerText(msg: String, row: Int, termSize: TerminalSize) -> String {
        var out = ANSIRenderer.moveTo(row: row, col: 0) + ANSIRenderer.clearLine
        let col = max(0, (termSize.cols - msg.count) / 2)
        out += ANSIRenderer.moveTo(row: row, col: col)
        out += ANSIRenderer.resetAttributes
        out += msg
        return out
    }

    private static func clearAndCenter(msg: String, center: Int, termSize: TerminalSize) -> String {
        var out = ""
        out += clearLine(row: center - 1, termSize: termSize)
        out += clearLine(row: center + 1, termSize: termSize)
        out += centerText(msg: msg, row: center, termSize: termSize)
        return out
    }
}
