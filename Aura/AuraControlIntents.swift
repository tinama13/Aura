import AppIntents
import Foundation

private enum AuraControlIntentStorage {
    static let commandNotificationName = "app.tinama.aura.controlCommand"
    static let isListeningKey = "aura.control.isListening"
    static let requestedListeningKey = "aura.control.requestedListening"
    static let listeningRequestIDKey = "aura.control.listeningRequestID"
    static let requestedFavoriteSlotKey = "aura.control.requestedFavoriteSlot"
    static let presetRequestIDKey = "aura.control.presetRequestID"
    
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
    
    static func requestFavoritePreset(slot: Int) {
        defaults.set(slot, forKey: requestedFavoriteSlotKey)
        defaults.set(UUID().uuidString, forKey: presetRequestIDKey)
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
            if value {
                ListeningManager.shared.startListening()
            } else {
                ListeningManager.shared.stopListening()
            }
        }
        await MainActor.run {
            AuraControlIntentStorage.requestListening(value)
        }
        return .result()
    }
}

struct SwitchAuraPresetIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Switch Aura Preset"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Favorite Preset Slot")
    var slot: Int
    
    init() {}
    
    init(slot: Int) {
        self.slot = slot
    }
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AuraControlIntentStorage.requestFavoritePreset(slot: slot)
        }
        return .result()
    }
}
