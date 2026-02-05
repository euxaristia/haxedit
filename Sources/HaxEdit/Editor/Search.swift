#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Search
// Forward/backward block-based search. Port of search.c.

struct Search {

    /// Search forward from cursor position.
    static func forward(
        state: inout EditorState,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard let pattern = getSearchPattern(
            state: &state,
            terminal: terminal,
            inputParser: inputParser,
            termSize: termSize
        ) else { return }

        let fd = state.fileHandle.fd
        var searchBuf = [UInt8](repeating: 0, count: blockSearchSize)
        var blockstart = state.base + Int64(state.cursor) - Int64(blockSearchSize) + Int64(pattern.count)
        var quit: Int64 = -1

        repeat {
            blockstart += Int64(blockSearchSize) - Int64(pattern.count) + 1

            if platformLseek(fd, off_t(blockstart), SEEK_SET) != off_t(blockstart) {
                quit = -3; break
            }

            let bytesRead = searchBuf.withUnsafeMutableBufferPointer { buf in
                platformRead(fd, buf.baseAddress!, blockSearchSize)
            }

            if bytesRead < pattern.count {
                quit = -3
            } else if let key = inputParser.readKeyNonBlocking(), key != .none {
                quit = -2
            } else {
                if let offset = searchBuf.withUnsafeBufferPointer({ buf in
                    let slice = UnsafeBufferPointer(start: buf.baseAddress, count: bytesRead)
                    return memorySearch(haystack: slice, needle: pattern)
                }) {
                    quit = Int64(offset)
                }
            }

            let msg = "searching... 0x" + formatHex08(blockstart)
            Prompt.displayTwoLineMessage(
                msg, "(press any key to cancel)",
                state: state, terminal: terminal, termSize: termSize
            )
        } while quit == -1

        finishSearch(
            state: &state,
            loc: quit >= 0 ? quit + blockstart : quit,
            terminal: terminal,
            inputParser: inputParser,
            termSize: termSize
        )
    }

    /// Search backward from cursor position.
    static func backward(
        state: inout EditorState,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        guard let pattern = getSearchPattern(
            state: &state,
            terminal: terminal,
            inputParser: inputParser,
            termSize: termSize
        ) else { return }

        let fd = state.fileHandle.fd
        var searchBuf = [UInt8](repeating: 0, count: blockSearchSize)
        var blockstart = state.base + Int64(state.cursor) - Int64(pattern.count) + 1
        var quit: Int64 = -1

        repeat {
            blockstart -= Int64(blockSearchSize) - Int64(pattern.count) + 1
            var sizeb = blockSearchSize
            if blockstart < 0 {
                sizeb -= Int(-blockstart)
                blockstart = 0
            }

            if sizeb < pattern.count {
                quit = -3
            } else {
                if platformLseek(fd, off_t(blockstart), SEEK_SET) != off_t(blockstart) {
                    quit = -3; break
                }
                let bytesRead = searchBuf.withUnsafeMutableBufferPointer { buf in
                    platformRead(fd, buf.baseAddress!, sizeb)
                }
                if bytesRead != sizeb {
                    quit = -3
                } else if let key = inputParser.readKeyNonBlocking(), key != .none {
                    quit = -2
                } else {
                    if let offset = searchBuf.withUnsafeBufferPointer({ buf in
                        let slice = UnsafeBufferPointer(start: buf.baseAddress, count: bytesRead)
                        return memorySearchReverse(haystack: slice, needle: pattern)
                    }) {
                        quit = Int64(offset)
                    }
                }
            }

            let msg = "searching... 0x" + formatHex08(blockstart)
            Prompt.displayTwoLineMessage(
                msg, "(press any key to cancel)",
                state: state, terminal: terminal, termSize: termSize
            )
        } while quit == -1

        finishSearch(
            state: &state,
            loc: quit >= 0 ? quit + blockstart : quit,
            terminal: terminal,
            inputParser: inputParser,
            termSize: termSize
        )
    }

    // MARK: - Helpers

    private static func getSearchPattern(
        state: inout EditorState,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize
    ) -> [UInt8]? {
        let msg = state.editPane.isHex ? "Hexa string to search: " : "Ascii string to search: "
        let lastValue = state.editPane.isHex ? state.lastAskHexString : state.lastAskAsciiString

        guard let input = Prompt.displayMessageAndGetString(
            msg,
            lastValue: lastValue,
            state: state,
            terminal: terminal,
            inputParser: inputParser,
            termSize: termSize
        ) else { return nil }

        // Remember the search string
        if state.editPane.isHex {
            state.lastAskHexString = input
        } else {
            state.lastAskAsciiString = input
        }

        if state.editPane.isHex {
            guard let result = hexStringToBinString(input) else { return nil }
            if let err = result.errorMessage {
                Prompt.displayMessageAndWaitForKey(
                    err, state: state, terminal: terminal,
                    inputParser: inputParser, termSize: termSize
                )
                return nil
            }
            return result.data
        } else {
            return Array(input.utf8)
        }
    }

    private static func finishSearch(
        state: inout EditorState,
        loc: Int64,
        terminal: Terminal,
        inputParser: InputParser,
        termSize: TerminalSize
    ) {
        if loc >= 0 {
            state.setCursor(loc)
        } else if loc == -3 {
            Prompt.displayMessageAndWaitForKey(
                "not found",
                state: state, terminal: terminal,
                inputParser: inputParser, termSize: termSize
            )
        }
        // loc == -2 means cancelled, do nothing
    }
}
