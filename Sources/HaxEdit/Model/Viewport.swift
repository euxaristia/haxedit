// MARK: - Viewport
// Manages the visible page buffer with edit overlays.
// Port of readFile() logic from file.c.

struct Viewport {
    var buffer: [UInt8]
    var attributes: [ByteAttribute]
    var nbBytes: Int
    let pageSize: Int

    init(pageSize: Int) {
        self.pageSize = pageSize
        self.buffer = [UInt8](repeating: 0, count: pageSize)
        self.attributes = [ByteAttribute](repeating: .normal, count: pageSize)
        self.nbBytes = 0
    }

    /// Read a page from file at the given base offset, overlay edits, apply marks.
    /// Port of readFile() from file.c.
    mutating func read(
        from fileHandle: HaxFileHandle,
        at base: Int64,
        edits: EditTracker,
        markSet: Bool,
        markMin: Int64,
        markMax: Int64
    ) {
        // Clear buffer
        buffer = [UInt8](repeating: 0, count: pageSize)
        attributes = [ByteAttribute](repeating: .normal, count: pageSize)

        // Read from file
        let result = fileHandle.readPage(at: base, size: pageSize)
        buffer = result.data
        nbBytes = result.bytesRead

        // Overlay edits
        edits.forEachPage { page in
            let overlapStart = max(base, page.base)
            let overlapEnd = min(page.base + Int64(page.size), base + Int64(pageSize))
            
            if overlapStart < overlapEnd {
                for i in overlapStart..<overlapEnd {
                    let bufIdx = Int(i - base)
                    let pageIdx = Int(i - page.base)
                    if buffer[bufIdx] != page.vals[pageIdx] {
                        buffer[bufIdx] = page.vals[pageIdx]
                        attributes[bufIdx].insert(.modified)
                    }
                }
            }
            
            // Check for modifications past EOF
            if page.base + Int64(page.size) > base + Int64(nbBytes) {
                while nbBytes < pageSize && Int64(nbBytes) < page.base + Int64(page.size) - base {
                    attributes[nbBytes].insert(.modified)
                    nbBytes += 1
                }
            }
        }

        // Apply marks
        if markSet {
            markRegion(base: base, min: markMin, max: markMax)
        }
    }

    // MARK: - Resize

    mutating func resize(newPageSize: Int) {
        buffer = [UInt8](repeating: 0, count: newPageSize)
        attributes = [ByteAttribute](repeating: .normal, count: newPageSize)
        nbBytes = 0
    }

    // MARK: - Mark Handling

    mutating func markRegion(base: Int64, min markMin: Int64, max markMax: Int64) {
        let start = Swift.max(Int(markMin - base), 0)
        let end = Swift.min(Int(markMax - base), nbBytes - 1)
        for i in start...Swift.max(start, end) {
            if i >= 0 && i < pageSize {
                attributes[i].insert(.marked)
            }
        }
    }

    mutating func unmarkRegion(base: Int64, min markMin: Int64, max markMax: Int64) {
        let start = Swift.max(Int(markMin - base), 0)
        let end = Swift.min(Int(markMax - base), nbBytes - 1)
        for i in start...Swift.max(start, end) {
            if i >= 0 && i < pageSize {
                attributes[i].remove(.marked)
            }
        }
    }

    mutating func unmarkAll() {
        for i in 0..<pageSize {
            attributes[i].remove(.marked)
        }
    }

    mutating func markIt(_ i: Int) {
        guard i >= 0 && i < pageSize else { return }
        attributes[i].insert(.marked)
    }

    mutating func unmarkIt(_ i: Int) {
        guard i >= 0 && i < pageSize else { return }
        attributes[i].remove(.marked)
    }
}
