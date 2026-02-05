// MARK: - Clipboard

struct Clipboard {
    var data: [UInt8]?

    var isEmpty: Bool { data == nil || data!.isEmpty }
    var size: Int { data?.count ?? 0 }

    mutating func set(_ bytes: [UInt8]) {
        data = bytes
    }

    mutating func clear() {
        data = nil
    }
}
