// MARK: - Key Dispatcher
// Maps KeyEvent → EditorAction. Port of key_to_function() from interact.c.

struct KeyDispatcher {

     /// Map a KeyEvent to an EditorAction.
     /// Returns nil for unrecognized keys.
     static func dispatch(_ key: KeyEvent, mode: DisplayMode, pane: EditPane) -> EditorAction? {
          switch key {
          // Arrow keys
          case .arrow(.right): return .forwardChar
          case .arrow(.left): return .backwardChar
          case .arrow(.down): return .nextLine
          case .arrow(.up): return .previousLine

          // Alt+arrow keys
          case .altArrow(.right): return .forwardChars
          case .altArrow(.left): return .backwardChars
          case .altArrow(.down): return .nextLines
          case .altArrow(.up): return .previousLines

          // Ctrl+letter movement
          case .ctrl(0x06): /* Ctrl+F */ return .forwardChar
          case .ctrl(0x02): /* Ctrl+B */ return .backwardChar
          case .ctrl(0x0E): /* Ctrl+N */ return .nextLine
          case .ctrl(0x10): /* Ctrl+P */ return .previousLine
          case .ctrl(0x01): /* Ctrl+A */ return .beginningOfLine
          case .ctrl(0x05): /* Ctrl+E */ return .endOfLine
          case .ctrl(0x16): /* Ctrl+V */ return .scrollUp

          // Alt+letter
          case .alt(UInt8(ascii: "f")),
               .alt(UInt8(ascii: "F")):
               return .forwardChars
          case .alt(UInt8(ascii: "b")),
               .alt(UInt8(ascii: "B")):
               return .backwardChars
          case .alt(UInt8(ascii: "n")),
               .alt(UInt8(ascii: "N")):
               return .nextLines
          case .alt(UInt8(ascii: "p")),
               .alt(UInt8(ascii: "P")):
               return .previousLines
          case .alt(UInt8(ascii: "v")),
               .alt(UInt8(ascii: "V")):
               return .scrollDown
          case .alt(UInt8(ascii: "<")): return .beginningOfBuffer
          case .alt(UInt8(ascii: ">")): return .endOfBuffer
          case .alt(UInt8(ascii: "l")),
               .alt(UInt8(ascii: "L")):
               return .recenter
          case .alt(UInt8(ascii: "h")),
               .alt(UInt8(ascii: "H")):
               return .help
          case .alt(UInt8(ascii: "w")),
               .alt(UInt8(ascii: "W")):
               return .copyRegion
          case .alt(UInt8(ascii: "q")),
               .alt(UInt8(ascii: "Q")):
               return .quotedInsert
          case .alt(UInt8(ascii: "y")),
               .alt(UInt8(ascii: "Y")):
               return .yankToFile
          case .alt(UInt8(ascii: "i")),
               .alt(UInt8(ascii: "I")):
               return .fillWithString
          case .alt(UInt8(ascii: "t")),
               .alt(UInt8(ascii: "T")):
               return .truncateFile

          // Home/End/Page
          case .home: return .beginningOfLine
          case .end: return .endOfLine
          case .pageDown: return .scrollUp
          case .pageUp: return .scrollDown

          // Special chars
          case .char(UInt8(ascii: "<")): return .beginningOfBuffer
          case .char(UInt8(ascii: ">")): return .endOfBuffer
          case .char(UInt8(ascii: "/")): return .searchForward

          // Function keys
          case .functionKey(1): return .help
          case .functionKey(2): return .save
          case .functionKey(3): return .findFile
          case .functionKey(4): return .gotoChar
          case .functionKey(5): return .scrollDown
          case .functionKey(6): return .scrollUp
          case .functionKey(7): return .copyRegion
          case .functionKey(8): return .yank
          case .functionKey(9): return .setMark
          case .functionKey(10): return .askSaveAndQuit
          case .functionKey(11): return .yankToFile
          case .functionKey(12): return .fillWithString

          // Ctrl combos
          case .ctrl(0x00): /* Ctrl+Space */ return .setMark
          case .ctrl(0x03): /* Ctrl+C */ return .quit
          case .ctrl(0x04): /* Ctrl+D */ return .copyRegion
          case .ctrl(0x07): /* Ctrl+G */ return .gotoChar
          case .ctrl(0x0C): /* Ctrl+L */ return .redisplay
          case .ctrl(0x0F): /* Ctrl+O */ return .findFile
          case .ctrl(0x11): /* Ctrl+Q */ return .quotedInsert
          case .ctrl(0x12): /* Ctrl+R */ return .searchBackward
          case .ctrl(0x13): /* Ctrl+S */ return .searchForward
          case .ctrl(0x14): /* Ctrl+T */ return .toggleHexAscii
          case .ctrl(0x15): /* Ctrl+U */ return .undo
          case .ctrl(0x17): /* Ctrl+W */ return .save
          case .ctrl(0x18): /* Ctrl+X */ return .askSaveAndQuit
          case .ctrl(0x19): /* Ctrl+Y */ return .yank
          case .ctrl(0x1A): /* Ctrl+Z */ return .suspend
          case .ctrl(0x1F): /* Ctrl+_ */ return .undo

          // Ctrl+Shift combos
          case .ctrlShift(UInt8(ascii: "C")),
               .ctrlShift(UInt8(ascii: "c")):
               return .copyToSystemClipboard

          // Tab
          case .tab: return .toggleHexAscii

          // Enter
          case .enter:
               return mode == .bySector ? .gotoSector : .gotoChar

          // Backspace
          case .backspace: return .deleteBackwardChar

          // Insert/Delete keys
          case .insert: return .yank
          case .delete: return .copyRegion

          // Escape alone (not followed by sequence)
          case .escape: return nil

          // Printable characters
          case .char(let c):
               if pane.isHex {
                    switch c {
                    case UInt8(ascii: "h"): return .backwardChar
                    case UInt8(ascii: "j"): return .nextLine
                    case UInt8(ascii: "k"): return .previousLine
                    case UInt8(ascii: "l"): return .forwardChar
                    case UInt8(ascii: "v"): return .setMark
                    case UInt8(ascii: "y"): return .copyRegion
                    case UInt8(ascii: "p"): return .yank
                    case UInt8(ascii: "w"): return .forwardChars
                    case UInt8(ascii: "b"): return .backwardChars
                    case UInt8(ascii: "G"): return .endOfBuffer
                    default: break
                    }
               }
               if c == UInt8(ascii: "v") {
                    return .setMark
               }
               return .insertChar(c)

          // Mouse events
          case .mouse(let button, let type, let row, let col):
               if button == .left || (button == .none && type == .drag) {
                    return .mouseEvent(row: row, col: col, type: type)
               }
               return nil

          // Ctrl+Alt+H → delete backward chars
          case .ctrlAlt(0x08): return .deleteBackwardChars

          default:
               return nil
          }
     }
}
