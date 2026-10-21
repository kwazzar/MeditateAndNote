//
//  MiniZipReader.swift
//  MeditateAndNoteCoreJNI
//
//  Read-only zip reader for EPUB containers on Android.
//
//  ZIPFoundation needs a CZlib pkg-config setup the NDK does not ship, and the
//  Compression framework does not exist on Android, so this is the small slice
//  of the zip format the reader actually needs: parse the central directory,
//  read one entry, inflate raw deflate with zlib. No ZIP64, no encryption, no
//  writing — an EPUB with those would be rejected as unreadable, which the
//  parser surfaces as a normal parse failure.
//

import CZlib
import Foundation

struct MiniZipEntry {
    let path: String
    let compressionMethod: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

struct MiniZipReader {
    let data: [UInt8]
    let entries: [MiniZipEntry]

    enum ZipError: Error {
        case tooSmall
        case noEndRecord
        case entryNotFound
        case unsupportedEntry
        case inflateFailed
    }

    init(url: URL) throws {
        guard let data = try? Data(contentsOf: url) else {
            throw ZipError.tooSmall
        }
        self.data = [UInt8](data)
        self.entries = try Self.readCentralDirectory(self.data)
    }

    func entry(named path: String) -> MiniZipEntry? {
        entries.first { $0.path == path }
    }

    /// Decompresses one entry. Returns nil when the entry is missing or malformed.
    func read(_ entry: MiniZipEntry) -> Data? {
        // Local header: 30 fixed bytes + name length + extra length.
        let header = 30
        guard entry.localHeaderOffset + header + 4 <= data.count else { return nil }
        let nameLen = Self.u16(data, entry.localHeaderOffset + 26)
        let extraLen = Self.u16(data, entry.localHeaderOffset + 28)
        let dataStart = entry.localHeaderOffset + header + Int(nameLen) + Int(extraLen)
        let dataEnd = dataStart + entry.compressedSize
        guard dataEnd <= data.count else { return nil }

        switch entry.compressionMethod {
        case 0: // stored
            return Data(data[dataStart..<dataEnd])
        case 8: // deflate
            return Self.inflate(data[dataStart..<dataEnd], expectedSize: entry.uncompressedSize)
        default:
            return nil
        }
    }

    // MARK: - Central directory

    private static func readCentralDirectory(_ data: [UInt8]) throws -> [MiniZipEntry] {
        guard data.count > 22 else { throw ZipError.tooSmall }

        // EOCD: scan backwards; the comment is at most 65535 bytes.
        var eocd = -1
        let searchStart = max(0, data.count - 22 - 65_536)
        var i = data.count - 22
        while i >= searchStart {
            if u32(data, i) == 0x0605_4b50 {
                eocd = i
                break
            }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.noEndRecord }

        let count = Int(u16(data, eocd + 10))
        var offset = Int(u32(data, eocd + 16))

        var entries: [MiniZipEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            guard offset + 46 <= data.count, u32(data, offset) == 0x0201_4b50 else {
                break
            }
            let method = u16(data, offset + 10)
            let compressedSize = Int(u32(data, offset + 20))
            let uncompressedSize = Int(u32(data, offset + 24))
            let nameLen = Int(u16(data, offset + 28))
            let extraLen = Int(u16(data, offset + 30))
            let commentLen = Int(u16(data, offset + 32))
            let localOffset = Int(u32(data, offset + 42))
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else { break }
            let path = String(decoding: data[nameStart..<nameEnd], as: UTF8.self)
            entries.append(
                MiniZipEntry(
                    path: path,
                    compressionMethod: method,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localOffset
                )
            )
            offset = nameEnd + extraLen + commentLen
        }
        return entries
    }

    // MARK: - Inflate

    private static func inflate(_ compressed: ArraySlice<UInt8>, expectedSize: Int) -> Data? {
        var source = Array(compressed)
        var output = Data(count: max(expectedSize, 0))
        let sourceCount = source.count
        let outputCount = output.count

        let written = source.withUnsafeMutableBytes { sourceBuffer -> Int32 in
            var stream = z_stream()
            guard CZlib.inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return -1
            }
            defer { CZlib.inflateEnd(&stream) }
            let result = output.withUnsafeMutableBytes { outputBuffer -> Int32 in
                stream.next_in = sourceBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                stream.avail_in = uInt(sourceCount)
                stream.next_out = outputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                stream.avail_out = uInt(outputCount)
                return CZlib.inflate(&stream, Z_FINISH)
            }
            guard result == Z_STREAM_END else { return -1 }
            return Int32(stream.total_out)
        }

        guard written > 0 else { return nil }
        output.removeSubrange(Int(written)..<output.count)
        return output
    }

    // MARK: - Fixed-width reads (little-endian)

    private static func u16(_ data: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func u32(_ data: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
