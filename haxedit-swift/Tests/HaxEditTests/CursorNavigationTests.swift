import XCTest
@testable import HaxEdit

final class CursorNavigationTests: XCTestCase {

    /// Helper to create a state with a temp file
    private func makeState(fileData: [UInt8]) throws -> EditorState {
        let path = "/tmp/haxedit_test_nav.bin"
        fileData.withUnsafeBufferPointer { buf in
            let fd = platformOpen(path, platformO_WRONLY | platformO_CREAT | platformO_TRUNC, 0o666)
            _ = platformWrite(fd, buf.baseAddress!, fileData.count)
            _ = platformClose(fd)
        }

        var state = EditorState()
        state.mode = .maximized
        state.lineLength = 16
        state.blocSize = 4
        state.page = 256
        state.colsUsed = 80
        state.nAddrDigits = 8
        state.normalSpaces = 3
        state.viewport = Viewport(pageSize: 256)

        try state.openFile(path)
        state.readFile()
        return state
    }

    func testMoveCursorForward() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        XCTAssertEqual(state.cursor, 0)
        state.moveCursor(1)
        XCTAssertEqual(state.cursor, 1)
        state.moveCursor(10)
        XCTAssertEqual(state.cursor, 11)
    }

    func testMoveCursorBackward() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(10)
        state.moveCursor(-5)
        XCTAssertEqual(state.cursor, 5)
    }

    func testMoveCursorBeyondStart() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(3)
        state.moveCursor(-10)  // Should clamp to 0
        XCTAssertTrue(state.cursor >= 0)
    }

    func testSetCursorBeyondEOF() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 16))
        let result = state.setCursor(1000)
        XCTAssertFalse(result)
    }

    func testSetCursorAtEOF() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 16))
        // Should be able to set cursor at EOF (for appending)
        let result = state.setCursor(16)
        XCTAssertTrue(result)
    }

    func testBeginningOfLine() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(5)
        state.beginningOfLine()
        XCTAssertEqual(state.cursor, 0)

        state.setCursor(20)  // Second line
        state.beginningOfLine()
        XCTAssertEqual(state.cursor, 16)
    }

    func testEndOfLine() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(0)
        state.endOfLine()
        XCTAssertEqual(state.cursor, 15)
    }

    func testNextLine() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(5)
        state.nextLine()
        XCTAssertEqual(state.cursor, 21)  // 5 + 16
    }

    func testPreviousLine() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(20)
        state.previousLine()
        XCTAssertEqual(state.cursor, 4)  // 20 - 16
    }

    func testBeginningOfBuffer() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.setCursor(30)
        state.beginningOfBuffer()
        XCTAssertEqual(state.cursor, 0)
        XCTAssertEqual(state.base, 0)
    }

    func testEndOfBuffer() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        state.endOfBuffer()
        XCTAssertEqual(state.base + Int64(state.cursor), 64)
    }

    func testCursorOffset() throws {
        var state = try makeState(fileData: [UInt8](repeating: 0xAA, count: 64))
        XCTAssertEqual(state.cursorOffset, 0)
        state.editPane = .hex

        // Forward char in hex mode should toggle nibble
        state.forwardChar()
        XCTAssertEqual(state.cursorOffset, 1)  // Now on low nibble
        XCTAssertEqual(state.cursor, 0)  // Cursor hasn't moved yet

        state.forwardChar()
        XCTAssertEqual(state.cursorOffset, 0)  // Back to high nibble
        XCTAssertEqual(state.cursor, 1)  // Now moved to next byte
    }

    override func tearDown() {
        unlink("/tmp/haxedit_test_nav.bin")
        super.tearDown()
    }
}
