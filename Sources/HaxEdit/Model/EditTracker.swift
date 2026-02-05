// MARK: - Edit Page (linked list node)

/// Represents a contiguous range of edited bytes.
/// This is a class (reference type) because it forms a linked list.
final class EditPage {
    var base: Int64
    var size: Int
    var vals: [UInt8]
    var next: EditPage?

    init(base: Int64, size: Int) {
        self.base = base
        self.size = size
        self.vals = [UInt8](repeating: 0, count: size)
        self.next = nil
    }

    init(base: Int64, vals: [UInt8]) {
        self.base = base
        self.size = vals.count
        self.vals = vals
        self.next = nil
    }
}

// MARK: - Edit Tracker

/// Manages a sorted linked list of edit pages (non-overlapping, coalescing).
/// Direct port of page.c from the original hexedit.
final class EditTracker {
    private(set) var head: EditPage?
    private(set) var lastEditedLoc: Int64 = 0

    /// Whether any edits have been made
    var hasEdits: Bool { head != nil }

    // MARK: - Add Edits

    /// Add edited bytes at the given position, coalescing with adjacent/overlapping pages.
    /// Port of addToEdited() from page.c.
    func add(base: Int64, vals: [UInt8]) {
        let size = vals.count
        guard size > 0 else { return }

        // First pass: remove any pages completely contained within [base, base+size)
        var p = head
        var q: EditPage? = nil

        while let current = p {
            if base + Int64(size) <= current.base { break }
            if base <= current.base && current.base + Int64(current.size) <= base + Int64(size) {
                // Current page is completely within new range — remove it
                if let prev = q {
                    prev.next = current.next
                } else {
                    head = current.next
                }
                p = q  // back up
                if q == nil {
                    p = head
                    continue
                }
            }
            q = p
            p = current.next
        }

        // Reset for second pass
        p = head
        q = nil
        while let current = p {
            if base + Int64(size) <= current.base { break }
            q = current
            p = current.next
        }

        if let prev = q, base <= prev.base + Int64(prev.size) && prev.base <= base + Int64(size) {
            // Overlap with previous page (chevauchement)
            let minBase = min(prev.base, base)

            if let next = p, base + Int64(size) == next.base {
                // Also merges with next page
                let maxEnd = next.base + Int64(next.size)
                var s = [UInt8](repeating: 0, count: Int(maxEnd - minBase))
                // Copy prev values
                let prevOffset = Int(prev.base - minBase)
                for i in 0..<prev.size { s[prevOffset + i] = prev.vals[i] }
                // Copy new values (overwrites prev where overlapping)
                let newOffset = Int(base - minBase)
                for i in 0..<size { s[newOffset + i] = vals[i] }
                // Copy next values
                let nextOffset = Int(next.base - minBase)
                for i in 0..<next.size { s[nextOffset + i] = next.vals[i] }

                prev.vals = s
                prev.base = minBase
                prev.size = Int(maxEnd - minBase)
                prev.next = next.next
            } else {
                // Merge with prev only
                let maxEnd = max(prev.base + Int64(prev.size), base + Int64(size))
                var s = [UInt8](repeating: 0, count: Int(maxEnd - minBase))
                let prevOffset = Int(prev.base - minBase)
                for i in 0..<prev.size { s[prevOffset + i] = prev.vals[i] }
                let newOffset = Int(base - minBase)
                for i in 0..<size { s[newOffset + i] = vals[i] }

                prev.vals = s
                prev.base = minBase
                prev.size = Int(maxEnd - minBase)
            }
        } else if let next = p, base + Int64(size) == next.base {
            // Merge with next page only
            var s = [UInt8](repeating: 0, count: Int(next.base + Int64(next.size) - base))
            for i in 0..<size { s[i] = vals[i] }
            let nextOffset = Int(next.base - base)
            for i in 0..<next.size { s[nextOffset + i] = next.vals[i] }

            next.vals = s
            next.size = Int(next.base + Int64(next.size) - base)
            next.base = base
        } else {
            // Insert new standalone page
            let r = EditPage(base: base, vals: vals)
            if let prev = q {
                prev.next = r
            } else {
                head = r
            }
            r.next = p
        }

        updateLastEditedLoc()
    }

    // MARK: - Remove Edits

    /// Remove edits in the given range. Port of removeFromEdited() from page.c.
    func remove(base: Int64, size: Int) {
        guard size > 0 else { return }

        var p = head
        var q: EditPage? = nil

        while let current = p {
            if base + Int64(size) <= current.base { break }

            if base <= current.base {
                if current.base + Int64(current.size) <= base + Int64(size) {
                    // Entire page within removal range — remove it
                    if let prev = q {
                        prev.next = current.next
                    } else {
                        head = current.next
                    }
                    p = q
                    if q == nil {
                        p = head
                        continue
                    }
                } else {
                    // Removal clips the beginning
                    let removeCount = Int(base + Int64(size) - current.base)
                    current.size -= removeCount
                    current.vals = Array(current.vals[removeCount...])
                    current.base = base + Int64(size)
                }
            } else if current.base + Int64(current.size) <= base + Int64(size) {
                // Removal clips the end
                if base < current.base + Int64(current.size) {
                    current.size -= Int(current.base + Int64(current.size) - base)
                }
            } else {
                // Removal splits the page
                let rightBase = base + Int64(size)
                let rightSize = Int(current.base + Int64(current.size) - rightBase)
                let rightOffset = Int(rightBase - current.base)
                let rightPage = EditPage(base: rightBase, vals: Array(current.vals[rightOffset..<(rightOffset + rightSize)]))
                rightPage.next = current.next
                current.next = rightPage
                current.size = Int(base - current.base)
                break
            }

            if let pp = p {
                q = pp
                p = pp.next
            } else {
                q = nil
                p = head
            }
        }

        updateLastEditedLoc()
    }

    // MARK: - Discard All

    func discardAll() {
        head = nil
        lastEditedLoc = 0
    }

    // MARK: - Query

    /// Get the edited value at a specific position, or nil if not edited
    func getValue(at position: Int64) -> UInt8? {
        var p = head
        while let current = p {
            if position >= current.base && position < current.base + Int64(current.size) {
                return current.vals[Int(position - current.base)]
            }
            if position < current.base { break }
            p = current.next
        }
        return nil
    }

    /// Iterate over all edit pages
    func forEachPage(_ body: (EditPage) -> Void) {
        var p = head
        while let current = p {
            body(current)
            p = current.next
        }
    }

    // MARK: - Save

    /// Write all edited pages to a file handle, then clear the edit list.
    /// Returns error message if any write fails.
    func save(to fileHandle: HaxFileHandle) -> String? {
        var errorMessage: String? = nil
        var p = head
        while let current = p {
            let nextPage = current.next
            do {
                try current.vals.withUnsafeBufferPointer { buf in
                    try fileHandle.write(data: buf.baseAddress!, count: current.size, at: current.base)
                }
            } catch {
                if errorMessage == nil {
                    errorMessage = "\(error)"
                }
            }
            p = nextPage
        }
        head = nil
        if lastEditedLoc > fileHandle.fileSize {
            fileHandle.biggestLoc = max(fileHandle.biggestLoc, lastEditedLoc)
        }
        lastEditedLoc = 0
        return errorMessage
    }

    // MARK: - Private

    private func updateLastEditedLoc() {
        lastEditedLoc = 0
        var p = head
        while let current = p {
            let end = current.base + Int64(current.size)
            if end > lastEditedLoc {
                lastEditedLoc = end
            }
            p = current.next
        }
    }
}
