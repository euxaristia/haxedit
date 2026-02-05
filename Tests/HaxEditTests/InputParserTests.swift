import XCTest
@testable import HaxEdit

final class InputParserTests: XCTestCase {

    var mockTerminal: MockTerminal!
    var parser: InputParser!

    override func setUp() {
        super.setUp()
        mockTerminal = MockTerminal()
        parser = InputParser(terminal: mockTerminal)
    }

    // MARK: - Key Parsing Tests

    func testParseSimpleChar() {
        mockTerminal.queueInput("a")
        XCTAssertEqual(parser.readKey(), .char(UInt8(ascii: "a")))
    }

    func testParseCtrlKey() {
        mockTerminal.queueInput([0x01]) // Ctrl+A
        XCTAssertEqual(parser.readKey(), .ctrl(0x01))
    }

    func testParseArrowKeys() {
        // Up Arrow: ESC [ A
        mockTerminal.queueInput([0x1B, UInt8(ascii: "["), UInt8(ascii: "A")])
        XCTAssertEqual(parser.readKey(), .arrow(.up))
    }

    func testParseFunctionKeys() {
        // F1: ESC O P
        mockTerminal.queueInput([0x1B, UInt8(ascii: "O"), UInt8(ascii: "P")])
        XCTAssertEqual(parser.readKey(), .functionKey(1))
    }

    func testParseCSIu() {
        // Ctrl+Shift+C: ESC [ 99 ; 6 u
        mockTerminal.queueInput([0x1B, UInt8(ascii: "["), UInt8(ascii: "9"), UInt8(ascii: "9"), UInt8(ascii: ";"), UInt8(ascii: "6"), UInt8(ascii: "u")])
        XCTAssertEqual(parser.readKey(), .ctrlShift(UInt8(ascii: "c")))
    }

    // MARK: - Mouse Tracking Tests

    func testSGRMousePress() {
        // ESC [ < 0 ; 10 ; 20 M  (Left Button Press at col 10, row 20)
        // 0 = left button
        // 10 = x (col) -> 1-based, so col index 9
        // 20 = y (row) -> 1-based, so row index 19
        // M = Press/Drag
        let seq = "\u{1b}[<0;10;20M"
        mockTerminal.queueInput(seq)
        
        // Expected: MouseButton.left, .press, row 19, col 9
        XCTAssertEqual(parser.readKey(), .mouse(.left, .press, 19, 9))
    }

    func testSGRMouseRelease() {
        // ESC [ < 0 ; 10 ; 20 m  (Left Button Release)
        // m = Release
        let seq = "\u{1b}[<0;10;20m"
        mockTerminal.queueInput(seq)
        
        XCTAssertEqual(parser.readKey(), .mouse(.left, .release, 19, 9))
    }

    func testSGRMouseDrag() {
        // ESC [ < 32 ; 10 ; 20 M (Drag)
        // 32 = drag bit
        // Left button drag is usually 32 + 0 = 32
        let seq = "\u{1b}[<32;10;20M"
        mockTerminal.queueInput(seq)
        
        XCTAssertEqual(parser.readKey(), .mouse(.left, .drag, 19, 9))
    }

    func testSGRMouseRightClick() {
        // 2 = right button
        let seq = "\u{1b}[<2;5;5M"
        mockTerminal.queueInput(seq)
        XCTAssertEqual(parser.readKey(), .mouse(.right, .press, 4, 4))
    }
    
    // MARK: - KeyDispatcher Tests (Legacy)
    
    func testArrowKeysDispatch() {
        XCTAssertEqual(KeyDispatcher.dispatch(.arrow(.right), mode: .maximized, pane: .hex), .forwardChar)
        XCTAssertEqual(KeyDispatcher.dispatch(.arrow(.left), mode: .maximized, pane: .hex), .backwardChar)
    }

    func testViKeysDispatch() {
        // Hex mode: h,j,k,l work
        XCTAssertEqual(KeyDispatcher.dispatch(.char(UInt8(ascii: "h")), mode: .maximized, pane: .hex), .backwardChar)
        XCTAssertEqual(KeyDispatcher.dispatch(.char(UInt8(ascii: "j")), mode: .maximized, pane: .hex), .nextLine)
        XCTAssertEqual(KeyDispatcher.dispatch(.char(UInt8(ascii: "k")), mode: .maximized, pane: .hex), .previousLine)
        XCTAssertEqual(KeyDispatcher.dispatch(.char(UInt8(ascii: "l")), mode: .maximized, pane: .hex), .forwardChar)

        // Ascii mode: h,j,k,l insert char
        if case .insertChar(let c) = KeyDispatcher.dispatch(.char(UInt8(ascii: "h")), mode: .maximized, pane: .ascii) {
            XCTAssertEqual(c, UInt8(ascii: "h"))
        } else {
            XCTFail("Should be insertChar in ASCII mode")
        }
    }
    
    func testVisualModeKey() {
        // 'v' works in both modes
        XCTAssertEqual(KeyDispatcher.dispatch(.char(UInt8(ascii: "v")), mode: .maximized, pane: .hex), .setMark)
        XCTAssertEqual(KeyDispatcher.dispatch(.char(UInt8(ascii: "v")), mode: .maximized, pane: .ascii), .setMark)
    }
}