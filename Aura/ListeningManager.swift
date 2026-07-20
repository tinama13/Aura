import Combine
import AVFoundation
import Foundation
import UserNotifications
import WidgetKit

@MainActor
final class ListeningManager: ObservableObject {
    static let shared = ListeningManager()
    
    private enum ControlStorage {
        static let commandNotificationName = "app.tinama.aura.controlCommand"
        static let isListeningKey = "aura.control.isListening"
        static let requestedListeningKey = "aura.control.requestedListening"
        static let listeningRequestIDKey = "aura.control.listeningRequestID"
        static let handledListeningRequestIDKey = "aura.control.handledListeningRequestID"
        static let requestedFavoriteSlotKey = "aura.control.requestedFavoriteSlot"
        static let presetRequestIDKey = "aura.control.presetRequestID"
        static let handledPresetRequestIDKey = "aura.control.handledPresetRequestID"
        
        static var defaults: UserDefaults {
            UserDefaults(suiteName: "group.app.tinama.aura") ?? .standard
        }
    }

    @Published private(set) var isListening = false
    @Published private(set) var latestDetection: SoundDetection?
    @Published private(set) var latestAcceptedEvent: DetectedEvent?
    @Published private(set) var latestAlertSound = ""

    private let recognizer = SoundRecognizer()
    private var cancellables = Set<AnyCancellable>()
    private weak var controlPresetManager: PresetManager?
    private weak var historyManager: HistoryManager?
    private let listeningNotificationIdentifier = "AuraBackgroundListening"

