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

    // MARK: - App Background Gradient
    /// Light mode colors: very light green to medium green
    private var lightStart: Color { Color(red: 0.90, green: 0.98, blue: 0.90) } // very light green
    private var lightEnd: Color { Color(red: 0.40, green: 0.80, blue: 0.50) }   // medium green

    /// Dark mode colors: medium green to dark green
    private var darkStart: Color { Color(red: 0.30, green: 0.65, blue: 0.45) }  // medium green
    private var darkEnd: Color { Color(red: 0.05, green: 0.25, blue: 0.15) }    // dark green

    /// Gradient that goes from top to bottom for the provided scheme
    private func gradient(for scheme: AppColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .light ? [lightStart, lightEnd] : [darkStart, darkEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Public helper to obtain the app background gradient considering followSystem and optional system scheme
    func appBackgroundGradient(system systemScheme: ColorScheme?) -> LinearGradient {
        if followSystem {
            if let systemScheme {
                return gradient(for: systemScheme == .light ? .light : .dark)
            } else {
                // Default to light if system scheme is unknown
                return gradient(for: .light)
            }
        } else {
            return gradient(for: selectedScheme)
        }
    }
}
