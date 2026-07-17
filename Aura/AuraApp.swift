//
//  AuraApp.swift
//  Aura
//
//  Created by Tina Ma on 7/7/26.
//

import SwiftUI
import Combine
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct AuraApp: App {
    @StateObject private var soundManager = SoundManager()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var historyManager = HistoryManager()
    private let notificationDelegate = NotificationDelegate()
    
    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(soundManager)
                .environmentObject(presetManager)
                .environmentObject(historyManager)
        }
    }
}
