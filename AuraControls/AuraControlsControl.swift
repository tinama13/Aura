//
//  AuraControlsControl.swift
//  AuraControls
//

import AppIntents
import SwiftUI
import WidgetKit

private enum AuraControlStorage {
    static let commandNotificationName = "app.tinama.aura.controlCommand"
    static let isListeningKey = "aura.control.isListening"
    static let requestedListeningKey = "aura.control.requestedListening"
    static let listeningRequestIDKey = "aura.control.listeningRequestID"
    static let requestedFavoriteSlotKey = "aura.control.requestedFavoriteSlot"
    static let presetRequestIDKey = "aura.control.presetRequestID"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.app.tinama.aura") ?? .standard
    }

    static var isListening: Bool {
        get { defaults.bool(forKey: isListeningKey) }
        set { defaults.set(newValue, forKey: isListeningKey) }
    }

    static func requestListening(_ isListening: Bool) {
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

struct AuraListeningControl: ControlWidget {
    static let kind: String = "app.tinama.aura.control.listening"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { isListening in
            ControlWidgetToggle(
                "Start Listening",
                isOn: isListening,
                action: ToggleAuraListeningIntent()
            ) { isOn in
                Label(isOn ? "Listening" : "Start Listening", systemImage: isOn ? "ear.badge.waveform" : "ear")
            }
        }
        .displayName("Start Listening")
        .description("Start or stop Aura listening.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            AuraControlStorage.isListening
        }
    }
}

struct AuraPresetOneControl: ControlWidget {
    static let kind: String = "app.tinama.aura.control.preset.one"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SwitchAuraPresetIntent(slot: 0)) {
                Label("Starred 1", systemImage: "1.circle.fill")
            }
        }
        .displayName("Starred Preset 1")
        .description("Switch to your first starred Aura preset.")
    }
}

struct AuraPresetTwoControl: ControlWidget {
    static let kind: String = "app.tinama.aura.control.preset.two"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SwitchAuraPresetIntent(slot: 1)) {
                Label("Starred 2", systemImage: "2.circle.fill")
            }
        }
        .displayName("Starred Preset 2")
        .description("Switch to your second starred Aura preset.")
    }
}

struct AuraPresetThreeControl: ControlWidget {
    static let kind: String = "app.tinama.aura.control.preset.three"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SwitchAuraPresetIntent(slot: 2)) {
                Label("Starred 3", systemImage: "3.circle.fill")
            }
        }
        .displayName("Starred Preset 3")
        .description("Switch to your third starred Aura preset.")
    }
}

struct AuraPresetFourControl: ControlWidget {
    static let kind: String = "app.tinama.aura.control.preset.four"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SwitchAuraPresetIntent(slot: 3)) {
                Label("Starred 4", systemImage: "4.circle.fill")
            }
        }
        .displayName("Starred Preset 4")
        .description("Switch to your fourth starred Aura preset.")
    }
}

struct ToggleAuraListeningIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Aura Listening"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Aura is listening")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        AuraControlStorage.requestListening(value)
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
        AuraControlStorage.requestFavoritePreset(slot: slot)
        return .result()
    }
}
