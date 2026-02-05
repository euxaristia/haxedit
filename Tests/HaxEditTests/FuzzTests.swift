import XCTest
@testable import HaxEdit

final class FuzzTests: XCTestCase {

    func testFuzzRandomInputs() {
        let fuzzIterations = 1000
        
        // Setup
        let mockTerminal = MockTerminal()
        let parser = InputParser(terminal: mockTerminal)
        
        var state = EditorState()
        state.mode = .maximized
        state.lineLength = 16
        state.blocSize = 4
        state.page = 256
        state.viewport = Viewport(pageSize: 256)
        
        // Create a dummy file
        let path = "/tmp/haxedit_fuzz.bin"
        var data = [UInt8](repeating: 0, count: 1024)
        // Fill with random data
        for i in 0..<data.count { data[i] = UInt8.random(in: 0...255) }
        
        data.withUnsafeBufferPointer { buf in
            let fd = platformOpen(path, platformO_WRONLY | platformO_CREAT | platformO_TRUNC, 0o666)
            _ = platformWrite(fd, buf.baseAddress!, data.count)
            _ = platformClose(fd)
        }
        
        do {
            try state.openFile(path)
            state.readFile()
        } catch {
            XCTFail("Failed to open fuzz file: \(error)")
            return
        }
        
        // Run fuzz loop
        for i in 0..<fuzzIterations {
            let key = generateRandomKey()
            
            // Dispatch
            if let action = KeyDispatcher.dispatch(key, mode: state.mode, pane: state.editPane) {
                // Execute
                // We mock the interactive prompts by ensuring the input buffer has something
                // if the command asks for input.
                // Or we can just let it fail or hang? 
                // Commands.execute calls Prompt.display... which reads keys.
                // We need to be careful not to hang on prompts.
                
                // Strategy: Only fuzz safe commands that don't block on input, 
                // OR pre-fill input buffer with "safe" exits (like ESC or Enter).
                
                mockTerminal.queueInput([0x1B, 0x0D, 0x1B, 0x0D]) // Queue multiple ESC and Enter just in case
                
                _ = Commands.execute(
                    action,
                    state: &state,
                    terminal: mockTerminal,
                    inputParser: parser,
                    termSize: mockTerminal.size
                )
            }
            
            // Sanity checks after every command
            XCTAssert(state.cursor >= 0, "Cursor negative at iter \(i)")
            XCTAssert(state.base >= 0, "Base negative at iter \(i)")
            // viewport check?
        }
        
        // Cleanup
        unlink(path)
    }
    
    func generateRandomKey() -> KeyEvent {
        let type = Int.random(in: 0...10)
        switch type {
        case 0: return .char(UInt8.random(in: 32...126))
        case 1: return .ctrl(UInt8.random(in: 1...31))
        case 2: return .arrow(randomArrow())
        case 3: return .functionKey(Int.random(in: 1...12))
        case 4: return .mouse(.left, .press, Int.random(in: 0...24), Int.random(in: 0...80))
        case 5: return .mouse(.left, .drag, Int.random(in: 0...24), Int.random(in: 0...80))
        case 6: return .mouse(.left, .release, Int.random(in: 0...24), Int.random(in: 0...80))
        case 7: return .enter
        case 8: return .backspace
        case 9: return .delete
        default: return .none
        }
    }
    
    func randomArrow() -> ArrowDirection {
        let r = Int.random(in: 0...3)
        switch r {
        case 0: return .up
        case 1: return .down
        case 2: return .left
        default: return .right
        }
    }
}
