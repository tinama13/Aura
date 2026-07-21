import AppIntents
import Foundation

private enum AuraControlIntentStorage {
    static let commandNotificationName = "app.tinama.aura.controlCommand"
    static let isListeningKey = "aura.control.isListening"
    static let requestedListeningKey = "aura.control.requestedListening"
    static let listeningRequestIDKey = "aura.control.listeningRequestID"
    
    static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.app.tinama.aura") ?? .standard
    }
    
    static func requestListening(_ isListening: Bool) {
        defaults.set(isListening, forKey: isListeningKey)
        defaults.set(isListening, forKey: requestedListeningKey)
        defaults.set(UUID().uuidString, forKey: listeningRequestIDKey)
        defaults.synchronize()
        postCommandNotification()
    }
    
    private static func postCommandNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(commandNotificationName as CFString),
            nil,
            nil,
            true
        )
    }
}

struct ToggleAuraListeningIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Aura Listening"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Aura is listening")
    var value: Bool
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AuraControlIntentStorage.requestListening(value)
        }
        
        return .result()
    }
}
