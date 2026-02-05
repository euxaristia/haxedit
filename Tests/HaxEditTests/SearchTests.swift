import XCTest
@testable import HaxEdit

final class SearchTests: XCTestCase {

    // MARK: - memorySearch (forward)

    func testMemorySearchFound() {
        let haystack: [UInt8] = [0x00, 0x01, 0x02, 0xAA, 0xBB, 0x05]
        let needle: [UInt8] = [0xAA, 0xBB]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearch(haystack: buf, needle: needle)
        }
        XCTAssertEqual(result, 3)
    }

    func testMemorySearchNotFound() {
        let haystack: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let needle: [UInt8] = [0xFF, 0xFE]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearch(haystack: buf, needle: needle)
        }
        XCTAssertNil(result)
    }

    func testMemorySearchAtStart() {
        let haystack: [UInt8] = [0xAA, 0xBB, 0xCC]
        let needle: [UInt8] = [0xAA, 0xBB]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearch(haystack: buf, needle: needle)
        }
        XCTAssertEqual(result, 0)
    }

    func testMemorySearchAtEnd() {
        let haystack: [UInt8] = [0x00, 0x01, 0xAA, 0xBB]
        let needle: [UInt8] = [0xAA, 0xBB]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearch(haystack: buf, needle: needle)
        }
        XCTAssertEqual(result, 2)
    }

    func testMemorySearchSingleByte() {
        let haystack: [UInt8] = [0x00, 0x01, 0xFF, 0x03]
        let needle: [UInt8] = [0xFF]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearch(haystack: buf, needle: needle)
        }
        XCTAssertEqual(result, 2)
    }

    func testMemorySearchNeedleLargerThanHaystack() {
        let haystack: [UInt8] = [0x00, 0x01]
        let needle: [UInt8] = [0x00, 0x01, 0x02]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearch(haystack: buf, needle: needle)
        }
        XCTAssertNil(result)
    }

    // MARK: - memorySearchReverse (backward)

    func testMemorySearchReverseFound() {
        let haystack: [UInt8] = [0xAA, 0xBB, 0x00, 0xAA, 0xBB, 0x00]
        let needle: [UInt8] = [0xAA, 0xBB]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearchReverse(haystack: buf, needle: needle)
        }
        XCTAssertEqual(result, 3)  // Should find the LAST occurrence
    }

    func testMemorySearchReverseNotFound() {
        let haystack: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let needle: [UInt8] = [0xFF]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearchReverse(haystack: buf, needle: needle)
        }
        XCTAssertNil(result)
    }

    func testMemorySearchReverseSingleOccurrence() {
        let haystack: [UInt8] = [0x00, 0xAA, 0xBB, 0x00]
        let needle: [UInt8] = [0xAA, 0xBB]
        let result = haystack.withUnsafeBufferPointer { buf in
            memorySearchReverse(haystack: buf, needle: needle)
        }
        XCTAssertEqual(result, 1)
    }

    // MARK: - hexStringToBinString

    func testHexStringSimple() {
        let result = hexStringToBinString("AABB")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.errorMessage)
        XCTAssertEqual(result?.data, [0xAA, 0xBB])
    }

    func testHexStringWithSpaces() {
        let result = hexStringToBinString("AA BB CC")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.errorMessage)
        XCTAssertEqual(result?.data, [0xAA, 0xBB, 0xCC])
    }

    func testHexStringOddLength() {
        let result = hexStringToBinString("AAB")
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.errorMessage)  // Should error: odd number
    }

    func testHexStringInvalidChar() {
        let result = hexStringToBinString("AAXB")
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.errorMessage)  // Should error: invalid char
    }

    func testHexStringLowercase() {
        let result = hexStringToBinString("aabb")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.errorMessage)
        XCTAssertEqual(result?.data, [0xAA, 0xBB])
    }
}
