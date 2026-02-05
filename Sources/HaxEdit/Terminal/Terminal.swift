#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Terminal Protocol

protocol TerminalProtocol {
    var size: TerminalSize { get }
    func readByte(timeout: Int) -> UInt8?
    func readByteImmediate() -> UInt8?
    func checkResize() -> Bool
    func writeBytes(_ bytes: [UInt8])
    func writeString(_ string: String)
    func flush()
    func suspend()
}

struct TerminalSize: Equatable {
    var cols: Int
    var rows: Int
}

// MARK: - Terminal Implementation

final class Terminal: TerminalProtocol {
    private var originalTermios: termios
    private var isRawMode = false
    private(set) var size: TerminalSize

    // Pipe-to-self for SIGWINCH
    static var signalPipeFds: (Int32, Int32) = (-1, -1)
    private static var instance: Terminal?

    // Output buffer for efficient writes
    private var outputBuffer: [UInt8] = []

    init() throws {
        var ws = winsize()
        self.originalTermios = termios()
        self.size = TerminalSize(cols: 80, rows: 24)

        // Get current terminal attributes
        guard tcgetattr(STDIN_FILENO, &originalTermios) == 0 else {
            throw HaxEditError.terminalError("Failed to get terminal attributes")
        }

        // Get terminal size
        if ioctl(STDOUT_FILENO, UInt(PLATFORM_TIOCGWINSZ), &ws) == 0 {
            size = TerminalSize(cols: Int(ws.ws_col), rows: Int(ws.ws_row))
        }

        // Setup signal pipe
        Terminal.instance = self
        setupSignalPipe()
    }

    deinit {
        if isRawMode {
            disableRawMode()
        }
        Terminal.instance = nil
    }

    // MARK: - Raw Mode

    func enableRawMode() {
        guard !isRawMode else { return }
        var raw = originalTermios

        // Input: no break, no CR to NL, no parity, no strip, no flow control
        raw.c_iflag &= ~tcflag_t(BRKINT | ICRNL | INPCK | ISTRIP | IXON)

        // Output: disable post processing
        raw.c_oflag &= ~tcflag_t(OPOST)

        // Control: 8-bit chars
        raw.c_cflag |= tcflag_t(CS8)

        // Local: no echo, no canonical, no extended, no signal chars
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | IEXTEN | ISIG)

        // Set VMIN and VTIME
        withUnsafeMutablePointer(to: &raw.c_cc) { ccPtr in
            ccPtr.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { cc in
                cc[Int(VMIN)] = 0
                cc[Int(VTIME)] = 1
            }
        }

        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        writeString(ANSIRenderer.enableMouseTracking)
        flush()
        isRawMode = true
    }

    func disableRawMode() {
        guard isRawMode else { return }
        writeString(ANSIRenderer.disableMouseTracking)
        flush()
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawMode = false
    }

    // MARK: - Signal Handling

    private func setupSignalPipe() {
        var fds: (Int32, Int32) = (0, 0)
        let result = withUnsafeMutablePointer(to: &fds) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 2) { intPtr in
                platformPipe(intPtr)
            }
        }
        guard result == 0 else { return }

        Terminal.signalPipeFds = fds

        // Set write end to non-blocking
        let flags = platformFcntl(Terminal.signalPipeFds.1, F_GETFL, 0)
        _ = platformFcntl(Terminal.signalPipeFds.1, F_SETFL, flags | O_NONBLOCK)

        // Install SIGWINCH handler
        platformInstallSigwinchHandler(Terminal.sigwinchHandler)
    }

    private static let sigwinchHandler: @convention(c) (Int32) -> Void = { _ in
        var byte: UInt8 = 1
        _ = platformWrite(Terminal.signalPipeFds.1, &byte, 1)
    }

    func refreshSize() {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(PLATFORM_TIOCGWINSZ), &ws) == 0 {
            size = TerminalSize(cols: Int(ws.ws_col), rows: Int(ws.ws_row))
        }
    }

    /// Check if a SIGWINCH has been received (non-blocking)
    func checkResize() -> Bool {
        guard Terminal.signalPipeFds.0 >= 0 else { return false }

        var pfd = pollfd(fd: Terminal.signalPipeFds.0, events: Int16(POLLIN), revents: 0)
        if platformPoll(&pfd, 1, 0) > 0 {
            var buf: UInt8 = 0
            _ = platformRead(Terminal.signalPipeFds.0, &buf, 1)
            refreshSize()
            return true
        }
        return false
    }

    // MARK: - I/O

    func readByte(timeout: Int = -1) -> UInt8? {
        // Check for resize signal first
        if checkResize() {
            return nil
        }

        var fds: [pollfd] = [
            pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        ]
        if Terminal.signalPipeFds.0 >= 0 {
            fds.append(pollfd(fd: Terminal.signalPipeFds.0, events: Int16(POLLIN), revents: 0))
        }

        let ret = fds.withUnsafeMutableBufferPointer { buf in
            platformPoll(buf.baseAddress!, buf.count, Int32(timeout))
        }

        if ret <= 0 { return nil }

        // Check signal pipe
        if fds.count > 1 && fds[1].revents & Int16(POLLIN) != 0 {
            var buf: UInt8 = 0
            _ = platformRead(Terminal.signalPipeFds.0, &buf, 1)
            refreshSize()
            return nil
        }

        // Check stdin
        if fds[0].revents & Int16(POLLIN) != 0 {
            var byte: UInt8 = 0
            let n = platformRead(STDIN_FILENO, &byte, 1)
            if n == 1 { return byte }
        }

        return nil
    }

    /// Read a byte from stdin with a very short timeout (for escape sequences)
    func readByteImmediate() -> UInt8? {
        return readByte(timeout: 50)
    }

    func writeBytes(_ bytes: [UInt8]) {
        outputBuffer.append(contentsOf: bytes)
    }

    func writeString(_ string: String) {
        outputBuffer.append(contentsOf: Array(string.utf8))
    }

    func flush() {
        guard !outputBuffer.isEmpty else { return }
        outputBuffer.withUnsafeBufferPointer { buf in
            if let base = buf.baseAddress {
                _ = platformWrite(STDOUT_FILENO, base, buf.count)
            }
        }
        outputBuffer.removeAll(keepingCapacity: true)
    }

    // MARK: - Suspend / Resume

    func suspend() {
        disableRawMode()
        writeString("\u{1b}[?25h\u{1b}[0m")
        flush()
        _ = platformKill(platformGetpid(), SIGTSTP)
        // After resume:
        enableRawMode()
        refreshSize()
    }
}
