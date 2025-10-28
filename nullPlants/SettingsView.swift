import SwiftUI

struct SettingsView: View {
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
            }
            .navigationTitle("Impostazioni")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
