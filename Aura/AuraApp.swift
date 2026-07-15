//
//  AuraApp.swift
//  Aura
//
//  Created by Tina Ma on 7/7/26.
//

import SwiftUI
import Combine
@main
struct AuraApp: App {
    @StateObject private var soundManager = SoundManager()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var historyManager = HistoryManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(soundManager)
                .environmentObject(presetManager)
                .environmentObject(historyManager)
        }
    }
}
