import XCTest
@testable import HaxEdit

// Since InputParser depends on Terminal (final class) and we can't easily mock it,
// we test the key dispatch mapping and utility functions instead.

final class InputParserTests: XCTestCase {

    // MARK: - KeyDispatcher mapping tests

    func testArrowKeys() {
        XCTAssertEqual(KeyDispatcher.dispatch(.arrow(.right), mode: .maximized), .forwardChar)
        XCTAssertEqual(KeyDispatcher.dispatch(.arrow(.left), mode: .maximized), .backwardChar)
        XCTAssertEqual(KeyDispatcher.dispatch(.arrow(.down), mode: .maximized), .nextLine)
        XCTAssertEqual(KeyDispatcher.dispatch(.arrow(.up), mode: .maximized), .previousLine)
    }

    func testCtrlKeys() {
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x06), mode: .maximized), .forwardChar)   // Ctrl+F
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x02), mode: .maximized), .backwardChar)  // Ctrl+B
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x0E), mode: .maximized), .nextLine)      // Ctrl+N
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x10), mode: .maximized), .previousLine)  // Ctrl+P
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x01), mode: .maximized), .beginningOfLine) // Ctrl+A
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x05), mode: .maximized), .endOfLine)     // Ctrl+E
    }

    func testFunctionKeys() {
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(1), mode: .maximized), .help)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(2), mode: .maximized), .save)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(3), mode: .maximized), .findFile)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(4), mode: .maximized), .gotoChar)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(5), mode: .maximized), .scrollDown)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(6), mode: .maximized), .scrollUp)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(7), mode: .maximized), .copyRegion)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(8), mode: .maximized), .yank)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(9), mode: .maximized), .setMark)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(10), mode: .maximized), .askSaveAndQuit)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(11), mode: .maximized), .yankToFile)
        XCTAssertEqual(KeyDispatcher.dispatch(.functionKey(12), mode: .maximized), .fillWithString)
    }

    func testSpecialKeys() {
        XCTAssertEqual(KeyDispatcher.dispatch(.home, mode: .maximized), .beginningOfLine)
        XCTAssertEqual(KeyDispatcher.dispatch(.end, mode: .maximized), .endOfLine)
        XCTAssertEqual(KeyDispatcher.dispatch(.pageDown, mode: .maximized), .scrollUp)
        XCTAssertEqual(KeyDispatcher.dispatch(.pageUp, mode: .maximized), .scrollDown)
        XCTAssertEqual(KeyDispatcher.dispatch(.insert, mode: .maximized), .yank)
        XCTAssertEqual(KeyDispatcher.dispatch(.delete, mode: .maximized), .copyRegion)
        XCTAssertEqual(KeyDispatcher.dispatch(.backspace, mode: .maximized), .deleteBackwardChar)
        XCTAssertEqual(KeyDispatcher.dispatch(.tab, mode: .maximized), .toggleHexAscii)
    }

    func testEnterBySectorMode() {
        XCTAssertEqual(KeyDispatcher.dispatch(.enter, mode: .bySector), .gotoSector)
        XCTAssertEqual(KeyDispatcher.dispatch(.enter, mode: .maximized), .gotoChar)
    }

    func testPrintableCharsToInsert() {
        if case .insertChar(let c) = KeyDispatcher.dispatch(.char(UInt8(ascii: "a")), mode: .maximized) {
            XCTAssertEqual(c, UInt8(ascii: "a"))
        } else {
            XCTFail("Expected insertChar")
        }
    }

    func testAltKeys() {
        XCTAssertEqual(
            KeyDispatcher.dispatch(.alt(UInt8(ascii: "f")), mode: .maximized),
            .forwardChars
        )
        XCTAssertEqual(
            KeyDispatcher.dispatch(.alt(UInt8(ascii: "v")), mode: .maximized),
            .scrollDown
        )
        XCTAssertEqual(
            KeyDispatcher.dispatch(.alt(UInt8(ascii: "<")), mode: .maximized),
            .beginningOfBuffer
        )
    }

    func testSaveQuitKeys() {
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x17), mode: .maximized), .save)     // Ctrl+W
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x18), mode: .maximized), .askSaveAndQuit) // Ctrl+X
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x03), mode: .maximized), .quit)      // Ctrl+C
    }

    func testSearchKeys() {
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x13), mode: .maximized), .searchForward)  // Ctrl+S
        XCTAssertEqual(KeyDispatcher.dispatch(.ctrl(0x12), mode: .maximized), .searchBackward) // Ctrl+R
        XCTAssertEqual(
            KeyDispatcher.dispatch(.char(UInt8(ascii: "/")), mode: .maximized),
            .searchForward
        )
    }

    // MARK: - KeyEvent equality

    func testKeyEventEquality() {
        XCTAssertEqual(KeyEvent.char(65), KeyEvent.char(65))
        XCTAssertNotEqual(KeyEvent.char(65), KeyEvent.char(66))
        XCTAssertEqual(KeyEvent.arrow(.up), KeyEvent.arrow(.up))
        XCTAssertNotEqual(KeyEvent.arrow(.up), KeyEvent.arrow(.down))
        XCTAssertEqual(KeyEvent.functionKey(1), KeyEvent.functionKey(1))
        XCTAssertNotEqual(KeyEvent.functionKey(1), KeyEvent.functionKey(2))
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
        default:
            return false
        }
    }
}
