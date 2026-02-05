#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Platform-specific constants and wrappers

#if os(Linux)
let platformO_RDWR: Int32 = Glibc.O_RDWR
let platformO_RDONLY: Int32 = Glibc.O_RDONLY
let platformO_WRONLY: Int32 = Glibc.O_WRONLY
let platformO_CREAT: Int32 = Glibc.O_CREAT
let platformO_TRUNC: Int32 = Glibc.O_TRUNC
#else
let platformO_RDWR: Int32 = Darwin.O_RDWR
let platformO_RDONLY: Int32 = Darwin.O_RDONLY
let platformO_WRONLY: Int32 = Darwin.O_WRONLY
let platformO_CREAT: Int32 = Darwin.O_CREAT
let platformO_TRUNC: Int32 = Darwin.O_TRUNC
#endif

func platformRead(_ fd: Int32, _ buf: UnsafeMutableRawPointer, _ count: Int) -> Int {
    #if os(Linux)
    return Glibc.read(fd, buf, count)
    #else
    return Darwin.read(fd, buf, count)
    #endif
}

func platformWrite(_ fd: Int32, _ buf: UnsafeRawPointer, _ count: Int) -> Int {
    #if os(Linux)
    return Glibc.write(fd, buf, count)
    #else
    return Darwin.write(fd, buf, count)
    #endif
}

func platformClose(_ fd: Int32) -> Int32 {
    #if os(Linux)
    return Glibc.close(fd)
    #else
    return Darwin.close(fd)
    #endif
}

func platformOpen(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t = 0o666) -> Int32 {
    #if os(Linux)
    return Glibc.open(path, flags, mode)
    #else
    return Darwin.open(path, flags, mode)
    #endif
}

func platformLseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t {
    #if os(Linux)
    return Glibc.lseek(fd, offset, whence)
    #else
    return Darwin.lseek(fd, offset, whence)
    #endif
}

func platformFstat(_ fd: Int32, _ buf: UnsafeMutablePointer<stat>) -> Int32 {
    #if os(Linux)
    return Glibc.fstat(fd, buf)
    #else
    return Darwin.fstat(fd, buf)
    #endif
}

func platformStatFile(_ path: String, _ buf: UnsafeMutablePointer<stat>) -> Int32 {
    return path.withCString { cstr in
        return lstat(cstr, buf)
    }
}

func platformFtruncate(_ fd: Int32, _ length: off_t) -> Int32 {
    #if os(Linux)
    return Glibc.ftruncate(fd, length)
    #else
    return Darwin.ftruncate(fd, length)
    #endif
}

func platformIoctl(_ fd: Int32, _ request: UInt, _ arg: UnsafeMutableRawPointer) -> Int32 {
    #if os(Linux)
    return Glibc.ioctl(fd, UInt(request), arg)
    #else
    return Darwin.ioctl(fd, UInt(request), arg)
    #endif
}

func platformKill(_ pid: pid_t, _ sig: Int32) -> Int32 {
    #if os(Linux)
    return Glibc.kill(pid, sig)
    #else
    return Darwin.kill(pid, sig)
    #endif
}

func platformGetpid() -> pid_t {
    #if os(Linux)
    return Glibc.getpid()
    #else
    return Darwin.getpid()
    #endif
}

func platformStrerror(_ errnum: Int32) -> String {
    if let cstr = strerror(errnum) {
        return String(cString: cstr)
    }
    return "Unknown error \(errnum)"
}

func platformErrno() -> Int32 {
    return errno
}

// Terminal size ioctl
#if os(Linux)
let PLATFORM_TIOCGWINSZ: UInt = 0x5413
#else
let PLATFORM_TIOCGWINSZ: UInt = UInt(TIOCGWINSZ)
#endif

// Block device size
#if os(Linux)
// BLKGETSIZE64 = _IOR(0x12, 114, sizeof(uint64_t))
let PLATFORM_BLKGETSIZE64: UInt = 0x80081272
#endif

func platformBasename(_ path: String) -> String {
    // Pure Swift implementation — no Foundation needed
    guard let lastSlash = path.lastIndex(of: "/") else {
        return path
    }
    let afterSlash = path.index(after: lastSlash)
    if afterSlash == path.endIndex {
        return String(path.dropLast())
    }
    return String(path[afterSlash...])
}

// Pipe wrapper
func platformPipe(_ fds: UnsafeMutablePointer<Int32>) -> Int32 {
    #if os(Linux)
    return Glibc.pipe(fds)
    #else
    return Darwin.pipe(fds)
    #endif
}

func platformFcntl(_ fd: Int32, _ cmd: Int32, _ arg: Int32) -> Int32 {
    #if os(Linux)
    return Glibc.fcntl(fd, cmd, arg)
    #else
    return Darwin.fcntl(fd, cmd, arg)
    #endif
}

// MARK: - Signal handling

func platformInstallSigwinchHandler(_ handler: @convention(c) (Int32) -> Void) {
    signal(SIGWINCH, handler)
}

func platformPoll(_ fds: UnsafeMutablePointer<pollfd>, _ nfds: Int, _ timeout: Int32) -> Int32 {
    #if os(Linux)
    return Glibc.poll(fds, UInt(nfds), timeout)
    #else
    return Darwin.poll(fds, UInt32(nfds), timeout)
    #endif
}

// MARK: - String Utilities (no Foundation)

func trimWhitespace(_ s: String) -> String {
    var chars = Array(s)
    while let first = chars.first, first == " " || first == "\t" || first == "\n" || first == "\r" {
        chars.removeFirst()
    }
    while let last = chars.last, last == " " || last == "\t" || last == "\n" || last == "\r" {
        chars.removeLast()
    }
    return String(chars)
}

func formatHex08(_ value: Int64) -> String {
    let hex = String(UInt64(bitPattern: value), radix: 16, uppercase: true)
    let padding = max(0, 8 - hex.count)
    return String(repeating: "0", count: padding) + hex
}
