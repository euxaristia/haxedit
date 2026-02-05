import XCTest
@testable import HaxEdit

final class ViewportTests: XCTestCase {

    func testReadFromFile() throws {
        // Create a temp file
        let path = "/tmp/haxedit_test_viewport.bin"
        let testData: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                                  0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]
        testData.withUnsafeBufferPointer { buf in
            let fd = platformOpen(path, platformO_WRONLY | platformO_CREAT | platformO_TRUNC, 0o666)
            _ = platformWrite(fd, buf.baseAddress!, testData.count)
            _ = platformClose(fd)
        }
        defer { unlink(path) }

        let fileHandle = try HaxFileHandle(fileName: path)
        let edits = EditTracker()
        var viewport = Viewport(pageSize: 32)

        viewport.read(from: fileHandle, at: 0, edits: edits, markSet: false, markMin: 0, markMax: 0)

        XCTAssertEqual(viewport.nbBytes, 16)
        XCTAssertEqual(viewport.buffer[0], 0x00)
        XCTAssertEqual(viewport.buffer[15], 0x0F)
        XCTAssertEqual(viewport.attributes[0], .normal)
    }

    func testReadWithEdits() throws {
        let path = "/tmp/haxedit_test_viewport2.bin"
        let testData: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        testData.withUnsafeBufferPointer { buf in
            let fd = platformOpen(path, platformO_WRONLY | platformO_CREAT | platformO_TRUNC, 0o666)
            _ = platformWrite(fd, buf.baseAddress!, testData.count)
            _ = platformClose(fd)
        }
        defer { unlink(path) }

        let fileHandle = try HaxFileHandle(fileName: path)
        let edits = EditTracker()
        edits.add(base: 1, vals: [0xFF])  // Edit byte at position 1

        var viewport = Viewport(pageSize: 16)
        viewport.read(from: fileHandle, at: 0, edits: edits, markSet: false, markMin: 0, markMax: 0)

        XCTAssertEqual(viewport.buffer[0], 0x00)
        XCTAssertEqual(viewport.buffer[1], 0xFF)  // Should be edited value
        XCTAssertEqual(viewport.buffer[2], 0x02)
        XCTAssertTrue(viewport.attributes[1].contains(.modified))
        XCTAssertFalse(viewport.attributes[0].contains(.modified))
    }

    func testReadWithMark() throws {
        let path = "/tmp/haxedit_test_viewport3.bin"
        let testData: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
        testData.withUnsafeBufferPointer { buf in
            let fd = platformOpen(path, platformO_WRONLY | platformO_CREAT | platformO_TRUNC, 0o666)
            _ = platformWrite(fd, buf.baseAddress!, testData.count)
            _ = platformClose(fd)
        }
        defer { unlink(path) }

        let fileHandle = try HaxFileHandle(fileName: path)
        let edits = EditTracker()
        var viewport = Viewport(pageSize: 16)

        viewport.read(from: fileHandle, at: 0, edits: edits, markSet: true, markMin: 2, markMax: 4)

        XCTAssertFalse(viewport.attributes[0].contains(.marked))
        XCTAssertFalse(viewport.attributes[1].contains(.marked))
        XCTAssertTrue(viewport.attributes[2].contains(.marked))
        XCTAssertTrue(viewport.attributes[3].contains(.marked))
        XCTAssertTrue(viewport.attributes[4].contains(.marked))
        XCTAssertFalse(viewport.attributes[5].contains(.marked))
    }

    func testResize() {
        var viewport = Viewport(pageSize: 16)
        XCTAssertEqual(viewport.buffer.count, 16)
        viewport.resize(newPageSize: 256)
        XCTAssertEqual(viewport.buffer.count, 256)
        XCTAssertEqual(viewport.attributes.count, 256)
    }
}
