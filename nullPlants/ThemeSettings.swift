import SwiftUI
import Combine

enum AppColorScheme: String, CaseIterable, Identifiable {
    case light
    case dark
    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class ThemeSettings: ObservableObject {
    // Backing storage in AppStorage
    @AppStorage("theme_followSystem") private var followSystemStorage: Bool = true
    @AppStorage("theme_selectedScheme") private var selectedSchemeRawStorage: String = AppColorScheme.light.rawValue

    // Published mirrors to trigger ObservableObject updates
    @Published var followSystem: Bool = true
    @Published var selectedScheme: AppColorScheme = .light

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize published values from storage safely after all stored properties are set
        let storedFollow = followSystemStorage
        let storedSchemeRaw = selectedSchemeRawStorage
        self.followSystem = storedFollow
        self.selectedScheme = AppColorScheme(rawValue: storedSchemeRaw) ?? .light

        // Set up bindings
        setupBindings()
    }

    private func setupBindings() {
        // Sync published -> storage
        $followSystem
            .sink { [weak self] newValue in
                self?.followSystemStorage = newValue
            }
            .store(in: &cancellables)

        $selectedScheme
            .sink { [weak self] newValue in
                self?.selectedSchemeRawStorage = newValue.rawValue
            }
            .store(in: &cancellables)
    }

    // Helper to compute the effective scheme
    func effectiveScheme(system scheme: ColorScheme?) -> ColorScheme? {
        if followSystem { return nil }
        return selectedScheme.colorScheme
    }
}
