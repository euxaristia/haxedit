// MARK: - Display
// Screen rendering: hex view, ASCII view, status bar.
// Port of display.c.

struct Display {
    /// Render the full screen into an ANSI string buffer.
    static func render(state: EditorState, termSize: TerminalSize) -> String {
        var out = ANSIRenderer.hideCursor

        // Hex/ASCII lines
        let lineCount = state.page / state.lineLength
        for lineIdx in 0..<lineCount {
            let offset = lineIdx * state.lineLength
            out += ANSIRenderer.moveTo(row: lineIdx, col: 0)

            if offset < state.nbBytes {
                out += renderLine(
                    state: state,
                    offset: offset,
                    max: state.nbBytes
                )
            } else {
                // Empty line: show address then blanks
                out += ANSIRenderer.resetAttributes
                out += ANSIRenderer.formatAddress(
                    UInt64(state.base) + UInt64(offset),
                    digits: state.nAddrDigits
                )
                out += String(repeating: " ", count: max(0, state.colsUsed - state.nAddrDigits))
            }
            // Clear rest of line
            out += ANSIRenderer.clearToEndOfLine
        }

        // Status bar (last line)
        out += renderStatusBar(state: state, termSize: termSize)

        // Position cursor
        let cursorRow = state.cursor / state.lineLength
        let cursorCol = state.computeCursorXCurrentPos()
        out += ANSIRenderer.moveTo(row: cursorRow, col: cursorCol)
        out += ANSIRenderer.showCursor

        return out
    }

    // MARK: - Render Line

    static func renderLine(state: EditorState, offset: Int, max: Int) -> String {
        var out = ""
        let lineLength = state.lineLength
        let blocSize = state.blocSize

        // Address
        out += ANSIRenderer.resetAttributes
        out += ANSIRenderer.formatAddress(UInt64(state.base) + UInt64(offset), digits: state.nAddrDigits)
        out += "   "

        // Hex column
        for i in offset..<(offset + lineLength) {
            if i > offset {
                // Separator between bytes
                let posInLine = i - offset
                let isMarked = state.viewport.attributes[i].contains(.marked)
                let prevMarked = state.viewport.attributes[i - 1].contains(.marked)
                let bothMarked = isMarked && prevMarked

                out += ANSIRenderer.resetAttributes
                if bothMarked {
                    if state.editPane.isHex {
                        out += ANSIRenderer.reverse
                    } else {
                        out += ANSIRenderer.dim
                    }
                }

                if posInLine % blocSize == 0 {
                    out += "  "
                } else {
                    out += " "
                }
            }

            if i < max {
                let byte = state.viewport.buffer[i]
                let attr = state.viewport.attributes[i]
                let isCursorHex = (state.cursor == i && state.editPane.isHex)
                let isOtherCursorHex = (state.cursor == i && state.editPane.isAscii)
                let isMarked = attr.contains(.marked)
                let color = ByteColor(byte: byte)

                out += ANSIRenderer.attributesFor(
                    byteAttr: attr,
                    byteColor: color,
                    isCursor: isCursorHex,
                    colored: state.colored,
                    showMarked: state.editPane.isHex,
                    isOtherCursor: isOtherCursorHex,
                    isOtherMarked: !state.editPane.isHex && isMarked
                )
                out += ANSIRenderer.hexByte(byte)
            } else {
                out += ANSIRenderer.resetAttributes
                out += "  "
            }
        }

        // ASCII column
        out += ANSIRenderer.resetAttributes
        out += "  "
        for i in offset..<(offset + lineLength) {
            if i >= max {
                out += ANSIRenderer.resetAttributes
                out += " "
            } else {
                let byte = state.viewport.buffer[i]
                let attr = state.viewport.attributes[i]
                let isCursorAscii = (state.cursor == i && state.editPane.isAscii)
                let isOtherCursorAscii = (state.cursor == i && state.editPane.isHex)
                let isMarked = attr.contains(.marked)
                let color = ByteColor(byte: byte)

                out += ANSIRenderer.attributesFor(
                    byteAttr: attr,
                    byteColor: color,
                    isCursor: isCursorAscii,
                    colored: state.colored,
                    showMarked: state.editPane.isAscii,
                    isOtherCursor: isOtherCursorAscii,
                    isOtherMarked: !state.editPane.isAscii && isMarked
                )
                out += String(ANSIRenderer.printableChar(byte))
            }
        }

        out += ANSIRenderer.resetAttributes
        return out
    }

    // MARK: - Status Bar

    static func renderStatusBar(state: EditorState, termSize: TerminalSize) -> String {
        var out = ""
        let lastRow = termSize.rows - 1

        out += ANSIRenderer.moveTo(row: lastRow, col: 0)
        out += ANSIRenderer.resetAttributes

        // Build status line
        let separator = String(repeating: "-", count: state.colsUsed)
        out += separator
        out += ANSIRenderer.moveTo(row: lastRow, col: 0)

        let modChar: Character
        if state.isReadOnly {
            modChar = "%"
        } else if state.edits.hasEdits {
            modChar = "*"
        } else {
            modChar = "-"
        }

        let pos = state.base + Int64(state.cursor)
        var status = "-\(modChar)\(modChar)  \(state.baseName)       --0x\(String(pos, radix: 16, uppercase: true))"

        let fsize = state.getfilesize()
        if max(state.fileSize, state.lastEditedLoc) > 0 {
            status += "/0x\(String(fsize, radix: 16, uppercase: true))"
        }

        let percentage: Int
        if fsize == 0 {
            percentage = 0
        } else {
            percentage = Int(100 * (pos + fsize / 200) / fsize)
        }
        status += "--\(percentage)%"

        if state.mode == .bySector {
            status += "--sector \(pos / sectorSize)"
        }

        out += status
        out += ANSIRenderer.clearToEndOfLine

        return out
    }
}
