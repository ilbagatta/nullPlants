import Foundation

struct PlantViewHelper {
    
    /// Restituisce l'età formattata della pianta tra due date (in italiano).
    /// - Parameters:
    ///   - startDate: Data di inizio.
    ///   - endDate: Data di fine (default: oggi).
    /// - Returns: Stringa descrittiva dell'età in anni, mesi e giorni.
    static func formattedAge(from startDate: Date, to endDate: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .weekOfYear, .day], from: startDate, to: endDate)
        var parts: [String] = []
        if let years = comps.year, years > 0 {
            parts.append("\(years) \(years == 1 ? "anno" : "anni")")
        }
        if let months = comps.month, months > 0 {
            parts.append("\(months) \(months == 1 ? "mese" : "mesi")")
        }
        if (comps.year ?? 0) == 0, (comps.month ?? 0) == 0, let weeks = comps.weekOfYear, weeks > 0 {
            parts.append("\(weeks) \(weeks == 1 ? "settimana" : "settimane")")
        }
        if let days = comps.day, days > 0 {
            parts.append("\(days) \(days == 1 ? "giorno" : "giorni")")
        }
        if parts.isEmpty { return "0 giorni" }
        return parts.prefix(2).joined(separator: " e ")
    }

    /// Restituisce l'elenco delle annaffiature ordinate per data decrescente.
    /// - Parameter plant: La pianta di riferimento.
    /// - Returns: Array di eventi di annaffiatura ordinati.
    static func sortedWaterings(for plant: Plant) -> [WateringEvent] {
        return plant.wateringLog.sorted { $0.date > $1.date }
    }

    /// Tipo usato per rappresentare una voce di foto della pianta.
    struct PlantPhotoLogEntry {
        let imageFilename: String
        let date: Date
    }

    /// Restituisce la foto più recente della pianta, se disponibile.
    /// - Parameter plant: La pianta di riferimento.
    /// - Returns: L'ultima voce di foto o nil se non ci sono foto.
    static func latestPhoto(for plant: Plant) -> PlantPhotoLogEntry? {
        guard let latest = plant.photoLog.max(by: { $0.date < $1.date }) else {
            return nil
        }
        return PlantPhotoLogEntry(imageFilename: latest.imageFilename, date: latest.date)
    }

    /// Verifica se la pianta è stata annaffiata oggi.
    /// - Parameter plant: La pianta di riferimento.
    /// - Returns: true se è stata annaffiata oggi, false altrimenti.
    static func hasWateringToday(_ plant: Plant) -> Bool {
        return plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) })
    }

    /// Esegue il parsing di una stringa in litri gestendo il separatore decimale locale.
    /// - Parameter text: Testo da parsare.
    /// - Returns: Valore Double se il parsing è andato a buon fine, nil altrimenti.
    static func parseLiters(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.decimalSeparator = Locale.current.decimalSeparator
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        } else if let val = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
            return val
        } else {
            return nil
        }
    }

    /// Restituisce le foto ordinate per data decrescente.
    /// - Parameter plant: La pianta di riferimento.
    /// - Returns: Array di foto ordinate per data.
    static func sortedPhotos(for plant: Plant) -> [PlantPhotoLogEntry] {
        plant.photoLog
            .sorted { $0.date > $1.date }
            .map { PlantPhotoLogEntry(imageFilename: $0.imageFilename, date: $0.date) }
    }

    /// Restituisce l'indice di una foto, data la filename, nella lista ordinata per data discendente.
    /// - Parameters:
    ///   - filename: Nome del file immagine da cercare.
    ///   - plant: La pianta di riferimento.
    /// - Returns: Indice se trovato, nil altrimenti.
    static func indexOfPhoto(filename: String, in plant: Plant) -> Int? {
        let sortedPhotos = sortedPhotos(for: plant)
        return sortedPhotos.firstIndex { $0.imageFilename == filename }
    }
}
