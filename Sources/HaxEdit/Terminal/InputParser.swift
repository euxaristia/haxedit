// MARK: - Input Parser State Machine
// Converts raw terminal byte stream into KeyEvent values.
// Handles:
//   - Single bytes (printable, Ctrl+X)
//   - ESC sequences (Alt+X)
//   - CSI sequences: ESC [ ... (arrows, F-keys, Home/End/PgUp/PgDn/Ins/Del)
//   - SS3 sequences: ESC O ... (F1-F4, arrows)

final class InputParser {
    private let terminal: TerminalProtocol

    init(terminal: TerminalProtocol) {
        self.terminal = terminal
    }

    /// Read and parse the next key event. Blocks until input available or resize.
    func readKey() -> KeyEvent {
        // Check for resize first
        if terminal.checkResize() {
            return .resize
        }

        guard let byte = terminal.readByte(timeout: -1) else {
            // Could be a resize that consumed the read
            if terminal.checkResize() {
                return .resize
            }
            return .none
        }

        return parseByte(byte)
    }

    /// Non-blocking key read (for cancellation checks during search)
    func readKeyNonBlocking() -> KeyEvent? {
        guard let byte = terminal.readByte(timeout: 0) else {
            return nil
        }
        return parseByte(byte)
    }

    private func parseByte(_ byte: UInt8) -> KeyEvent {
        switch byte {
        case 0x1B: // ESC
            return parseEscape()
        case 0x00: // Ctrl+Space
            return .ctrl(0)
        case 0x01...0x07: // Ctrl+A through Ctrl+G
            return .ctrl(byte)
        case 0x08: // Ctrl+H / Backspace
            return .backspace
        case 0x09: // Tab
            return .tab
        case 0x0A, 0x0D: // Enter (LF or CR)
            return .enter
        case 0x0B...0x0C: // Ctrl+K, Ctrl+L
            return .ctrl(byte)
        case 0x0E...0x1A: // Ctrl+N through Ctrl+Z
            return .ctrl(byte)
        case 0x1C...0x1F: // Ctrl+\, Ctrl+], Ctrl+^, Ctrl+_
            return .ctrl(byte)
        case 0x7F: // DEL (some terminals send this for backspace)
            return .backspace
        case 0x80...0xFF:
            // High-bit set could be Alt+char (meta-sends-escape not set)
            // Original C code uses ALT(c) = c | 0xa0
            return .alt(byte & 0x7F)
        default:
            return .char(byte)
        }
    }

    // MARK: - Escape Sequence Parsing

    private func parseEscape() -> KeyEvent {
        guard let next = terminal.readByteImmediate() else {
            return .escape
        }

        switch next {
        case UInt8(ascii: "["): // CSI
            return parseCSI()
        case UInt8(ascii: "O"): // SS3
            return parseSS3()
        case 0x1B: // ESC ESC - could be double escape, or ESC [ coming
            // Try to read one more to disambiguate
            if let third = terminal.readByteImmediate() {
                if third == UInt8(ascii: "[") {
                    // ESC ESC [ — treat as Alt + CSI sequence
                    return parseAltCSI()
                } else {
                    return .escape // consume second ESC, ignore third
                }
            }
            return .escape
        case 0x01...0x1A: // ESC + Ctrl+letter = Ctrl+Alt
            return .ctrlAlt(next)
        default:
            // Alt+char
            return .alt(next)
        }
    }

    // MARK: - CSI Sequences (ESC [)

