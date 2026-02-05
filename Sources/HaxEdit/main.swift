#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

// MARK: - Main Entry Point

var state = EditorState()
var terminal: Terminal!
var inputParser: InputParser!

func cleanup() {
    terminal?.disableRawMode()
    terminal?.writeString(ANSIRenderer.resetAttributes)
    terminal?.writeString(ANSIRenderer.showCursor)
    terminal?.writeString(ANSIRenderer.clearScreen)
    terminal?.writeString(ANSIRenderer.moveTo(row: 0, col: 0))
    terminal?.flush()
}

func die(_ message: String) -> Never {
    cleanup()
    fputs(message + "\n", stderr)
    exit(1)
}

// MARK: - Argument Parsing

var args = CommandLine.arguments
let progName = platformBasename(args[0])
args.removeFirst()

var fileName: String? = nil
var forceReadOnly = false
var requestedLineLength: Int = 0

var i = 0
while i < args.count {
    let arg = args[i]

    if arg == "-s" || arg == "--sector" {
        state.mode = .bySector
    } else if arg == "-r" || arg == "--readonly" {
        forceReadOnly = true
    } else if arg == "-m" || arg == "--maximize" {
        state.mode = .maximized
        requestedLineLength = 0
    } else if arg == "--color" {
        state.colored = true
    } else if arg.hasPrefix("-l") {
        if arg.count > 2 {
            let numStr = String(arg.dropFirst(2))
            guard let ll = Int(numStr), ll >= 0 && ll <= 4096 else {
                die("\(progName): illegal line length")
            }
            requestedLineLength = ll
        } else {
            i += 1
            guard i < args.count, let ll = Int(args[i]), ll >= 0 && ll <= 4096 else {
                die("\(progName): illegal line length")
            }
            requestedLineLength = ll
        }
    } else if arg == "--linelength" {
        i += 1
        guard i < args.count, let ll = Int(args[i]), ll >= 0 && ll <= 4096 else {
            die("\(progName): illegal line length")
        }
        requestedLineLength = ll
    } else if arg == "-h" || arg == "--help" {
        print(usageMessage)
        exit(0)
    } else if arg == "--" {
        i += 1
        if i < args.count {
            fileName = args[i]
        }
        break
    } else if arg.hasPrefix("-") {
        die(usageMessage)
    } else {
        fileName = arg
        break
    }
    i += 1
}

// Check for extra arguments
if fileName != nil && i + 1 < args.count {
    die(usageMessage)
}

state.lineLength = requestedLineLength

// MARK: - Initialize Terminal

signal(SIGINT) { _ in
    cleanup()
    exit(0)
}

do {
    terminal = try Terminal()
} catch {
    fputs("Failed to initialize terminal: \(error)\n", stderr)
    exit(1)
}

inputParser = InputParser(terminal: terminal)

// MARK: - Open File

if let name = fileName {
    do {
        try state.openFile(name, forceReadOnly: forceReadOnly)
    } catch {
        die("\(progName): \(error)")
    }
}

// MARK: - Enter Raw Mode and Initialize Display

terminal.enableRawMode()

do {
    try state.initDisplay(termSize: terminal.size)
} catch {
    die("\(progName): \(error)")
}

// If no file specified, prompt for one
if fileName == nil {
    // Render empty screen first
    terminal.writeString(ANSIRenderer.clearScreen)
    terminal.flush()

    guard let name = Prompt.displayMessageAndGetString(
        "File name: ",
        lastValue: nil,
        state: state,
        terminal: terminal,
        inputParser: inputParser,
        termSize: terminal.size
    ), isFile(name) else {
        cleanup()
        die("\(progName): No such file")
    }

    do {
        try state.openFile(name, forceReadOnly: forceReadOnly)
    } catch {
        cleanup()
        die("\(progName): \(error)")
    }
}

// Initial read
state.readFile()

// MARK: - Main Loop

var running = true

while running {
    // Render
    let output = Display.render(state: state, termSize: terminal.size)
    terminal.writeString(output)
    terminal.flush()

    // Read key
    let key = inputParser.readKey()
    state.saveOldState()

    // Handle resize
    if key == .resize || terminal.checkResize() {
        terminal.refreshSize()
        state.lineLength = 0  // force recalculation
        do {
            try state.initDisplay(termSize: terminal.size)
        } catch {
            // Terminal too small — wait for another resize
            terminal.writeString(ANSIRenderer.clearScreen)
            terminal.writeString(ANSIRenderer.moveTo(row: 0, col: 0))
            terminal.writeString("Terminal too small. Please resize.")
            terminal.flush()
            continue
        }
        state.readFile()
        continue
    }

    if key == .none { continue }

    // Dispatch key to action
    if let action = KeyDispatcher.dispatch(key, mode: state.mode, pane: state.editPane) {
        running = Commands.execute(
            action,
            state: &state,
            terminal: terminal,
            inputParser: inputParser,
            termSize: terminal.size
        )
    }
}

// MARK: - Cleanup

cleanup()
exit(0)