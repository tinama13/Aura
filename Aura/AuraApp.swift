//
//  AuraApp.swift
//  Aura
//
//  Created by Tina Ma on 7/7/26.
//

import SwiftUI
import Combine
import UserNotifications

extension Notification.Name {
    static let auraOpenDetectedEvent = Notification.Name("auraOpenDetectedEvent")
    static let auraRestartTutorial = Notification.Name("auraRestartTutorial")
    static let auraTutorialOpenTab = Notification.Name("auraTutorialOpenTab")
    static let auraTutorialPresetHeld = Notification.Name("auraTutorialPresetHeld")
    static let auraTutorialAddSoundsDone = Notification.Name("auraTutorialAddSoundsDone")
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "STOP_LISTENING" {
            Task { @MainActor in
                ListeningManager.shared.stopListening()
                completionHandler()
            }
        } else if let eventID = response.notification.request.content.userInfo["eventID"] as? String {
            UserDefaults.standard.set(eventID, forKey: "pendingNotificationEventID")
            NotificationCenter.default.post(
                name: .auraOpenDetectedEvent,
                object: nil,
                userInfo: ["eventID": eventID]
            )
            completionHandler()
        } else {
            completionHandler()
        }
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            OnBoardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

@main
struct AuraApp: App {
    @StateObject private var soundManager = SoundManager()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var listeningManager = ListeningManager.shared
    private let notificationDelegate = NotificationDelegate()
    
    init() {
        ListeningManager.registerNotificationActions()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Aura notification authorization failed: \(error.localizedDescription)")
            }
            if !granted {
                print("Aura notification authorization was not granted.")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(soundManager)
                .environmentObject(presetManager)
                .environmentObject(historyManager)
                .environmentObject(listeningManager)
        }
    }
}
