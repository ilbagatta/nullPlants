//
//  SimpleZip.swift
//  bagaFit
//
//  Created by ilbagatta on 22/09/25.
//


import Foundation

/// ZIP minimale (metodo Store, no compressione) – sufficiente per il nostro backup.
enum SimpleZip {
    struct Entry {
        let fileURL: URL
        let path: String
        let fileSize: UInt32
        let crc32: UInt32
    }

    static func crc32(of url: URL) throws -> (UInt32, UInt32) {
        let data = try Data(contentsOf: url)
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            for byte in buf {
                var c = crc ^ UInt32(byte)
                for _ in 0..<8 {
                    let mask: UInt32 = (c & 1) == 0 ? 0 : 0xFFFF_FFFF
                    c = (c >> 1) ^ (0xEDB88320 & mask)
                }
                crc = c
            }
        }
        return (~crc, UInt32(data.count))
    }

    static func zip(folder folderURL: URL, to zipURL: URL) throws {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])!
        var entries: [Entry] = []
        for case let file as URL in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            // Build a safe relative path from folderURL to file using path components
            let baseComps = folderURL.standardizedFileURL.pathComponents
            let fileComps = file.standardizedFileURL.pathComponents
            var i = 0
            while i < min(baseComps.count, fileComps.count) && baseComps[i] == fileComps[i] { i += 1 }
            let remaining = fileComps.dropFirst(i)
            let relPath = remaining.joined(separator: "/")
            let (crc, size) = try crc32(of: file)
            entries.append(Entry(fileURL: file, path: relPath.replacingOccurrences(of: "\\", with: "/"), fileSize: size, crc32: crc))
        }
        try writeZip(entries: entries, base: folderURL, to: zipURL)
    }

    /// Unzip a .zip created with `SimpleZip.zip` (method: store, no compression)
    /// - Parameters:
    ///   - zipURL: source .zip file URL
    ///   - destURL: destination folder (must exist)
    static func unzip(file zipURL: URL, to destURL: URL) throws {
        let data = try Data(contentsOf: zipURL)
        var offset = 0
        func readU16() -> UInt16 {
            let v = data.subdata(in: offset..<(offset+2)).withUnsafeBytes { $0.load(as: UInt16.self) }
            offset += 2
            return UInt16(littleEndian: v)
        }
        func readU32() -> UInt32 {
            let v = data.subdata(in: offset..<(offset+4)).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += 4
            return UInt32(littleEndian: v)
        }
        func readBytes(_ count: Int) -> Data {
            let d = data.subdata(in: offset..<(offset+count))
            offset += count
            return d
        }

        let fm = FileManager.default
        try fm.createDirectory(at: destURL, withIntermediateDirectories: true)

        // Iterate local file headers until we hit central directory or end
        while offset + 4 <= data.count {
            let sig = readU32()
            if sig == 0x04034b50 { // local file header
                _ = readU16() // version needed
                _ = readU16() // flags
                let method = readU16()
                _ = readU16() // time
                _ = readU16() // date
                _ = readU32() // crc32
                let compSize = Int(readU32())
                _ = readU32() // uncompressed size (same as compSize for store)
                let nameLen = Int(readU16())
                let extraLen = Int(readU16())

                let nameData = readBytes(nameLen)
                _ = readBytes(extraLen)
                let fileName = String(data: nameData, encoding: .utf8) ?? "file"

                // Only method 0 (store) is supported
                guard method == 0 else {
                    throw NSError(domain: "SimpleZip", code: -2, userInfo: [NSLocalizedDescriptionKey:"Unsupported compression method: \(method)"])
                }

                let fileData = readBytes(compSize)
                // Normalize path and create directories
                let safePath = fileName.replacingOccurrences(of: "\\", with: "/")
                    .split(separator: "/").filter { $0 != ".." && !$0.isEmpty }
                var outURL = destURL
                for (i, comp) in safePath.enumerated() {
                    if i == safePath.count - 1 {
                        outURL.appendPathComponent(String(comp), isDirectory: false)
                    } else {
                        outURL.appendPathComponent(String(comp), isDirectory: true)
                    }
                }
                let dirURL = outURL.deletingLastPathComponent()
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
                fm.createFile(atPath: outURL.path, contents: fileData)
            } else if sig == 0x02014b50 || sig == 0x06054b50 {
                // central directory or end — stop parsing
                break
            } else {
                // Unknown signature — stop to avoid infinite loop
                break
            }
        }
    }

    private static func writeZip(entries: [Entry], base: URL, to zipURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: zipURL.path) { try fm.removeItem(at: zipURL) }
        fm.createFile(atPath: zipURL.path, contents: nil)
        let out = try FileHandle(forWritingTo: zipURL)
        defer { try? out.close() }

        var centralDirectory: [Data] = []
        var offset: UInt32 = 0

        for e in entries {
            // Local header
            let nameData = Data(e.path.utf8)
            var local = Data()
            local.append(u32(0x04034b50))                 // signature
            local.append(u16(20))                          // version needed
            local.append(u16(0))                           // flags
            local.append(u16(0))                           // method: store
            local.append(dosDateTime(Date()))              // time+date
            local.append(u32(e.crc32))
            local.append(u32(e.fileSize))
            local.append(u32(e.fileSize))
            local.append(u16(UInt16(nameData.count)))
            local.append(u16(0))                           // extra len
            local.append(nameData)
            try out.write(contentsOf: local)

            // File data
            let fileData = try Data(contentsOf: e.fileURL)
            try out.write(contentsOf: fileData)

            // Central dir header
            var cd = Data()
            cd.append(u32(0x02014b50))
            cd.append(u16(20))                      // version made by
            cd.append(u16(20))                      // version needed to extract
            cd.append(u16(0))                       // flags
            cd.append(u16(0))                       // method store
            cd.append(dosDateTime(Date()))
            cd.append(u32(e.crc32))
            cd.append(u32(e.fileSize))
            cd.append(u32(e.fileSize))
            cd.append(u16(UInt16(nameData.count)))
            cd.append(u16(0))                       // extra len
            cd.append(u16(0))                       // comment len
            cd.append(u16(0))                       // disk number start
            cd.append(u16(0))                       // internal attrs
            cd.append(u32(0))                       // external attrs
            cd.append(u32(offset))                  // relative offset of local header
            cd.append(nameData)
            centralDirectory.append(cd)

            offset = offset &+ UInt32(local.count) &+ e.fileSize
        }

        // Central directory
        let startOfCD = offset
        for cd in centralDirectory { try out.write(contentsOf: cd) }
        let sizeOfCD: UInt32 = centralDirectory.reduce(UInt32(0)) { partial, data in
            partial &+ UInt32(data.count)
        }

        // End of central directory
        var end = Data()
        let sig: UInt32 = 0x06054b50
        let disk: UInt16 = 0
        let diskStart: UInt16 = 0
        let entriesCount: UInt16 = UInt16(entries.count)
        let sizeCD: UInt32 = sizeOfCD
        let startCD: UInt32 = startOfCD
        let commentLen: UInt16 = 0

        end.append(u32(sig))
        end.append(u16(disk))
        end.append(u16(diskStart))
        end.append(u16(entriesCount))
        end.append(u16(entriesCount))
        end.append(u32(sizeCD))
        end.append(u32(startCD))
        end.append(u16(commentLen))
        try out.write(contentsOf: end)
    }

    // MARK: - Helpers
    private static func u16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func u32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    private static func dosDateTime(_ date: Date) -> Data {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents(in: .current, from: date)
        let sec = UInt16(((c.second ?? 0) / 2) & 0x1F)
        let min = UInt16(c.minute ?? 0) << 5
        let hour = UInt16(c.hour ?? 0) << 11
        let time = sec | min | hour
        let day = UInt16(c.day ?? 1)
        let mon = UInt16(c.month ?? 1) << 5
        let yr = UInt16(max(0, (c.year ?? 1980) - 1980)) << 9
        let d = day | mon | yr
        return u16(time) + u16(d)
    }
}
private extension Data {
    static func + (lhs: Data, rhs: Data) -> Data { var d = Data(); d.append(lhs); d.append(rhs); return d }
}

