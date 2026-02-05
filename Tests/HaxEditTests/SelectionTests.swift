import XCTest
@testable import HaxEdit

final class SelectionTests: XCTestCase {

    func testToggle() {
        var sel = Selection()
        XCTAssertFalse(sel.isSet)

        sel.toggle(at: 100)
        XCTAssertTrue(sel.isSet)
        XCTAssertEqual(sel.min, 100)
        XCTAssertEqual(sel.max, 100)

        sel.toggle(at: 100)
        XCTAssertFalse(sel.isSet)
    }

    func testClear() {
        var sel = Selection()
        sel.toggle(at: 50)
        XCTAssertTrue(sel.isSet)
        sel.clear()
        XCTAssertFalse(sel.isSet)
    }

    func testUpdateForward() {
        var sel = Selection()
        sel.toggle(at: 10)
        var viewport = Viewport(pageSize: 256)
        viewport.nbBytes = 256

        sel.update(oldPos: 10, newPos: 15, fileSize: 256, viewport: &viewport, base: 0)
        XCTAssertEqual(sel.min, 10)
        XCTAssertEqual(sel.max, 15)
    }

    func testUpdateBackward() {
        var sel = Selection()
        sel.toggle(at: 10)
        var viewport = Viewport(pageSize: 256)
        viewport.nbBytes = 256

        sel.update(oldPos: 10, newPos: 5, fileSize: 256, viewport: &viewport, base: 0)
        XCTAssertEqual(sel.min, 5)
        XCTAssertEqual(sel.max, 10)
    }

    func testUpdateExpandThenShrink() {
        var sel = Selection()
        sel.toggle(at: 10)
        var viewport = Viewport(pageSize: 256)
        viewport.nbBytes = 256

        // Expand forward
        sel.update(oldPos: 10, newPos: 20, fileSize: 256, viewport: &viewport, base: 0)
        XCTAssertEqual(sel.min, 10)
        XCTAssertEqual(sel.max, 20)

        // Shrink from end
        sel.update(oldPos: 20, newPos: 15, fileSize: 256, viewport: &viewport, base: 0)
        XCTAssertEqual(sel.min, 10)
        XCTAssertEqual(sel.max, 15)
    }

    func testClampToFileSize() {
        var sel = Selection()
        sel.toggle(at: 10)
        var viewport = Viewport(pageSize: 256)
        viewport.nbBytes = 20

        sel.update(oldPos: 10, newPos: 25, fileSize: 20, viewport: &viewport, base: 0)
        XCTAssertEqual(sel.max, 19)  // clamped to fileSize - 1
    }
}