    private func parseCSI() -> KeyEvent {
        var params: [Int] = []
        var currentParam = 0
        var hasParam = false

        while true {
            guard let byte = terminal.readByteImmediate() else {
                return .escape
            }

            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                currentParam = currentParam * 10 + Int(byte - UInt8(ascii: "0"))
                hasParam = true
            case UInt8(ascii: "<"):
                // SGR mouse mode prefix
                return parseSGRMouse()
            case UInt8(ascii: ";"):
                params.append(hasParam ? currentParam : 0)
                currentParam = 0
                hasParam = false
            case UInt8(ascii: "A"):
                return .arrow(.up)
            case UInt8(ascii: "B"):
                return .arrow(.down)
            case UInt8(ascii: "C"):
                return .arrow(.right)
            case UInt8(ascii: "D"):
                return .arrow(.left)
            case UInt8(ascii: "H"):
                return .home
            case UInt8(ascii: "F"):
                return .end
            case UInt8(ascii: "~"):
                if hasParam { params.append(currentParam) }
                return csiTildeKey(params)
            case UInt8(ascii: "q"):
                // SGI-style: e.g. ESC [ 010 q = F10
                if hasParam { params.append(currentParam) }
                return csiQKey(params)
            case UInt8(ascii: "z"):
                // Sun-style: e.g. ESC [ 214 z
                if hasParam { params.append(currentParam) }
                return csiZKey(params)
            case UInt8(ascii: "u"):
                // CSI u (Enhanced Keyboard Protocol)
                if hasParam { params.append(currentParam) }
                return csiUKey(params)
            default:
                return .none
            }
        }
    }

    /// CSI sequences ending with u (CSI u / Enhanced Keyboard Protocol)
    private func csiUKey(_ params: [Int]) -> KeyEvent {
        guard params.count >= 2 else { return .none }
        let code = params[0]
        let modifier = params[1]

        // Modifier bits: 1=Shift, 2=Alt, 4=Ctrl
        // CSI u uses 1 + bits
        // 2=Shift, 3=Alt, 4=Shift+Alt, 5=Ctrl, 6=Shift+Ctrl, 7=Alt+Ctrl, 8=Shift+Alt+Ctrl
        
        switch modifier {
        case 5: // Ctrl
            return .ctrl(UInt8(code & 0xFF))
        case 6: // Ctrl + Shift
            return .ctrlShift(UInt8(code & 0xFF))
        case 2: // Shift
            return .char(UInt8(code & 0xFF)) // Should probably be upper case anyway if code is char
        default:
            return .none
        }
    }

    // Alt + CSI sequence (ESC ESC [)
    private func parseAltCSI() -> KeyEvent {
        guard let byte = terminal.readByteImmediate() else {
            return .escape
        }

        switch byte {
        case UInt8(ascii: "A"): return .altArrow(.up)
        case UInt8(ascii: "B"): return .altArrow(.down)
        case UInt8(ascii: "C"): return .altArrow(.right)
        case UInt8(ascii: "D"): return .altArrow(.left)
        default:
            // Consume rest of sequence
            while terminal.readByteImmediate() != nil {}
            return .none
        }
    }

    /// CSI sequences ending with ~ (xterm-style)
    private func csiTildeKey(_ params: [Int]) -> KeyEvent {
        guard let code = params.first else { return .none }
        switch code {
        case 27:
            // Xterm modified key: ESC [ 27 ; modifier ; code ~
            guard params.count >= 3 else { return .none }
            let modifier = params[1]
            let charCode = params[2]
            
            // Modifier bits: 1=Shift, 2=Alt, 4=Ctrl
            // Uses 1 + bits (same as CSI u)
            switch modifier {
            case 5: // Ctrl
                return .ctrl(UInt8(charCode & 0xFF))
            case 6: // Ctrl + Shift
                return .ctrlShift(UInt8(charCode & 0xFF))
            default:
                return .none
            }
        case 1:  return .home
        case 2:  return .insert
        case 3:  return .delete
        case 4:  return .end
        case 5:  return .pageUp
        case 6:  return .pageDown
        case 7:  return .home      // rxvt
        case 8:  return .end       // rxvt
        case 11: return .functionKey(1)
        case 12: return .functionKey(2)
        case 13: return .functionKey(3)
        case 14: return .functionKey(4)
        case 15: return .functionKey(5)
        case 17: return .functionKey(6)
        case 18: return .functionKey(7)
        case 19: return .functionKey(8)
        case 20: return .functionKey(9)
        case 21: return .functionKey(10)
        case 23: return .functionKey(11)
        case 24: return .functionKey(12)
        default: return .none
        }
    }

    /// CSI sequences ending with q (SGI)
    private func csiQKey(_ params: [Int]) -> KeyEvent {
        guard let code = params.first else { return .none }
        switch code {
        case 10:  return .functionKey(10)
        default:  return .none
        }
    }

    /// CSI sequences ending with z (Sun)
    private func csiZKey(_ params: [Int]) -> KeyEvent {
        guard let code = params.first else { return .none }
        switch code {
        case 193: return .functionKey(12)  // fill_with_string
        case 214: return .home
        case 216: return .pageUp
        case 220: return .end
        case 222: return .pageDown
        case 233: return .functionKey(10)
        case 234: return .functionKey(11)
        case 247: return .insert
        default:  return .none
        }
    }

    // MARK: - SS3 Sequences (ESC O)

    private func parseSGRMouse() -> KeyEvent {
        var params: [Int] = []
        var currentParam = 0
        var hasParam = false

        while true {
            guard let byte = terminal.readByteImmediate() else {
                return .none
            }

            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                currentParam = currentParam * 10 + Int(byte - UInt8(ascii: "0"))
                hasParam = true
            case UInt8(ascii: ";"):
                params.append(hasParam ? currentParam : 0)
                currentParam = 0
                hasParam = false
            case UInt8(ascii: "M"), UInt8(ascii: "m"):
                if hasParam { params.append(currentParam) }
                guard params.count >= 3 else { return .none }

                let b = params[0]
                let x = params[1]
                let y = params[2]
                let isRelease = (byte == UInt8(ascii: "m"))

                let button: MouseButton
                let type: MouseEventType

                // SGR button bits:
                // 0: left, 1: middle, 2: right, 3: release (not for SGR 'm'), 32: drag
                if (b & 32) != 0 {
                    type = .drag
                } else if isRelease {
                    type = .release
                } else {
                    type = .press
                }

                switch b & 3 {
                case 0: button = .left
                case 1: button = .middle
                case 2: button = .right
                default: button = .none
                }

                // SGR coordinates are 1-based
                return .mouse(button, type, y - 1, x - 1)
            default:
                return .none
            }
        }
    }

    private func parseSS3() -> KeyEvent {
        guard let byte = terminal.readByteImmediate() else {
            return .escape
        }

        switch byte {
        case UInt8(ascii: "A"): return .arrow(.up)
        case UInt8(ascii: "B"): return .arrow(.down)
        case UInt8(ascii: "C"): return .arrow(.right)
        case UInt8(ascii: "D"): return .arrow(.left)
        case UInt8(ascii: "H"): return .home
        case UInt8(ascii: "F"): return .end
        case UInt8(ascii: "P"): return .functionKey(1)
        case UInt8(ascii: "Q"): return .functionKey(2)
        case UInt8(ascii: "R"): return .functionKey(3)
        case UInt8(ascii: "S"): return .functionKey(4)
        default: return .none
        }
    }
}
