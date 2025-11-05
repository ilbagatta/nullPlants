import Foundation
import SwiftUI

struct BackupManager {
    enum ConflictPolicy {
        case overwrite
        case duplicate
    }
    
    struct ExportScope {
        /// If nil, export all plants
        let plantIDs: [UUID]?
    }
    
    private struct Manifest: Codable {
        struct Header: Codable {
            let app: String
            let version: Int
            let exportedAt: Date
        }
        
        struct PlantPayload: Codable {
            let id: UUID
            let name: String
            let type: String
            let datePlanted: Date
            let wateringLog: [WateringEventPayload]
            let photoLog: [PlantPhotoPayload]
        }
        
        struct WateringEventPayload: Codable {
            let date: Date
            let liters: Double?
        }
        
        struct PlantPhotoPayload: Codable {
            let date: Date
            let filename: String
        }
        
        let header: Header
        let plants: [PlantPayload]
        let media: [String]
    }
    
    private static let manifestFilename = "manifest.json"
    private static let mediaFolderName = "media"
    
    // MARK: - Export
    
    static func exportBackup(from store: PlantStore, scope: ExportScope? = nil, to destinationZipURL: URL) throws {
        let exportPlants: [Plant]
        if let selectedIDs = scope?.plantIDs {
            exportPlants = store.plants.filter { selectedIDs.contains($0.id) }
        } else {
            exportPlants = store.plants
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let tempBackupFolder = cachesDirectory().appendingPathComponent("nullplants_backup_\(timestamp)", isDirectory: true)
        
        try ensureDir(tempBackupFolder)
        let mediaDir = tempBackupFolder.appendingPathComponent(mediaFolderName, isDirectory: true)
        try ensureDir(mediaDir)
        
        // Collect media filenames to include (unique)
        var mediaFilenamesSet = Set<String>()
        // Map from original filename -> copied filename (no rename on export, so same)
        
        // Prepare plants payload
        let plantsPayload: [Manifest.PlantPayload] = exportPlants.map { plant in
            let wateringLogPayload = plant.wateringLog.map {
                Manifest.WateringEventPayload(date: $0.date, liters: $0.liters)
            }
            let photoLogPayload = plant.photoLog.map { photo -> Manifest.PlantPhotoPayload in
                let filename = photo.imageFilename
                mediaFilenamesSet.insert(filename)
                return Manifest.PlantPhotoPayload(date: photo.date, filename: filename)
            }
            return Manifest.PlantPayload(
                id: plant.id,
                name: plant.name,
                type: plant.type,
                datePlanted: plant.datePlanted,
                wateringLog: wateringLogPayload,
                photoLog: photoLogPayload
            )
        }
        
        // Copy media files from Documents to mediaDir
        let docsDir = documentsDirectory()
        for filename in mediaFilenamesSet {
            let srcURL = docsDir.appendingPathComponent(filename)
            let destURL = mediaDir.appendingPathComponent(filename)
            try copyIfExists(from: srcURL, to: destURL)
        }
        
        // Build manifest
        let manifest = Manifest(
            header: Manifest.Header(app: "nullPlants", version: 1, exportedAt: Date()),
            plants: plantsPayload,
            media: Array(mediaFilenamesSet).sorted()
        )
        
        // Encode manifest to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        let manifestURL = tempBackupFolder.appendingPathComponent(manifestFilename)
        try manifestData.write(to: manifestURL, options: [.atomic])
        
        // Zip tempBackupFolder into destinationZipURL
        try SimpleZip.zip(folder: tempBackupFolder, to: destinationZipURL)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempBackupFolder)
    }
    
    // MARK: - Import
    
