import SwiftUI

struct PlantsListView: View {
    // Store & Theme
    @StateObject private var store = PlantStore()
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.colorScheme) private var systemScheme

    // UI State
    @State private var showingAdd = false
    @State private var showingSettings = false

    // MARK: - Lunar phase helpers (approximate) — copied from ContentView for consistency
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
        let synodicMonth: Double = 29.53058867
        let referenceComponents = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2000, month: 1, day: 6, hour: 18, minute: 14)
        let referenceDate = referenceComponents.date ?? Date(timeIntervalSince1970: 946728840)

        let interval = date.timeIntervalSince(referenceDate)
        let daysSinceReference = interval / 86400.0
        let age = (daysSinceReference.truncatingRemainder(dividingBy: synodicMonth) + synodicMonth).truncatingRemainder(dividingBy: synodicMonth)

        let phaseName = phaseNameForAge(age)
        let daysUntil = daysUntilNextWaxingCrescentStart(fromAge: age, synodicMonth: synodicMonth)
        return (phaseName, daysUntil)
    }

    private func phaseNameForAge(_ age: Double) -> String {
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
        let targetStart: Double = 0.5
        var delta = targetStart - age
        if (delta <= 0) { delta += synodicMonth }
        let days = Int(ceil(delta))
        return max(days, 0)
    }

    private var currentPhaseName: String {
        lunarPhaseSummary(for: Date()).0
    }

    private var customDayChangeLine: String? {
        let cutoffMinutes = UserDefaults.standard.integer(forKey: "settings.customDayCutoffMinutes")
        guard cutoffMinutes > 0 else { return nil }
        let hours = cutoffMinutes / 60
        let minutes = cutoffMinutes % 60
        let comps = DateComponents(calendar: Calendar.current, hour: hours, minute: minutes)
        let time = comps.date ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "Il giorno cambia alle \(formatter.string(from: time))"
    }

    // MARK: - Moon symbol mapping
    private func moonSymbolName(for phaseName: String) -> String {
        switch phaseName {
        case "Luna nuova": return "moonphase.new"
        case "Luna crescente": return "moonphase.waxing.crescent"
        case "Primo quarto": return "moonphase.first.quarter"
        case "Gibbosa crescente": return "moonphase.waxing.gibbous"
        case "Luna piena": return "moonphase.full"
        case "Gibbosa calante": return "moonphase.waning.gibbous"
        case "Ultimo quarto": return "moonphase.last.quarter"
        case "Luna calante": return "moonphase.waning.crescent"
        default: return "moonphase.new"
        }
    }

    // MARK: - Age formatting helper
    private func formattedAge(from startDate: Date, to endDate: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .weekOfYear, .day], from: startDate, to: endDate)
        var parts: [String] = []
        if let years = comps.year, years > 0 { parts.append("\(years) \(years == 1 ? "anno" : "anni")") }
        if let months = comps.month, months > 0 { parts.append("\(months) \(months == 1 ? "mese" : "mesi")") }
        if (comps.year ?? 0) == 0, (comps.month ?? 0) == 0, let weeks = comps.weekOfYear, weeks > 0 { parts.append("\(weeks) \(weeks == 1 ? "settimana" : "settimane")") }
        if let days = comps.day, days > 0 { parts.append("\(days) \(days == 1 ? "giorno" : "giorni")") }
        if parts.isEmpty { return "0 giorni" }
        return parts.prefix(2).joined(separator: " e ")
    }

    // MARK: - Custom day boundary helper
    private func isSameCustomDay(date1: Date, date2: Date, cutoffMinutes: Int) -> Bool {
        let calendar = Calendar.current
        func shifted(_ d: Date) -> Date {
            let cutoffH = cutoffMinutes / 60
            let cutoffM = cutoffMinutes % 60
            return calendar.date(byAdding: DateComponents(hour: -cutoffH, minute: -cutoffM), to: d) ?? d
        }
        let s1 = shifted(date1)
        let s2 = shifted(date2)
        return calendar.isDate(s1, inSameDayAs: s2)
    }

    var body: some View {
        ZStack {
            // Background gradient (top -> bottom), respects followSystem/theme settings
            theme.appBackgroundGradient(system: systemScheme)
                .ignoresSafeArea()

            NavigationStack {
                List {
                    // Fase lunare flat
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: moonSymbolName(for: currentPhaseName))
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
                            if let customLine = customDayChangeLine {
                                Text(customLine)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Lista piante flat
                    Section {
                        ForEach($store.plants) { $plant in
                            NavigationLink(destination: PlantDetailView(plant: $plant, store: store)) {
                                HStack(alignment: .center, spacing: 12) {
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
                                            let cutoffMinutes = UserDefaults.standard.integer(forKey: "settings.customDayCutoffMinutes")
                                            let cutoff = cutoffMinutes > 0 ? cutoffMinutes : 0
                                            if !plant.wateringLog.contains(where: { isSameCustomDay(date1: $0.date, date2: Date(), cutoffMinutes: cutoff) }) {
                                                Image(systemName: "drop.fill").foregroundStyle(.blue)
                                            }
                                            let hasPhotoToday = plant.photoLog.contains { isSameCustomDay(date1: $0.date, date2: Date(), cutoffMinutes: cutoff) }
                                            if !hasPhotoToday {
                                                Image(systemName: "camera.fill").foregroundStyle(.orange)
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
                    } header: {
                        Text("Piante")
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Le tue piante")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Impostazioni")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Aggiungi pianta")
                    }
                }
                .sheet(isPresented: $showingAdd) {
                    AddPlantView(store: store)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                        .environmentObject(store)
                        .environmentObject(theme)
                }
            }
        }
        .task {
            await initializeNotificationsIfNeeded()
        }
        .preferredColorScheme(theme.effectiveScheme(system: nil))
    }

    private func initializeNotificationsIfNeeded() async {
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
    PlantsListView()
        .environmentObject(ThemeSettings())
}

