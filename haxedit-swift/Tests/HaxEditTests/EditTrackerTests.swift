import XCTest
@testable import HaxEdit

final class EditTrackerTests: XCTestCase {

    // MARK: - Basic Add

    func testAddSingleByte() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [0xAB])
        XCTAssertEqual(tracker.lastEditedLoc, 11)
        XCTAssertEqual(tracker.getValue(at: 10), 0xAB)
        XCTAssertNil(tracker.getValue(at: 9))
        XCTAssertNil(tracker.getValue(at: 11))
    }

    func testAddMultipleBytes() {
        let tracker = EditTracker()
        tracker.add(base: 100, vals: [1, 2, 3, 4, 5])
        XCTAssertEqual(tracker.lastEditedLoc, 105)
        XCTAssertEqual(tracker.getValue(at: 100), 1)
        XCTAssertEqual(tracker.getValue(at: 104), 5)
    }

    func testAddSeparatePages() {
        let tracker = EditTracker()
        tracker.add(base: 0, vals: [0xAA])
        tracker.add(base: 100, vals: [0xBB])
        XCTAssertEqual(tracker.getValue(at: 0), 0xAA)
        XCTAssertEqual(tracker.getValue(at: 100), 0xBB)
        XCTAssertNil(tracker.getValue(at: 50))
        XCTAssertEqual(tracker.lastEditedLoc, 101)
    }

    // MARK: - Coalescing

    func testCoalesceAdjacentAfter() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2])
        tracker.add(base: 12, vals: [3, 4])
        // Should coalesce into single page [10..14)
        XCTAssertEqual(tracker.getValue(at: 10), 1)
        XCTAssertEqual(tracker.getValue(at: 11), 2)
        XCTAssertEqual(tracker.getValue(at: 12), 3)
        XCTAssertEqual(tracker.getValue(at: 13), 4)

        // Verify it's a single page
        var count = 0
        tracker.forEachPage { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testCoalesceAdjacentBefore() {
        let tracker = EditTracker()
        tracker.add(base: 12, vals: [3, 4])
        tracker.add(base: 10, vals: [1, 2])
        XCTAssertEqual(tracker.getValue(at: 10), 1)
        XCTAssertEqual(tracker.getValue(at: 13), 4)

        var count = 0
        tracker.forEachPage { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testCoalesceOverlap() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2, 3])
        tracker.add(base: 12, vals: [0xAA, 0xBB])
        // Overlap at position 12: should use new value
        XCTAssertEqual(tracker.getValue(at: 10), 1)
        XCTAssertEqual(tracker.getValue(at: 11), 2)
        XCTAssertEqual(tracker.getValue(at: 12), 0xAA)
        XCTAssertEqual(tracker.getValue(at: 13), 0xBB)
    }

    func testCoalesceCompleteOverwrite() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2, 3])
        tracker.add(base: 9, vals: [0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
        // Old page [10..13) is completely within new [9..14)
        XCTAssertEqual(tracker.getValue(at: 9), 0xAA)
        XCTAssertEqual(tracker.getValue(at: 10), 0xBB)
        XCTAssertEqual(tracker.getValue(at: 13), 0xEE)

        var count = 0
        tracker.forEachPage { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testCoalesceThreePages() {
        let tracker = EditTracker()
        tracker.add(base: 0, vals: [1, 2])
        tracker.add(base: 4, vals: [5, 6])
        tracker.add(base: 2, vals: [3, 4])
        // Now [0..2) + [2..4) + [4..6) should merge into [0..6)
        XCTAssertEqual(tracker.getValue(at: 0), 1)
        XCTAssertEqual(tracker.getValue(at: 2), 3)
        XCTAssertEqual(tracker.getValue(at: 5), 6)
    }

    // MARK: - Remove

    func testRemoveEntirePage() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2, 3])
        tracker.remove(base: 10, size: 3)
        XCTAssertNil(tracker.getValue(at: 10))
        XCTAssertFalse(tracker.hasEdits)
    }

    func testRemoveFromStart() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2, 3, 4])
        tracker.remove(base: 10, size: 2)
        XCTAssertNil(tracker.getValue(at: 10))
        XCTAssertNil(tracker.getValue(at: 11))
        XCTAssertEqual(tracker.getValue(at: 12), 3)
        XCTAssertEqual(tracker.getValue(at: 13), 4)
    }

    func testRemoveFromEnd() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2, 3, 4])
        tracker.remove(base: 12, size: 2)
        XCTAssertEqual(tracker.getValue(at: 10), 1)
        XCTAssertEqual(tracker.getValue(at: 11), 2)
        XCTAssertNil(tracker.getValue(at: 12))
    }

    func testRemoveFromMiddle() {
        let tracker = EditTracker()
        tracker.add(base: 10, vals: [1, 2, 3, 4, 5])
        tracker.remove(base: 12, size: 1)
        XCTAssertEqual(tracker.getValue(at: 10), 1)
        XCTAssertEqual(tracker.getValue(at: 11), 2)
        XCTAssertNil(tracker.getValue(at: 12))
        XCTAssertEqual(tracker.getValue(at: 13), 4)
        XCTAssertEqual(tracker.getValue(at: 14), 5)

        // Should be split into two pages
        var count = 0
        tracker.forEachPage { _ in count += 1 }
        XCTAssertEqual(count, 2)
    }

    // MARK: - Discard

    func testDiscardAll() {
        let tracker = EditTracker()
        tracker.add(base: 0, vals: [1, 2, 3])
        tracker.add(base: 100, vals: [4, 5, 6])
        tracker.discardAll()
        XCTAssertFalse(tracker.hasEdits)
        XCTAssertEqual(tracker.lastEditedLoc, 0)
    }

    // MARK: - Sequential Single Byte Edits

    func testSequentialSingleByteEdits() {
        let tracker = EditTracker()
        for i in 0..<10 {
            tracker.add(base: Int64(i), vals: [UInt8(i)])
        }
        for i in 0..<10 {
            XCTAssertEqual(tracker.getValue(at: Int64(i)), UInt8(i))
        }
        // All should coalesce into a single page
        var count = 0
        tracker.forEachPage { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }
}
