// Gestore centrale di tutte le piante per l'app nullPlants
import Foundation
import Combine

class PlantStore: ObservableObject {
    @Published var plants: [Plant] = []
    
    private let saveKey = "plants_data.json"
    
    init() {
        load()
    }
    
    // Persistenza semplificata su disco (Documenti)
    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(plants) {
            let url = getDocumentsDirectory().appendingPathComponent(saveKey)
            try? data.write(to: url)
        }
    }
    
    func load() {
        let url = getDocumentsDirectory().appendingPathComponent(saveKey)
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([Plant].self, from: data) {
            self.plants = loaded
        }
    }
    
    func addPlant(_ plant: Plant) {
        plants.append(plant)
        save()
    }
    
    func updatePlant(_ plant: Plant) {
        if let idx = plants.firstIndex(where: { $0.id == plant.id }) {
            plants[idx] = plant
            save()
        }
    }
    
    func deletePlant(_ plant: Plant) {
        plants.removeAll(where: { $0.id == plant.id })
        save()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
