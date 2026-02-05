import XCTest
@testable import HaxEdit

// Mock Terminal for testing
class MockTerminal: TerminalProtocol {
    var size = TerminalSize(cols: 80, rows: 24)
    var inputBuffer: [UInt8] = []
    var resizePending = false

    func readByte(timeout: Int) -> UInt8? {
        if resizePending {
            resizePending = false
            return nil // Simulate read interrupted by signal (handled via checkResize)
        }
        guard !inputBuffer.isEmpty else { return nil }
        return inputBuffer.removeFirst()
    }

    func readByteImmediate() -> UInt8? {
        guard !inputBuffer.isEmpty else { return nil }
        return inputBuffer.removeFirst()
    }

    func checkResize() -> Bool {
        if resizePending {
            resizePending = false
            return true
        }
        return false
    }

    func writeBytes(_ bytes: [UInt8]) {}
    func writeString(_ string: String) {}
    func flush() {}
    func suspend() {}

    // Helper to queue input
    func queueInput(_ bytes: [UInt8]) {
        inputBuffer.append(contentsOf: bytes)
    }

    func queueInput(_ string: String) {
        inputBuffer.append(contentsOf: Array(string.utf8))
    }
}

// Make EditorAction Equatable for testing
extension EditorAction: Equatable {
    public static func == (lhs: EditorAction, rhs: EditorAction) -> Bool {
        switch (lhs, rhs) {
        case (.forwardChar, .forwardChar),
             (.backwardChar, .backwardChar),
             (.nextLine, .nextLine),
             (.previousLine, .previousLine),
             (.forwardChars, .forwardChars),
             (.backwardChars, .backwardChars),
             (.nextLines, .nextLines),
             (.previousLines, .previousLines),
             (.beginningOfLine, .beginningOfLine),
             (.endOfLine, .endOfLine),
             (.scrollUp, .scrollUp),
             (.scrollDown, .scrollDown),
             (.beginningOfBuffer, .beginningOfBuffer),
             (.endOfBuffer, .endOfBuffer),
             (.deleteBackwardChar, .deleteBackwardChar),
             (.deleteBackwardChars, .deleteBackwardChars),
             (.quotedInsert, .quotedInsert),
             (.toggleHexAscii, .toggleHexAscii),
             (.recenter, .recenter),
             (.redisplay, .redisplay),
             (.save, .save),
             (.findFile, .findFile),
             (.truncateFile, .truncateFile),
             (.gotoChar, .gotoChar),
             (.gotoSector, .gotoSector),
             (.searchForward, .searchForward),
             (.searchBackward, .searchBackward),
             (.setMark, .setMark),
             (.copyRegion, .copyRegion),
             (.yank, .yank),
             (.yankToFile, .yankToFile),
             (.fillWithString, .fillWithString),
             (.help, .help),
             (.suspend, .suspend),
             (.undo, .undo),
             (.quit, .quit),
             (.askSaveAndQuit, .askSaveAndQuit):
            return true
        case (.insertChar(let a), .insertChar(let b)):
            return a == b
        case (.mouseEvent(let r1, let c1, let t1), .mouseEvent(let r2, let c2, let t2)):
            return r1 == r2 && c1 == c2 && t1 == t2
        default:
            return false
        }
    }
}
