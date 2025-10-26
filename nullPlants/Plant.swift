// Modello dati principale per una pianta e log annaffiature/foto
import Foundation

struct WateringEvent: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var liters: Double?
}

struct Plant: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: String
    var datePlanted: Date
    var wateringLog: [WateringEvent]
    var photoLog: [PlantPhoto]
    
    init(id: UUID = UUID(), name: String, type: String, datePlanted: Date, wateringLog: [WateringEvent] = [], photoLog: [PlantPhoto] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.datePlanted = datePlanted
        self.wateringLog = wateringLog
        self.photoLog = photoLog
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, datePlanted, wateringLog, photoLog
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        datePlanted = try container.decode(Date.self, forKey: .datePlanted)
        photoLog = try container.decode([PlantPhoto].self, forKey: .photoLog)
        do {
            wateringLog = try container.decode([WateringEvent].self, forKey: .wateringLog)
        } catch {
            let oldWateringLog = try container.decode([Date].self, forKey: .wateringLog)
            wateringLog = oldWateringLog.map { WateringEvent(date: $0, liters: nil) }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(datePlanted, forKey: .datePlanted)
        try container.encode(photoLog, forKey: .photoLog)
        try container.encode(wateringLog, forKey: .wateringLog)
    }
}