    static func importBackup(into store: PlantStore, from url: URL, conflictPolicy: ConflictPolicy = .duplicate) throws {
        let isZip = url.pathExtension.lowercased() == "zip"
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let tempImportFolder = cachesDirectory().appendingPathComponent("nullplants_import_\(timestamp)", isDirectory: true)
        
        try ensureDir(tempImportFolder)
        
        if isZip {
            try SimpleZip.unzip(file: url, to: tempImportFolder)
        } else {
            // If not zip, treat url as folder with manifest.json inside
            // Copy folder content into tempImportFolder to unify handling
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                throw NSError(domain: "BackupManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import URL is not a directory"])
            }
            // Copy contents of url folder into tempImportFolder
            let contents = try FileManager.default.contentsOfDirectory(atPath: url.path)
            for item in contents {
                let src = url.appendingPathComponent(item)
                let dst = tempImportFolder.appendingPathComponent(item)
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
        
        // Find manifest.json
        let manifestURL = tempImportFolder.appendingPathComponent(manifestFilename)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "BackupManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "manifest.json not found in import"])
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Decode manifest ignoring unknown keys
        let manifest = try decoder.decode(Manifest.self, from: manifestData)
        
        let mediaDir = tempImportFolder.appendingPathComponent(mediaFolderName, isDirectory: true)
        let docsDir = documentsDirectory()
        
        // Helper: Find existing plant by id or name
        func existingPlant(withId id: UUID) -> Plant? {
            store.plants.first(where: { $0.id == id })
        }
        
        func plantWithNameExists(_ name: String) -> Bool {
            store.plants.contains(where: { $0.name == name })
        }
        
        for payload in manifest.plants {
            switch conflictPolicy {
            case .overwrite:
                if let existing = existingPlant(withId: payload.id) {
                    // Replace entirely
                    let newPhotos = try copyPhotosAndBuildPhotoLog(
                        from: payload.photoLog,
                        mediaDirectory: mediaDir,
                        documentsDirectory: docsDir
                    )
                    let newWateringLog = payload.wateringLog.map {
                        WateringEvent(date: $0.date, liters: $0.liters)
                    }
                    let updatedPlant = Plant(
                        id: payload.id,
                        name: payload.name,
                        type: payload.type,
                        datePlanted: payload.datePlanted,
                        wateringLog: newWateringLog,
                        photoLog: newPhotos
                    )
                    store.updatePlant(updatedPlant)
                } else {
                    // Insert new with same id if no conflict
                    let newPhotos = try copyPhotosAndBuildPhotoLog(
                        from: payload.photoLog,
                        mediaDirectory: mediaDir,
                        documentsDirectory: docsDir
                    )
                    let newWateringLog = payload.wateringLog.map {
                        WateringEvent(date: $0.date, liters: $0.liters)
                    }
                    let newPlant = Plant(
                        id: payload.id,
                        name: payload.name,
                        type: payload.type,
                        datePlanted: payload.datePlanted,
                        wateringLog: newWateringLog,
                        photoLog: newPhotos
                    )
                    store.addPlant(newPlant)
                }
                
            case .duplicate:
                // Always create a new plant with new UUID
                var newName = payload.name
                if plantWithNameExists(newName) {
                    newName += " (import)"
                }
                let newPhotos = try copyPhotosAndBuildPhotoLog(
                    from: payload.photoLog,
                    mediaDirectory: mediaDir,
                    documentsDirectory: docsDir
                )
                let newWateringLog = payload.wateringLog.map {
                    WateringEvent(date: $0.date, liters: $0.liters)
                }
                let newPlant = Plant(
                    id: UUID(),
                    name: newName,
                    type: payload.type,
                    datePlanted: payload.datePlanted,
                    wateringLog: newWateringLog,
                    photoLog: newPhotos
                )
                store.addPlant(newPlant)
            }
        }
        
        store.save()
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempImportFolder)
    }
    
    // MARK: - Internal Helpers
    
    /// Returns the app's Documents directory URL
    static func documentsDirectory() -> URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[0]
    }
    
    /// Returns the app's Caches directory URL
    static func cachesDirectory() -> URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0]
    }
    
    /// Ensures the directory exists at given URL.
    /// Creates it if missing.
    /// Throws on error.
    static func ensureDir(_ url: URL) throws {
        var isDir: ObjCBool = false
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw NSError(domain: "BackupManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Expected directory at \(url.path) but found file"])
            }
        } else {
            try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    /// Produces a unique filename in the specified directory, by appending numeric suffixes if needed.
    /// baseName should be without extension.
    /// ext should be without leading dot.
    static func uniqueFilename(in directory: URL, baseName: String, ext: String) -> String {
        var candidate = baseName + (ext.isEmpty ? "" : ".\(ext)")
        var index = 1
        let fm = FileManager.default
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(baseName) \(index)" + (ext.isEmpty ? "" : ".\(ext)")
            index += 1
        }
        return candidate
    }
    
    /// Copies file at srcURL to destURL if it exists.
    /// If srcURL does not exist, no error is thrown, operation is skipped.
    static func copyIfExists(from srcURL: URL, to destURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: srcURL.path) {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: srcURL, to: destURL)
        }
    }
    
    /// Copies photo files from media directory to Documents directory with collision-safe unique names.
    /// Returns array of PlantPhoto objects with updated filenames.
    private static func copyPhotosAndBuildPhotoLog(from photoPayloads: [Manifest.PlantPhotoPayload], mediaDirectory: URL, documentsDirectory: URL) throws -> [PlantPhoto] {
        var result: [PlantPhoto] = []
        let fm = FileManager.default
        
        for photoPayload in photoPayloads {
            let srcURL = mediaDirectory.appendingPathComponent(photoPayload.filename)
            if !fm.fileExists(atPath: srcURL.path) {
                // Missing media file, skip gracefully
                continue
            }
            
            let baseName = (photoPayload.filename as NSString).deletingPathExtension
            let ext = (photoPayload.filename as NSString).pathExtension
            
            let uniqueFilename = uniqueFilename(in: documentsDirectory, baseName: baseName, ext: ext)
            let destURL = documentsDirectory.appendingPathComponent(uniqueFilename)
            
            try copyIfExists(from: srcURL, to: destURL)
            
            let photo = PlantPhoto(date: photoPayload.date, imageFilename: uniqueFilename)
            result.append(photo)
        }
        
        return result
    }
}
