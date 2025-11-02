// Schermata principale dell'app nullPlants: lista piante, aggiunta, navigazione dettagli
import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var store = PlantStore()
    @EnvironmentObject private var theme: ThemeSettings
    @State private var showingAdd = false
    @State private var showingSettings = false

    // MARK: - Lunar phase helpers (approximate)
    private var lunarPhaseLine: String {
        let (phaseName, _) = lunarPhaseSummary(for: Date())
        return "Fase lunare: \(phaseName)"
    }

    private var lunarCountdownLine: String? {
        let (_, daysUntilWaxingCrescent) = lunarPhaseSummary(for: Date())
        if let days = daysUntilWaxingCrescent {
            let dayWord = days == 1 ? "giorno" : "giorni"
            return "\(days) \(dayWord) al primo giorno di luna crescente"
        } else {
            return nil
        }
    }

    private func lunarPhaseSummary(for date: Date) -> (String, Int?) {
        // Compute moon age in days using a simple approximation with a known new moon reference.
        let synodicMonth: Double = 29.53058867
        let referenceComponents = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2000, month: 1, day: 6, hour: 18, minute: 14)
        let referenceDate = referenceComponents.date ?? Date(timeIntervalSince1970: 946728840) // 2000-01-06 18:14:00 UTC

        let interval = date.timeIntervalSince(referenceDate)
        let daysSinceReference = interval / 86400.0
        let age = (daysSinceReference.truncatingRemainder(dividingBy: synodicMonth) + synodicMonth).truncatingRemainder(dividingBy: synodicMonth)

        let phaseName = phaseNameForAge(age)

        // Define the first day of waxing crescent as when age in [0.5, 3.5) roughly (after new moon, visible crescent)
        // We'll compute days until next age in that interval starting from date.
        let daysUntil = daysUntilNextWaxingCrescentStart(fromAge: age, synodicMonth: synodicMonth)
        return (phaseName, daysUntil)
    }

    private func phaseNameForAge(_ age: Double) -> String {
        // Basic mapping of age to phase
        switch age {
        case 0..<1.84566: return "Luna nuova"
        case 1.84566..<5.53699: return "Luna crescente"
        case 5.53699..<9.22831: return "Primo quarto"
        case 9.22831..<12.91963: return "Gibbosa crescente"
        case 12.91963..<16.61096: return "Luna piena"
        case 16.61096..<20.30228: return "Gibbosa calante"
        case 20.30228..<23.99361: return "Ultimo quarto"
        case 23.99361..<27.68493: return "Luna calante"
        default: return "Luna nuova"
        }
    }

    private func daysUntilNextWaxingCrescentStart(fromAge age: Double, synodicMonth: Double) -> Int? {
        // Consider first day of waxing crescent around age ~0.5 days after new moon
        let targetStart: Double = 0.5
        var delta = targetStart - age
        if delta <= 0 { delta += synodicMonth }
        // Round up to whole days
        let days = Int(ceil(delta))
        return max(days, 0)
    }

    // MARK: - Moon symbol mapping
    private func moonSymbolName(for phaseName: String) -> String {
        // Map Italian phase names to SF Symbols variants
        switch phaseName {
        case "Luna nuova":
            return "moonphase.new"
        case "Luna crescente":
            return "moonphase.waxing.crescent"
        case "Primo quarto":
            return "moonphase.first.quarter"
        case "Gibbosa crescente":
            return "moonphase.waxing.gibbous"
        case "Luna piena":
            return "moonphase.full"
        case "Gibbosa calante":
            return "moonphase.waning.gibbous"
        case "Ultimo quarto":
            return "moonphase.last.quarter"
        case "Luna calante":
            return "moonphase.waning.crescent"
        default:
            return "moonphase.new"
        }
    }

    // MARK: - Age formatting helper
    private func formattedAge(from startDate: Date, to endDate: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .weekOfYear, .day], from: startDate, to: endDate)
        var parts: [String] = []
        if let years = comps.year, years > 0 {
            parts.append("\(years) \(years == 1 ? "anno" : "anni")")
        }
        if let months = comps.month, months > 0 {
            parts.append("\(months) \(months == 1 ? "mese" : "mesi")")
        }
        // Prefer weeks only when years and months are zero to avoid redundancy
        if (comps.year ?? 0) == 0, (comps.month ?? 0) == 0, let weeks = comps.weekOfYear, weeks > 0 {
            parts.append("\(weeks) \(weeks == 1 ? "settimana" : "settimane")")
        }
        // Days remainder
        if let days = comps.day, days > 0 {
            parts.append("\(days) \(days == 1 ? "giorno" : "giorni")")
        }
        if parts.isEmpty { return "0 giorni" }
        // Join first two most significant parts to keep it concise
        return parts.prefix(2).joined(separator: " e ")
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                } header: {
                    HStack(alignment: .center, spacing: 12) {
                        let (phaseName, _) = lunarPhaseSummary(for: Date())
                        Image(systemName: moonSymbolName(for: phaseName))
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lunarPhaseLine)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if let countdown = lunarCountdownLine {
                                Text(countdown)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .textCase(nil)
                }
                
                ForEach($store.plants) { $plant in
                    NavigationLink(destination: PlantDetailView(plant: $plant, store: store)) {
                        HStack(alignment: .center, spacing: 12) {
                            // Leading circular thumbnail: latest photo or placeholder
                            let latestPhoto = plant.photoLog.sorted(by: { $0.date > $1.date }).first
                            Group {
                                if let latest = latestPhoto, let uiImage = ImageStorage.loadImage(latest.imageFilename) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        Color.gray.opacity(0.2)
                                        Image(systemName: "leaf.fill").foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(plant.name)
                                    // Show drop icon if not watered today
                                    if !plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(.blue)
                                    }
                                    // Show camera icon if no photo logged today
                                    let hasPhotoToday = plant.photoLog.contains { Calendar.current.isDateInToday($0.date) }
                                    if !hasPhotoToday {
                                        Image(systemName: "camera.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .font(.headline)
                                Text(plant.type)
                                    .font(.subheadline)
                                Text("Età: \(formattedAge(from: plant.datePlanted))")
                                    .font(.footnote)
                            }
                        }
                    }
                }
                .onDelete { indices in
                    indices.map { store.plants[$0] }.forEach(store.deletePlant)
                }
            }
            //.navigationTitle("nullPlants")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Impostazioni", systemImage: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Aggiungi", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPlantView(store: store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .task {
            await initializeNotificationsIfNeeded()
        }
        .preferredColorScheme(theme.effectiveScheme(system: nil))
    }
    
    private func initializeNotificationsIfNeeded() async {
        // Read stored preferences
        let enabled = UserDefaults.standard.bool(forKey: "settings.notificationsEnabled")
        if enabled {
            let granted = (try? await NotificationManager.shared.requestAuthorization()) ?? false
            if granted {
                NotificationManager.shared.refreshScheduleFromStoredPreferences()
            }
        } else {
            NotificationManager.shared.cancelAllManagedNotifications()
        }
    }
}

#Preview {
    ContentView()
}
