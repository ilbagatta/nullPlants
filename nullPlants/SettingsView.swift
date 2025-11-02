import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("settings.notificationHour") private var notificationHour: Int = 9
    @AppStorage("settings.notificationMinute") private var notificationMinute: Int = 0
    @AppStorage("settings.notifyPhoto") private var notifyPhoto: Bool = true
    @AppStorage("settings.notifyWater") private var notifyWater: Bool = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        NavigationStack {
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
    }
}

#Preview {
    SettingsView()
}
