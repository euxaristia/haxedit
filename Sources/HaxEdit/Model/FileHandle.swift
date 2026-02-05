#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - File Handle (POSIX fd wrapper)

final class HaxFileHandle {
    private(set) var fd: Int32 = -1
    private(set) var fileName: String
    private(set) var baseName: String
    private(set) var isReadOnly: Bool
    private(set) var fileSize: Int64 = 0
    var biggestLoc: Int64 = 0

    init(fileName: String, forceReadOnly: Bool = false) throws {
        self.fileName = fileName
        self.baseName = platformBasename(fileName)
        self.isReadOnly = forceReadOnly

        // Validate it's a file (not directory)
        var st = stat()
        guard platformStatFile(fileName, &st) == 0 else {
            throw HaxEditError.fileNotFound(fileName)
        }
        let mode = st.st_mode
        if (mode & S_IFMT) == S_IFDIR {
            throw HaxEditError.notAFile(fileName)
        }

        // Try opening read-write, fall back to read-only
        if !forceReadOnly {
            fd = platformOpen(fileName, platformO_RDWR)
            if fd == -1 {
                isReadOnly = true
            }
        }

        if fd == -1 {
            fd = platformOpen(fileName, platformO_RDONLY)
            isReadOnly = true
        }

        guard fd != -1 else {
            throw HaxEditError.openFailed(fileName, platformStrerror(platformErrno()))
        }

        // Determine file size
        var fst = stat()
        if platformFstat(fd, &fst) == 0 && fst.st_size > 0 {
            fileSize = Int64(fst.st_size)
        } else {
            // Try block device size
            #if os(Linux)
            var deviceSize: UInt64 = 0
            if platformIoctl(fd, PLATFORM_BLKGETSIZE64, &deviceSize) == 0 {
                fileSize = Int64(deviceSize)
            }
            #endif
        }

        biggestLoc = fileSize
    }

    deinit {
        if fd >= 0 {
            _ = platformClose(fd)
        }
    }

    // MARK: - Seeking

    func seek(to offset: Int64) throws {
        let result = platformLseek(fd, off_t(offset), SEEK_SET)
        if result != off_t(offset) {
            throw HaxEditError.seekFailed(Int64(result), offset)
        }
    }

    func seekSafe(to offset: Int64) -> Bool {
        return platformLseek(fd, off_t(offset), SEEK_SET) == off_t(offset)
    }

    // MARK: - Reading

    func read(into buffer: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let n = platformRead(fd, buffer, count)
        return n < 0 ? 0 : n
    }

    func readPage(at base: Int64, size: Int) -> (data: [UInt8], bytesRead: Int) {
        var buffer = [UInt8](repeating: 0, count: size)
        do {
            try seek(to: base)
        } catch {
            return (buffer, 0)
        }
        let n = buffer.withUnsafeMutableBufferPointer { ptr in
            platformRead(fd, ptr.baseAddress!, size)
        }
        let bytesRead = n < 0 ? 0 : n
        if bytesRead > 0 && base + Int64(bytesRead) > biggestLoc {
            biggestLoc = base + Int64(bytesRead)
        }
        return (buffer, bytesRead)
    }

    // MARK: - Writing

    func write(data: UnsafePointer<UInt8>, count: Int, at offset: Int64) throws {
        guard !isReadOnly else {
            throw HaxEditError.readOnly
        }
        guard seekSafe(to: offset) else {
            throw HaxEditError.seekFailed(-1, offset)
        }
        let written = platformWrite(fd, data, count)
        if written != count {
            throw HaxEditError.writeFailed(platformStrerror(platformErrno()))
        }
    }

    func truncate(at offset: Int64) throws {
        guard !isReadOnly else {
            throw HaxEditError.readOnly
        }
        guard platformFtruncate(fd, off_t(offset)) == 0 else {
            throw HaxEditError.writeFailed(platformStrerror(platformErrno()))
        }
        if biggestLoc > offset {
            biggestLoc = offset
        }
        if fileSize > offset {
            fileSize = offset
        }
    }

    // MARK: - Position Validation

    /// Check if a location is valid for cursor placement (allows one past EOF for appending)
    func tryloc(_ loc: Int64, lastEditedLoc: Int64) -> Bool {
        if loc < 0 { return false }
        if loc <= lastEditedLoc { return true }
        if loc <= biggestLoc { return true }

        // Try to read at loc-1
        if loc > 0 && seekSafe(to: loc - 1) {
            var c: UInt8 = 0
            if platformRead(fd, &c, 1) == 1 {
                biggestLoc = loc
                return true
            }
        }
        return false
    }

    func getfilesize(lastEditedLoc: Int64) -> Int64 {
        return max(lastEditedLoc, biggestLoc)
    }

    // MARK: - Reopen

    func reopen(fileName: String, forceReadOnly: Bool = false) throws {
        if fd >= 0 {
            _ = platformClose(fd)
            fd = -1
        }
        self.fileName = fileName
        self.baseName = platformBasename(fileName)
        self.isReadOnly = forceReadOnly

        var st = stat()
        guard platformStatFile(fileName, &st) == 0 else {
            throw HaxEditError.fileNotFound(fileName)
        }
        if (st.st_mode & S_IFMT) == S_IFDIR {
            throw HaxEditError.notAFile(fileName)
        }

        if !forceReadOnly {
            fd = platformOpen(fileName, platformO_RDWR)
            if fd == -1 { isReadOnly = true }
        }
        if fd == -1 {
            fd = platformOpen(fileName, platformO_RDONLY)
            isReadOnly = true
        }
        guard fd != -1 else {
            throw HaxEditError.openFailed(fileName, platformStrerror(platformErrno()))
        }

        var fst = stat()
        if platformFstat(fd, &fst) == 0 && fst.st_size > 0 {
            fileSize = Int64(fst.st_size)
        } else {
            fileSize = 0
        }
        biggestLoc = fileSize
    }
}

// MARK: - File Utility

func isFile(_ name: String) -> Bool {
    var st = stat()
    return platformStatFile(name, &st) == 0 && (st.st_mode & S_IFMT) != S_IFDIR
}
