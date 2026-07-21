import Combine
import AVFoundation
import Foundation
import UIKit
import UserNotifications
import WidgetKit
import SwiftUI

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
    
    private var alertCooldowns: [String: Date] = [:]
    private var globalLastAlert: Date? = nil
    private let recognizer = SoundRecognizer()
    private var cancellables = Set<AnyCancellable>()
    private weak var controlPresetManager: PresetManager?
    private weak var historyManager: HistoryManager?
    private let listeningNotificationIdentifier = "AuraBackgroundListening"
    
    private var hasShownListeningNotification = false
    private var recoveryTask: Task<Void, Never>?
    private var listeningHealthTask: Task<Void, Never>?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var isRequestingMicrophonePermission = false

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
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { _ in
            Task { @MainActor in
                ListeningManager.shared.scheduleListeningRecovery(forceRestart: false)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { _ in
            Task { @MainActor in
                ListeningManager.shared.scheduleListeningRecovery(forceRestart: true)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: recognizer.audioEngineNotificationObject,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ListeningManager.shared.scheduleListeningRecovery(forceRestart: true)
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
        ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
        reloadListeningControl()
        
        if isListening {
            if !recognizer.isActivelyListening {
                resumeListeningIfNeeded(forceRestart: true)
            }
            return
        }
        
        if !canStartRecordingNow() {
            requestMicrophonePermissionAndStartListening()
            return
        }
        
        if recognizer.startListening() {
            isListening = true
            ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
            beginBackgroundListeningTask()
            startListeningHealthMonitor()
            requestNotificationPermissionAndShowListeningNotification()
        } else {
            isListening = false
            ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
        }
    }
    
    func stopListening() {
        guard isListening else {
            ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
            reloadListeningControl()
            hasShownListeningNotification = false
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [listeningNotificationIdentifier])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [listeningNotificationIdentifier])
            return
        }
        isListening = false
        recoveryTask?.cancel()
        recoveryTask = nil
        listeningHealthTask?.cancel()
        listeningHealthTask = nil
        ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
        reloadListeningControl()
        recognizer.stopListening()
        endBackgroundListeningTask()
        hasShownListeningNotification = false
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [listeningNotificationIdentifier])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [listeningNotificationIdentifier])
    }
    
    func refreshListeningNotificationIfNeeded() {
        guard isListening else { return }
        requestNotificationPermissionAndShowListeningNotification()
    }
    
    func prepareForBackgroundListening() {
        guard isListening else { return }
        beginBackgroundListeningTask()

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
                beginBackgroundListeningTask()
                startListeningHealthMonitor()
                requestNotificationPermissionAndShowListeningNotification()
            } else {
                ControlStorage.defaults.set(true, forKey: ControlStorage.isListeningKey)
                reloadListeningControl()
                scheduleListeningRecovery(forceRestart: true, delay: 1.5)
            }
        }
    
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    func syncListeningControlWithCurrentState() {
        ControlStorage.defaults.set(isListening, forKey: ControlStorage.isListeningKey)
        reloadListeningControl()
    }
    
    func logListeningStatus(_ reason: String) {
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
        
        if type == .began {
            scheduleListeningRecovery(forceRestart: false, delay: 1.0)
        } else if type == .ended {
            scheduleListeningRecovery(forceRestart: true)
        }
    }
    
    private func scheduleListeningRecovery(forceRestart: Bool, delay: TimeInterval = 0.35) {
        guard isListening else { return }
        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isListening else { return }
                self.resumeListeningIfNeeded(forceRestart: forceRestart)
            }
        }
    }
    
    private func startListeningHealthMonitor() {
        guard listeningHealthTask == nil else { return }
        listeningHealthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard let self, self.isListening else { return }
                    
                    if !self.recognizer.isActivelyListening {
                        self.sendListeningRecoveryNotification(reason: "audio engine stopped")
                        self.scheduleListeningRecovery(forceRestart: true, delay: 0)
                        return
                    }
                    
                    if let silentStartTime = self.recognizer.secondsSinceListeningStartedWithoutAudio, silentStartTime > 4 {
                        self.sendListeningRecoveryNotification(reason: "microphone input stalled")
                        self.scheduleListeningRecovery(forceRestart: true, delay: 0)
                        return
                    }
                    
                    if let staleTime = self.recognizer.secondsSinceLastAudioBuffer, staleTime > 6 {
                        self.sendListeningRecoveryNotification(reason: "microphone input stalled")
                        self.scheduleListeningRecovery(forceRestart: true, delay: 0)
                    }
                }
            }
        }
    }
    
    func processDetection(_ detection: SoundDetection, presetManager: PresetManager, historyManager: HistoryManager) {
        let displayName = formattedSoundName(detection.name)
        
        if historyManager.containsEvent(id: detection.id) {
            _ = historyManager.logEvent(
                id: detection.id,
                name: displayName,
                timestamp: detection.timestamp,
                endedAt: detection.endedAt,
                timeline: detection.timeline,
                audioFileURL: detection.audioFileURL
            )
            return
        }
        
        guard isEnabled(displayName, in: presetManager) else {
            if let audioFileURL = detection.audioFileURL {
                try? FileManager.default.removeItem(at: audioFileURL)
            }
            return
        }
        
        let now = Date()
        
        if let globalTime = globalLastAlert, now.timeIntervalSince(globalTime) < 5 {
            if let audioFileURL = detection.audioFileURL { try? FileManager.default.removeItem(at: audioFileURL) }
            return
        }
        
        let soundKey = normalizedSoundName(detection.name)
        if let lastAlertTime = alertCooldowns[soundKey], now.timeIntervalSince(lastAlertTime) < 180 {
            if let audioFileURL = detection.audioFileURL { try? FileManager.default.removeItem(at: audioFileURL) }
            return
        }
        
        alertCooldowns[soundKey] = now
        globalLastAlert = now
        
        let newEvent = historyManager.logEvent(
            id: detection.id,
            name: displayName,
            timestamp: detection.timestamp,
            endedAt: detection.endedAt,
            timeline: detection.timeline,
            audioFileURL: detection.audioFileURL
        )
        latestAlertSound = displayName
        latestAcceptedEvent = newEvent
        
        if UIApplication.shared.applicationState != .active {
            requestNotificationPermissionAndSendDetectionNotification(event: newEvent)
        }
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
        guard UIApplication.shared.applicationState != .active else { return }
        guard !hasShownListeningNotification else { return }
        hasShownListeningNotification = true
        
        let content = UNMutableNotificationContent()
        content.title = "Aura is listening"
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
        UNUserNotificationCenter.current().requestAuthorization(options: notificationAuthorizationOptions) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                ListeningManager.shared.showBackgroundListeningNotification()
            }
        }
    }
    
    private func sendDetectionNotification(event: DetectedEvent) {
        let content = UNMutableNotificationContent()
        content.title = "\(event.name) detected"
        content.body = "Aura heard \(event.name). Check your surroundings."
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "eventID": event.id.uuidString
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendListeningRecoveryNotification(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Aura restarted listening"
        content.body = "Recovered after \(reason)."
        content.sound = nil
        
        let request = UNNotificationRequest(
            identifier: "AuraListeningRecovery-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func requestNotificationPermissionAndSendDetectionNotification(event: DetectedEvent) {
        UNUserNotificationCenter.current().requestAuthorization(options: notificationAuthorizationOptions) { granted, _ in
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
    
    private var notificationAuthorizationOptions: UNAuthorizationOptions {
        [.alert, .sound, .badge]
    }
    
    private func canStartRecordingNow() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }
    
    private func requestMicrophonePermissionAndStartListening() {
        guard !isRequestingMicrophonePermission else { return }
        isRequestingMicrophonePermission = true
        
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                self.isRequestingMicrophonePermission = false
                if granted {
                    self.startListening()
                } else {
                    self.isListening = false
                    ControlStorage.defaults.set(false, forKey: ControlStorage.isListeningKey)
                    self.reloadListeningControl()
                }
            }
        }
    }
    
    private func beginBackgroundListeningTask() {
        guard backgroundTaskIdentifier == .invalid else { return }
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AuraListening") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundListeningTask()
            }
        }
    }
    
    private func endBackgroundListeningTask() {
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
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
