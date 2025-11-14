import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("settings.notificationHour") private var notificationHour: Int = 9
    @AppStorage("settings.notificationMinute") private var notificationMinute: Int = 0
    @AppStorage("settings.notifyPhoto") private var notifyPhoto: Bool = true
    @AppStorage("settings.notifyWater") private var notifyWater: Bool = false
    @AppStorage("settings.customDayCutoffMinutes") private var customDayCutoffMinutes: Int = 0

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var store: PlantStore

    @State private var exportedZipURL: URL? = nil
    @State private var showingImporter: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showingExportPolicy: Bool = false

    @State private var showingImportPolicy: Bool = false
    @State private var pendingImportPolicy: BackupManager.ConflictPolicy = .duplicate

    @State private var pendingImportURL: URL? = nil
    @State private var importConflictsCount: Int = 0

    @State private var showingExportScopeDialog: Bool = false
    @State private var showingExportPicker: Bool = false
    @State private var selectedPlantIDsForExport: Set<UUID> = []

    @State private var isWorking: Bool = false
    @State private var showingShareSheet: Bool = false

    var body: some View {
        NavigationStack {
            TabView {
                // Generali Tab
                Form {

                    Section(header: Text("Giorno personalizzato"), footer: Text("Definisci a che ora inizia il nuovo giorno per i controlli di foto e irrigazione. Utile se fotografi/annaffi tardi la sera.")) {
                        DatePicker("Inizio nuovo giorno", selection: Binding(get: {
                            let minutes = customDayCutoffMinutes
                            let h = minutes / 60
                            let m = minutes % 60
                            var comps = DateComponents()
                            comps.hour = h
                            comps.minute = m
                            return Calendar.current.date(from: comps) ?? Date()
                        }, set: { newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            let h = comps.hour ?? 0
                            let m = comps.minute ?? 0
                            customDayCutoffMinutes = h * 60 + m
                        }), displayedComponents: .hourAndMinute)

                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text({ () -> String in
                                let minutes = customDayCutoffMinutes
                                let h = minutes / 60
                                let m = minutes % 60
                                var comps = DateComponents()
                                comps.hour = h
                                comps.minute = m
                                let date = Calendar.current.date(from: comps) ?? Date()
                                let df = DateFormatter()
                                df.timeStyle = .short
                                df.dateStyle = .none
                                return "Il giorno cambia alle \(df.string(from: date))"
                            }())
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .tabItem {
                    Label("Generali", systemImage: "gearshape")
                }

                // Notifiche Tab
                Form {
                    Section(header: Text("Notifiche"), footer: Text("Le notifiche sono locali e si ripetono ogni giorno all'orario selezionato.")) {
                        Toggle("Abilita notifiche giornaliere", isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { newValue in
                                if newValue {
                                    Task {
                                        let granted = (try? await NotificationManager.shared.requestAuthorization()) ?? false
                                        if granted {
                                            NotificationManager.shared.refreshScheduleFromStoredPreferences()
                                        } else {
                                            notificationsEnabled = false
                                        }
                                    }
                                } else {
                                    NotificationManager.shared.cancelAllManagedNotifications()
                                }
                            }

                        if notificationsEnabled {
                            DatePicker("Orario", selection: Binding(get: {
                                var comps = DateComponents()
                                comps.hour = notificationHour
                                comps.minute = notificationMinute
                                return Calendar.current.date(from: comps) ?? Date()
                            }, set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                notificationHour = comps.hour ?? 9
                                notificationMinute = comps.minute ?? 0
                                NotificationManager.shared.refreshScheduleFromStoredPreferences()
                            }), displayedComponents: .hourAndMinute)

                            Toggle("Promemoria foto", isOn: $notifyPhoto)
                                .onChange(of: notifyPhoto) { _ in
                                    NotificationManager.shared.refreshScheduleFromStoredPreferences()
                                }

                            Toggle("Promemoria irrigazione", isOn: $notifyWater)
                                .onChange(of: notifyWater) { _ in
                                    NotificationManager.shared.refreshScheduleFromStoredPreferences()
                                }
                        }
                    }
                }
                .tabItem {
                    Label("Notifiche", systemImage: "bell")
                }

                // Altro Tab
                Form {
                    Section(header: Text("Aspetto")) {
                        Toggle("Segui tema del device", isOn: $theme.followSystem)
                        Picker("Tema", selection: Binding(get: { theme.selectedScheme }, set: { theme.selectedScheme = $0 })) {
                            Text("Chiaro").tag(AppColorScheme.light)
                            Text("Scuro").tag(AppColorScheme.dark)
                        }
                        .pickerStyle(.segmented)
                        .disabled(theme.followSystem)
                    }

                    Section(header: Text("Backup")) {
                        Button {
                            showingExportScopeDialog = true
                        } label: {
                            Label("Esporta backup", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showingImporter = true
                        } label: {
                            Label("Importa backup", systemImage: "square.and.arrow.down")
                        }
                    }
                }
                .tabItem {
                    Label("Altro", systemImage: "ellipsis.circle")
                }
            }
            .navigationTitle("Impostazioni")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .task {
                if notificationsEnabled {
                    let granted = (try? await NotificationManager.shared.requestAuthorization()) ?? false
                    if granted {
                        NotificationManager.shared.refreshScheduleFromStoredPreferences()
                    } else {
                        notificationsEnabled = false
                    }
                } else {
                    NotificationManager.shared.cancelAllManagedNotifications()
                }
            }
        }
        .overlay(
            Group {
                if isWorking {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView("Elaborazione in corso…")
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Questo potrebbe richiedere qualche istante.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(radius: 10)
                    }
                }
            }
        )
        .sheet(isPresented: $showingImporter) {
            DocumentPicker(allowedContentTypes: ["public.zip-archive"]) { url in
                if let url {
                    isWorking = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let preview = try BackupManager.previewImport(into: store, from: url)
                            if preview.conflictingPlantIDs.isEmpty {
                                try BackupManager.importBackup(into: store, from: url, conflictPolicy: .duplicate)
                                DispatchQueue.main.async { isWorking = false; alertMessage = "Import completato" }
                            } else {
                                DispatchQueue.main.async {
                                    pendingImportURL = url
                                    importConflictsCount = preview.conflictingPlantIDs.count
                                    isWorking = false
                                    showingImportPolicy = true
                                }
                            }
                        } catch {
                            DispatchQueue.main.async { isWorking = false; alertMessage = "Errore anteprima import: \(error.localizedDescription)" }
                        }
                    }
                }
            }
        }
        .alert("Backup", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog("Politica di import", isPresented: $showingImportPolicy, titleVisibility: .visible) {
            Button("Duplica") {
                guard let url = pendingImportURL else { return }
                isWorking = true
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try BackupManager.importBackup(into: store, from: url, conflictPolicy: .duplicate)
                        DispatchQueue.main.async { isWorking = false; alertMessage = "Import completato" }
                    } catch {
                        DispatchQueue.main.async { isWorking = false; alertMessage = "Errore import: \(error.localizedDescription)" }
                    }
                }
                pendingImportURL = nil
            }
            Button("Sovrascrivi", role: .destructive) {
                guard let url = pendingImportURL else { return }
                isWorking = true
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try BackupManager.importBackup(into: store, from: url, conflictPolicy: .overwrite)
                        DispatchQueue.main.async { isWorking = false; alertMessage = "Import completato" }
                    } catch {
                        DispatchQueue.main.async { isWorking = false; alertMessage = "Errore import: \(error.localizedDescription)" }
                    }
                }
                pendingImportURL = nil
            }
            Button("Annulla", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("Trovate \(importConflictsCount) piante già esistenti. Come vuoi procedere?")
        }
        .confirmationDialog("Esporta", isPresented: $showingExportScopeDialog, titleVisibility: .visible) {
            Button("Tutte le piante") {
                isWorking = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("nullplants_backup_\(Int(Date().timeIntervalSince1970)).zip")
                    if let finalURL = try? BackupManager.exportBackup(from: store, scope: nil, to: dest, ifDestinationExists: .duplicate) {
                        DispatchQueue.main.async {
                            exportedZipURL = finalURL
                            isWorking = false
                            showingShareSheet = true
                        }
                    } else {
                        DispatchQueue.main.async { isWorking = false; alertMessage = "Errore export" }
                    }
                }
            }
            Button("Seleziona piante…") {
                selectedPlantIDsForExport = []
                showingExportPicker = true
            }
            Button("Annulla", role: .cancel) {}
        }
        .sheet(isPresented: $showingExportPicker) {
            NavigationStack {
                List {
                    ForEach(store.plants) { plant in
                        Toggle(isOn: Binding(
                            get: { selectedPlantIDsForExport.contains(plant.id) },
                            set: { isOn in
                                if isOn { selectedPlantIDsForExport.insert(plant.id) }
                                else { selectedPlantIDsForExport.remove(plant.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plant.name)
                                Text(plant.type).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Seleziona piante")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { showingExportPicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Esporta") {
                            isWorking = true
                            DispatchQueue.global(qos: .userInitiated).async {
                                let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("nullplants_backup_\(Int(Date().timeIntervalSince1970)).zip")
                                let scope = BackupManager.ExportScope(plantIDs: Array(selectedPlantIDsForExport))
                                if let finalURL = try? BackupManager.exportBackup(from: store, scope: scope, to: dest, ifDestinationExists: .duplicate) {
                                    DispatchQueue.main.async {
                                        exportedZipURL = finalURL
                                        isWorking = false
                                        showingExportPicker = false
                                        showingShareSheet = true
                                    }
                                } else {
                                    DispatchQueue.main.async { isWorking = false; alertMessage = "Errore export" }
                                }
                            }
                        }
                        .disabled(selectedPlantIDsForExport.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: { exportedZipURL = nil }) {
            if let url = exportedZipURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

import UniformTypeIdentifiers
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [String]
    var onPick: (URL?) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = allowedContentTypes.compactMap { UTType(importedAs: $0) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
