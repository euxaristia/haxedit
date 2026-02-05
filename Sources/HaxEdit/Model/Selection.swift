// MARK: - Selection / Mark State
// Port of mark.c's updateMarked() logic.

struct Selection {
    var isSet: Bool = false
    var min: Int64 = 0
    var max: Int64 = 0

    mutating func toggle(at position: Int64) {
        if isSet {
            isSet = false
        } else {
            isSet = true
            min = position
            max = position
        }
    }

    mutating func clear() {
        isSet = false
        min = 0
        max = 0
    }

    /// Update selection after cursor movement.
    /// Port of updateMarked() from mark.c.
    mutating func update(oldPos: Int64, newPos: Int64, fileSize: Int64, viewport: inout Viewport, base: Int64) {
        guard isSet else { return }

        if newPos > oldPos {
            // Moving forward
            if min == max {
                max = newPos
            } else if oldPos == min {
                if newPos <= max {
                    // Shrink from start
                    viewport.unmarkRegion(base: base, min: oldPos, max: newPos - 1)
                    min = newPos
                } else {
                    // Crossed over — flip
                    viewport.unmarkRegion(base: base, min: oldPos, max: max)
                    min = max
                    max = newPos
                }
            } else {
                max = newPos
            }
        } else if newPos < oldPos {
            // Moving backward
            if min == max {
                min = newPos
            } else if oldPos == max {
                if newPos >= min {
                    // Shrink from end
                    viewport.unmarkRegion(base: base, min: newPos + 1, max: oldPos)
                    max = newPos
                } else {
                    // Crossed over — flip
                    viewport.unmarkRegion(base: base, min: min, max: oldPos)
                    viewport.markRegion(base: base, min: newPos, max: min - 1)
                    max = min
                    min = newPos
                }
            } else {
                min = newPos
            }
        }

        // Clamp to file size
        if max >= fileSize {
            max = fileSize - 1
        }

        // Safety: Ensure min <= max
        if min > max {
            let temp = min
            min = max
            max = temp
        }

        // Re-mark the selected region
        viewport.markRegion(base: base, min: min, max: max)
    }
}
