// Modello dati per una foto della pianta, con data
import Foundation

struct PlantPhoto: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var imageFilename: String // Nome file dell'immagine salvata sul device
    
    init(id: UUID = UUID(), date: Date, imageFilename: String) {
        self.id = id
        self.date = date
        self.imageFilename = imageFilename
    }
}
