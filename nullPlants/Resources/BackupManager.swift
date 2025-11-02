//
//  BackupManager.swift
//  nullPlants
//
//  Created by ilbagatta on 02/11/25.
//

import Foundation
import UniformTypeIdentifiers

final class BackupManager {
    static let shared = BackupManager()
    private init() {}

    enum BackupError: Error, LocalizedError {
        case invalidArchive
        case ioFailure
        case unsupportedFormat
        case payloadMissing(String)
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "L'archivio di backup non è valido."
            case .ioFailure: return "Errore di lettura/scrittura durante il backup."
            case .unsupportedFormat: return "Formato di backup non supportato su questa versione di sistema."
            case .payloadMissing(let name): return "Elemento mancante nel backup: \(name)"
            case .permissionDenied: return "Permessi insufficienti per completare l'operazione."
            }
        }
    }

    // MARK: - Public API
    @discardableResult
    func exportBackup() async throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let tempDir = FileManager.default.temporaryDirectory
        let workingDir = tempDir.appendingPathComponent("AppBackup-\(timestamp)", isDirectory: true)
        let payloadDir = workingDir.appendingPathComponent("payload", isDirectory: true)
        let zipURL = tempDir.appendingPathComponent("AppBackup-\(timestamp).zip")

        try? FileManager.default.removeItem(at: workingDir)
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        do {
            try prepareBackupPayload(into: payloadDir)
        } catch {
            throw BackupError.ioFailure
        }

        // Zip the whole workingDir to preserve a top-level folder in the archive
        try SimpleZip.zip(folder: workingDir, to: zipURL)
        // Optionally remove the temp working directory
        try? FileManager.default.removeItem(at: workingDir)
        return zipURL
    }

    func importBackup(from url: URL) async throws {
        let fm = FileManager.default
        var cleanupURL: URL? = nil
        let baseURL: URL = try {
            if url.pathExtension.lowercased() == "zip" {
                let temp = fm.temporaryDirectory.appendingPathComponent("nullPlantsImport-\(UUID().uuidString)", isDirectory: true)
                try fm.createDirectory(at: temp, withIntermediateDirectories: true)
                try SimpleZip.unzip(file: url, to: temp)
                cleanupURL = temp
                // If the zip contains a single top-level folder, descend into it
                let contents = try fm.contentsOfDirectory(at: temp, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                if contents.count == 1, let only = contents.first {
                    return only
                }
                return temp
            } else {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    return url
                } else {
                    throw BackupError.invalidArchive
                }
            }
        }()
        defer { if let u = cleanupURL { try? fm.removeItem(at: u) } }

        // Prefer layout with payload subfolder; fallback to base
        let payloadURL = baseURL.appendingPathComponent("payload", isDirectory: true)
        if fm.fileExists(atPath: payloadURL.appendingPathComponent("preferences.json").path) {
            try restoreBackupPayload(from: payloadURL)
        } else if fm.fileExists(atPath: baseURL.appendingPathComponent("preferences.json").path) {
            try restoreBackupPayload(from: baseURL)
        } else {
            throw BackupError.payloadMissing("preferences.json")
        }
    }

    // MARK: - Payload
    private func prepareBackupPayload(into dir: URL) throws {
        // Example: export UserDefaults under our app prefixes
        let prefsURL = dir.appendingPathComponent("preferences.json")
        let all = UserDefaults.standard.dictionaryRepresentation()
        let filtered = all.filter { key, _ in
            return key.hasPrefix("settings.")
        }
        let data = try JSONSerialization.data(withJSONObject: filtered, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: prefsURL, options: .atomic)

        // Copy Documents
        if let docs = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false),
           FileManager.default.fileExists(atPath: docs.path) {
            try copyTree(at: docs, to: dir.appendingPathComponent("Documents", isDirectory: true))
        }
        // Copy Application Support
        if let appSup = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true),
           FileManager.default.fileExists(atPath: appSup.path) {
            try copyTree(at: appSup, to: dir.appendingPathComponent("ApplicationSupport", isDirectory: true))
        }
    }

    private func restoreBackupPayload(from dir: URL) throws {
        let prefsURL = dir.appendingPathComponent("preferences.json")
        if FileManager.default.fileExists(atPath: prefsURL.path) {
            let data = try Data(contentsOf: prefsURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BackupError.invalidArchive
            }
            // Only restore known namespaces to avoid clobbering unrelated defaults
            for (key, value) in json where key.hasPrefix("settings.") {
                UserDefaults.standard.setValue(value, forKey: key)
            }
        } else {
            // Not strictly fatal, but signal missing component
            throw BackupError.payloadMissing("preferences.json")
        }

        // Restore Documents
        if let docs = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let src = dir.appendingPathComponent("Documents", isDirectory: true)
            if FileManager.default.fileExists(atPath: src.path) {
                try copyTree(at: src, to: docs, overwrite: true)
            }
        }
        // Restore Application Support
        if let appSup = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let src = dir.appendingPathComponent("ApplicationSupport", isDirectory: true)
            if FileManager.default.fileExists(atPath: src.path) {
                try copyTree(at: src, to: appSup, overwrite: true)
            }
        }
    }

    // MARK: - Directory copy helper
    private func copyTree(at src: URL, to dst: URL, overwrite: Bool = false) throws {
        let fm = FileManager.default
        if overwrite, fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        if let enumerator = fm.enumerator(at: src, includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                let relPath = fileURL.path.replacingOccurrences(of: src.path + "/", with: "")
                let destURL = dst.appendingPathComponent(relPath)
                let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if values.isDirectory == true {
                    try fm.createDirectory(at: destURL, withIntermediateDirectories: true)
                } else {
                    try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
                    try fm.copyItem(at: fileURL, to: destURL)
                }
            }
        }
    }
}
