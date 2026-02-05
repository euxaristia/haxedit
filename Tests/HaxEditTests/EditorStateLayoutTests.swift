import XCTest
@testable import HaxEdit

final class EditorStateLayoutTests: XCTestCase {

    var state: EditorState!

    override func setUp() {
        super.setUp()
        state = EditorState()
        state.mode = .maximized
        state.lineLength = 16
        state.blocSize = 4
        state.page = 256
        state.colsUsed = 80 // Arbitrary, but needs to be enough
        state.nAddrDigits = 8
        state.normalSpaces = 3
        state.cursorOffset = 0
        state.editPane = .hex
    }

    func testComputeCursorXPosHex() {
        // cursor = 0, pane = .hex, offset = 0 (high nibble)
        // format: ADDRESS   XX
        // Digits(8) + 3 spaces = 11
        // Hex starts at 11
        let x = state.computeCursorXPos(cursor: 0, pane: .hex, offset: 0)
        XCTAssertEqual(x, 11)

        // offset = 1 (low nibble)
        let xLow = state.computeCursorXPos(cursor: 0, pane: .hex, offset: 1)
        XCTAssertEqual(xLow, 12)
    }

    func testComputeCursorXPosAscii() {
        // ASCII starts after hex block
        // Hex block width for 16 bytes:
        // 16 bytes * 2 chars + spaces
        // It's easier to check relative to hex
        // Let's compute expected ASCII pos for index 0
        let xAscii = state.computeCursorXPos(cursor: 0, pane: .ascii)
        
        // It should be > hex position
        XCTAssertGreaterThan(xAscii, 12)
    }

    func testFindOffsetFromHex() {
        // 0th byte, high nibble
        let x = state.computeCursorXPos(cursor: 0, pane: .hex, offset: 0)
        let result = state.findOffsetFrom(row: 0, col: x)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cursor, 0)
        XCTAssertEqual(result?.pane, .hex)
        XCTAssertEqual(result?.offset, 0)
    }

    func testFindOffsetFromHexLowNibble() {
        // 0th byte, low nibble
        let x = state.computeCursorXPos(cursor: 0, pane: .hex, offset: 1)
        let result = state.findOffsetFrom(row: 0, col: x)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cursor, 0)
        XCTAssertEqual(result?.pane, .hex)
        XCTAssertEqual(result?.offset, 1)
    }

    func testFindOffsetFromAscii() {
        // 0th byte, ascii
        let x = state.computeCursorXPos(cursor: 0, pane: .ascii)
        let result = state.findOffsetFrom(row: 0, col: x)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cursor, 0)
        XCTAssertEqual(result?.pane, .ascii)
        // Offset is ignored/0 for ASCII
        XCTAssertEqual(result?.offset, 0)
    }

    func testFindOffsetFromSecondLine() {
        // 16th byte (start of second line)
        let row = 1
        let col = state.computeCursorXPos(cursor: 0, pane: .hex, offset: 0) // same X relative to line
        
        // Mock state so findOffsetFrom works
        // findOffsetFrom uses (row * lineLength + x)
        
        let result = state.findOffsetFrom(row: row, col: col)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cursor, 16) // 1 * 16 + 0
        XCTAssertEqual(result?.pane, .hex)
    }
    
    func testClickVoid() {
        // Click on address area (col 0)
        let result = state.findOffsetFrom(row: 0, col: 0)
        XCTAssertNil(result)
    }
}