    private init() {
        recognizer.$latestDetection
            .receive(on: DispatchQueue.main)
            .assign(to: &$latestDetection)
        
        recognizer.$latestDetection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detection in
                guard let self,
                      let detection,
                      let presetManager = self.controlPresetManager,
                      let historyManager = self.historyManager else {
                    return
                }
                self.processDetection(detection, presetManager: presetManager, historyManager: historyManager)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                ListeningManager.shared.handleAudioSessionInterruption(typeValue: typeValue)
            }
        }
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let manager = Unmanaged<ListeningManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.applyPendingControlRequestsFromNotification()
                }
            },
            ControlStorage.commandNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    func startListening() {
        if isListening {
            ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
            return
        }
        
        if recognizer.startListening() {
            isListening = true
            ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
            requestNotificationPermissionAndShowListeningNotification()
        } else {
            isListening = false
            ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
        reloadListeningControl()
        recognizer.stopListening()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [listeningNotificationIdentifier])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [listeningNotificationIdentifier])
    }
    
    func refreshListeningNotificationIfNeeded() {
        guard isListening else { return }
        requestNotificationPermissionAndShowListeningNotification()
    }
    
    func resumeListeningIfNeeded(forceRestart: Bool = false) {
        guard isListening else { return }
        
        if forceRestart {
            recognizer.stopListening()
        } else if recognizer.isActivelyListening {
            return
        }
        
        if recognizer.startListening() {
            ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
            requestNotificationPermissionAndShowListeningNotification()
        } else {
            isListening = false
            ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
        }
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    func configureControlRequests(presetManager: PresetManager, historyManager: HistoryManager? = nil) {
        controlPresetManager = presetManager
        if let historyManager {
            self.historyManager = historyManager
        }
    }
    
    func applyPendingControlRequests(presetManager: PresetManager) {
        controlPresetManager = presetManager
        let defaults = ControlStorage.defaults
        
        let listeningRequestID = defaults.string(forKey: ControlStorage.listeningRequestIDKey)
        let handledListeningRequestID = defaults.string(forKey: ControlStorage.handledListeningRequestIDKey)
        if let listeningRequestID, listeningRequestID != handledListeningRequestID {
            let shouldListen = defaults.bool(forKey: ControlStorage.requestedListeningKey)
            if shouldListen {
                startListening()
            } else {
                stopListening()
            }
            defaults.set(listeningRequestID, forKey: ControlStorage.handledListeningRequestIDKey)
        }
        
        let presetRequestID = defaults.string(forKey: ControlStorage.presetRequestIDKey)
        let handledPresetRequestID = defaults.string(forKey: ControlStorage.handledPresetRequestIDKey)
        if let presetRequestID, presetRequestID != handledPresetRequestID {
            let slot = defaults.integer(forKey: ControlStorage.requestedFavoriteSlotKey)
            presetManager.activateFavoritePreset(at: slot)
            defaults.set(presetRequestID, forKey: ControlStorage.handledPresetRequestIDKey)
        }
    }
    
    private func applyPendingControlRequestsFromNotification() {
        guard let controlPresetManager else { return }
        applyPendingControlRequests(presetManager: controlPresetManager)
    }
    
    private func handleAudioSessionInterruption(typeValue: UInt?) {
        guard isListening,
              let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .ended {
            recognizer.stopListening()
            if recognizer.startListening() {
                ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
                refreshListeningNotificationIfNeeded()
            } else {
                isListening = false
                ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
            }
        }
    }
    
    func processDetection(_ detection: SoundDetection, presetManager: PresetManager, historyManager: HistoryManager) {
        let displayName = formattedSoundName(detection.name)
        guard isEnabled(displayName, in: presetManager) else {
            if let audioFileURL = detection.audioFileURL {
                try? FileManager.default.removeItem(at: audioFileURL)
            }
            return
        }
        
        let isNewEvent = !historyManager.containsEvent(id: detection.id)
        let newEvent = historyManager.logEvent(
            id: detection.id,
            name: displayName,
            timestamp: detection.timestamp,
            endedAt: detection.endedAt,
            timeline: detection.timeline,
            audioFileURL: detection.audioFileURL
        )
        guard isNewEvent else { return }
        latestAlertSound = displayName
        latestAcceptedEvent = newEvent
        requestNotificationPermissionAndSendDetectionNotification(event: newEvent)
    }

    static func registerNotificationActions() {
        let stopAction = UNNotificationAction(
            identifier: "STOP_LISTENING",
            title: "Stop Listening",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "LISTENING_STATUS",
            actions: [stopAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func showBackgroundListeningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Aura is now listening"
        content.body = ""
        content.sound = nil
        content.categoryIdentifier = "LISTENING_STATUS"

        let request = UNNotificationRequest(
            identifier: listeningNotificationIdentifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func requestNotificationPermissionAndShowListeningNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Failed to request listening notification permission: \(error.localizedDescription)")
            }
            guard granted else { return }
            Task { @MainActor in
                ListeningManager.shared.showBackgroundListeningNotification()
            }
        }
    }
    
    private func sendDetectionNotification(event: DetectedEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Warning"
        content.body = "\(event.name) detected"
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "eventID": event.id.uuidString
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func requestNotificationPermissionAndSendDetectionNotification(event: DetectedEvent) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Failed to request detection notification permission: \(error.localizedDescription)")
            }
            guard granted else { return }
            Task { @MainActor in
                ListeningManager.shared.sendDetectionNotification(event: event)
            }
        }
    }
    
    private func reloadListeningControl() {
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: "app.tinama.aura.control.listening")
        }
    }
    
    private func isEnabled(_ detectedSound: String, in presetManager: PresetManager) -> Bool {
        let activeSounds = (presetManager.selectedSounds[presetManager.activePresetID] ?? Set(presetManager.activePreset.defaultSounds))
            .union(presetManager.activePreset.defaultSounds)
        let normalizedDetection = normalizedSoundName(detectedSound)
        let detectionKeywords = soundKeywords(for: detectedSound)
        
        return activeSounds.contains { activeSound in
            let normalizedActiveSound = normalizedSoundName(activeSound)
            let activeKeywords = soundKeywords(for: activeSound)
            return normalizedActiveSound == normalizedDetection
                || normalizedActiveSound.contains(normalizedDetection)
                || normalizedDetection.contains(normalizedActiveSound)
                || !detectionKeywords.isDisjoint(with: activeKeywords)
        }
    }
    
    private func normalizedSoundName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
    
    private func soundKeywords(for name: String) -> Set<String> {
        let normalizedName = name
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        var keywords = Set(
            normalizedName
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 }
                .map(singularized)
        )
        
        let aliasGroups: [[String]] = [
            ["alarm", "siren", "emergency", "smoke", "security"],
            ["car", "horn", "vehicle", "traffic"],
            ["dog", "bark"],
            ["baby", "cry"],
            ["glass", "break"],
            ["door", "doorbell", "knock"],
            ["phone", "ring"],
            ["train", "crossing"],
            ["bike", "bell"],
            ["shout", "voice", "people", "crowd"],
            ["timer", "beep", "kitchen", "appliance"],
            ["motorcycle", "scooter"]
        ]
        
        for group in aliasGroups where !keywords.isDisjoint(with: group) {
            keywords.formUnion(group)
        }
        
        return keywords
    }
    
    private func singularized(_ word: String) -> String {
        if word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if word.hasSuffix("ing"), word.count > 5 {
            return String(word.dropLast(3))
        }
        if word.hasSuffix("s"), word.count > 3 {
            return String(word.dropLast())
        }
        return word
    }
    
    private func formattedSoundName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
