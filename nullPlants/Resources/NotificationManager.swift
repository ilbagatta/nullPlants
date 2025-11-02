import Foundation
import UserNotifications

public enum NotificationType: String, CaseIterable {
    case photoReminder = "photoReminder"
    case wateringReminder = "wateringReminder"
    
    public var userFacingTitle: String {
        switch self {
        case .photoReminder:
            return "Promemoria foto giornaliera"
        case .wateringReminder:
            return "Promemoria irrigazione"
        }
    }
}

public final class NotificationManager {
    public static let shared = NotificationManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    
    /// Requests authorization to show notifications with alert, sound, and badge options.
    /// - Returns: A boolean indicating whether authorization was granted.
    /// - Throws: An error if the authorization request fails.
    public func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        return try await center.requestAuthorization(options: options)
    }
    
    /// Schedules daily notifications at the specified time for the given notification types.
    /// Cancels existing notifications managed by this class before scheduling new ones.
    /// - Parameters:
    ///   - components: The date components specifying the time (hour and minute) for the notifications.
    ///   - enabledTypes: The notification types to schedule.
    public func scheduleDailyNotifications(at components: DateComponents, enabledTypes: [NotificationType]) {
        guard !enabledTypes.isEmpty else {
            cancelAllManagedNotifications()
            return
        }
        
        cancelAllManagedNotifications()
        
        let center = UNUserNotificationCenter.current()
        
        var normalizedComponents = DateComponents()
        normalizedComponents.hour = components.hour
        normalizedComponents.minute = components.minute
        
        for type in enabledTypes {
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            
            switch type {
            case .photoReminder:
                content.title = "Promemoria foto giornaliera"
                content.body = "Scatta la foto della pianta di oggi"
            case .wateringReminder:
                content.title = "Promemoria irrigazione"
                content.body = "Ricordati di annaffiare le tue piante"
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: normalizedComponents, repeats: true)
            let request = UNNotificationRequest(identifier: buildIdentifier(for: type), content: content, trigger: trigger)
            
            center.add(request)
        }
    }
    
    /// Cancels all scheduled notification requests managed by this class.
    public func cancelAllManagedNotifications() {
        let center = UNUserNotificationCenter.current()
        let identifiers = NotificationType.allCases.map { buildIdentifier(for: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// Builds the notification identifier string for a given notification type.
    /// - Parameter type: The notification type.
    /// - Returns: A string identifier used for scheduling and cancelling notifications.
    public func buildIdentifier(for type: NotificationType) -> String {
        return "nullplants." + type.rawValue
    }
    
    /// Refreshes the notification schedule based on stored preferences in UserDefaults.
    /// Reads keys "settings.notificationsEnabled", "settings.notificationHour", "settings.notificationMinute",
    /// "settings.notifyPhoto", and "settings.notifyWater".
    /// Schedules notifications if enabled and at least one notification type is enabled; otherwise cancels all.
    public func refreshScheduleFromStoredPreferences() {
        let notificationsEnabled = userDefaults.bool(forKey: "settings.notificationsEnabled")
        guard notificationsEnabled else {
            cancelAllManagedNotifications()
            return
        }
        
        let hour = userDefaults.integer(forKey: "settings.notificationHour")
        let minute = userDefaults.integer(forKey: "settings.notificationMinute")
        
        let notifyPhoto = userDefaults.bool(forKey: "settings.notifyPhoto")
        let notifyWater = userDefaults.bool(forKey: "settings.notifyWater")
        
        var enabledTypes: [NotificationType] = []
        if notifyPhoto {
            enabledTypes.append(.photoReminder)
        }
        if notifyWater {
            enabledTypes.append(.wateringReminder)
        }
        
        guard !enabledTypes.isEmpty else {
            cancelAllManagedNotifications()
            return
        }
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        scheduleDailyNotifications(at: components, enabledTypes: enabledTypes)
    }
}
