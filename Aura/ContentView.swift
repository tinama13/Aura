//
//  ContentView.swift
//  Aura
//
//  Created by Tina Ma on 7/7/26.
//

import SwiftUI
import AudioToolbox
import UIKit
import UserNotifications

enum Tab: String, CaseIterable {
    case home = "Home"
    case presets = "Presets"
    case sounds = "Sounds"
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .presets: return "slider.horizontal.3"
        case .sounds: return "speaker"
        }
    }
}

struct ContentView: View {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var presetManager: PresetManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var listeningManager: ListeningManager
    @State private var current_tab: Tab = .home
    @State private var tutorialStep: AuraTutorialStep?
    @State private var eventToOpen: DetectedEvent?
    
    @AppStorage("auraTutorialStepName") private var tutorialStepName = ""
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    switch current_tab {
                    case .home:
                        HomeView()
                    case .presets:
                        PresetsView()
                    case .sounds:
                        SoundsView()
                    }
                }
                .padding(.bottom, 90)
                
                NavBar(current_tab: $current_tab)
                    .allowsHitTesting(tutorialStep == nil || tutorialStep?.allowsTabBarInteraction == true)
            }
            .overlayPreferenceValue(AuraTutorialHighlightPreferenceKey.self) { anchors in
                GeometryReader { geometry in
                    if let tutorialStep {
                        AuraTutorialOverlay(
                            step: tutorialStep,
                            currentTab: current_tab,
                            highlightFrame: highlightFrame(for: tutorialStep, anchors: anchors, geometry: geometry),
                            onNext: advanceTutorial,
                            onSkip: finishTutorial
                        )
                        .allowsHitTesting(!tutorialStep.requiresUserAction)
                        .zIndex(3)
                    }
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationDestination(item: $eventToOpen) { event in
                EventTimelineView(event: event)
            }
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                listeningManager.applyPendingControlRequests(presetManager: presetManager)
                listeningManager.resumeListeningIfNeeded(forceRestart: true)
                listeningManager.syncListeningControlWithCurrentState()
                listeningManager.logListeningStatus("scene active")
                openPendingNotificationEventIfNeeded()
            } else if newValue == .inactive {
                print("Aura scene inactive. preparing background listening=\(listeningManager.isListening)")
                listeningManager.prepareForBackgroundListening()
                listeningManager.logListeningStatus("scene inactive")
            } else if newValue == .background {
                print("Aura entered background. listening=\(listeningManager.isListening)")
                listeningManager.resumeListeningIfNeeded()
                listeningManager.refreshListeningNotificationIfNeeded()
                listeningManager.logListeningStatus("scene background")
            }
        }
        .onChange(of: current_tab) { newValue in
            if newValue == .home {
                listeningManager.resumeListeningIfNeeded()
            }
            if tutorialStep == .switchToPresets, newValue == .presets {
                advanceTutorial()
            } else if tutorialStep == .switchToSounds, newValue == .sounds {
                advanceTutorial()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraOpenDetectedEvent)) { notification in
            openNotificationEvent(notification.userInfo?["eventID"] as? String)
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraRestartTutorial)) { _ in
            startTutorial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraTutorialOpenTab)) { notification in
            guard let tab = notification.object as? Tab else { return }
            current_tab = tab
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraTutorialPresetHeld)) { _ in
            if tutorialStep == .holdPreset {
                advanceTutorial()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraTutorialAddSoundsDone)) { _ in
            if tutorialStep == .addPresetDone {
                advanceTutorial()
            }
        }
        .onAppear {
            listeningManager.configureControlRequests(presetManager: presetManager, historyManager: historyManager)
            listeningManager.applyPendingControlRequests(presetManager: presetManager)
            listeningManager.syncListeningControlWithCurrentState()
            openPendingNotificationEventIfNeeded()
            if !hasCompletedTutorial {
                startTutorial()
            }
        }
        .task {
            await syncControlCenterRequestsWhileRunning()
        }
    }
    
    private func syncControlCenterRequestsWhileRunning() async {
        while !Task.isCancelled {
            listeningManager.applyPendingControlRequests(presetManager: presetManager)
            listeningManager.resumeListeningIfNeeded()
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
    
    private func openPendingNotificationEventIfNeeded() {
        let eventID = UserDefaults.standard.string(forKey: "pendingNotificationEventID")
        openNotificationEvent(eventID)
    }
    
    private func openNotificationEvent(_ eventID: String?) {
        guard let eventID,
              let eventUUID = UUID(uuidString: eventID),
              let event = historyManager.events.first(where: { $0.id == eventUUID }) else {
            return
        }
        UserDefaults.standard.removeObject(forKey: "pendingNotificationEventID")
        current_tab = .home
        eventToOpen = event
    }
    
    private func startTutorial() {
        current_tab = .home
        withAnimation(.easeInOut(duration: 0.2)) {
            tutorialStep = .startListening
        }
        tutorialStepName = AuraTutorialStep.startListening.storageName
    }
    
    private func advanceTutorial() {
        guard let tutorialStep else { return }
        if let nextStep = tutorialStep.next {
            if nextStep.shouldAutoSwitchTab {
                current_tab = nextStep.tab
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.tutorialStep = nextStep
            }
            tutorialStepName = nextStep.storageName
        } else {
            finishTutorial()
        }
    }
    
    private func finishTutorial() {
        hasCompletedTutorial = true
        withAnimation(.easeInOut(duration: 0.2)) {
            tutorialStep = nil
        }
        tutorialStepName = ""
        requestNotificationPermission()
    }
    
    private func highlightFrame(
        for step: AuraTutorialStep,
        anchors: [AuraTutorialHighlightTarget: Anchor<CGRect>],
        geometry: GeometryProxy
    ) -> CGRect? {
        guard let target = step.highlightTarget,
              let anchor = anchors[target] else {
            return nil
        }
        
        return geometry[anchor].insetBy(dx: -6, dy: -6)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

enum AuraTutorialHighlightTarget: Hashable {
    case startListening
    case recentList
    case presetsTab
    case soundsTab
    case newPresetButton
}

struct AuraTutorialHighlightPreferenceKey: PreferenceKey {
    static var defaultValue: [AuraTutorialHighlightTarget: Anchor<CGRect>] = [:]
    
    static func reduce(
        value: inout [AuraTutorialHighlightTarget: Anchor<CGRect>],
        nextValue: () -> [AuraTutorialHighlightTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private enum AuraTutorialStep: Int, CaseIterable {
    case startListening
    case recentList
    case switchToPresets
    case presets
    case holdPreset
    case addPresetDone
    case newPreset
    case switchToSounds
    case allSounds
    case addSound
    
    var tab: Tab {
        switch self {
        case .startListening, .recentList:
            return .home
        case .switchToPresets, .presets, .holdPreset, .addPresetDone, .newPreset:
            return .presets
        case .switchToSounds, .allSounds, .addSound:
            return .sounds
        }
    }
    
    var shouldAutoSwitchTab: Bool {
        switch self {
        case .switchToPresets, .switchToSounds:
            return false
        default:
            return true
        }
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .switchToPresets, .holdPreset, .addPresetDone, .switchToSounds:
            return true
        default:
            return false
        }
    }
    
    var allowsTabBarInteraction: Bool {
        switch self {
        case .switchToPresets, .switchToSounds:
            return true
        default:
            return false
        }
    }
    
    var title: String {
        switch self {
        case .startListening:
            return "Start Listening"
        case .recentList:
            return "Recent Sounds"
        case .switchToPresets:
            return "Go to Presets"
        case .presets:
            return "Use Presets"
        case .holdPreset:
            return "Hold to Edit"
        case .addPresetDone:
            return "Add Sounds"
        case .newPreset:
            return "Make New Presets"
        case .switchToSounds:
            return "Go to Sounds"
        case .allSounds:
            return "All Sounds"
        case .addSound:
            return "Add New Noises"
        }
    }
    
    var message: String {
        switch self {
        case .startListening:
            return "Press the ear button to start listening to sounds around you. When it turns green, Aura is listening."
        case .recentList:
            return "Recently heard noises show up here after Aura detects and records them."
        case .switchToPresets:
            return "Tap the Presets tab at the bottom to choose what Aura listens for."
        case .presets:
            return "Presets are categories for different situations. Pick one to decide which sounds Aura should listen for."
        case .holdPreset:
            return "Hold down the selected preset card to open the Add Sounds page."
        case .addPresetDone:
            return "Tap Done to continue."
        case .newPreset:
            return "Use Make New Preset to create your own category with the symbol and sounds you want."
        case .switchToSounds:
            return "Tap the Sounds tab at the bottom to see every sound Aura knows."
        case .allSounds:
            return "All Sounds lists every sound Aura knows about. Tap any sound to view or edit its details."
        case .addSound:
            return "Use the plus button in the top right to add a new noise after recording examples of it."
        }
    }
    
    var next: AuraTutorialStep? {
        AuraTutorialStep(rawValue: rawValue + 1)
    }
    
    var isLast: Bool {
        next == nil
    }
    
    func highlightFrame(in size: CGSize) -> CGRect {
        switch self {
        case .startListening:
            return CGRect(x: (size.width - 232) / 2, y: 188, width: 232, height: 278)
        case .recentList:
            let top: CGFloat = size.height - 340
            let height: CGFloat = 245
            return CGRect(x: 20, y: top, width: size.width - 40, height: height)
        case .switchToPresets:
            return navHighlightFrame(for: .presets, in: size)
        case .presets:
            return CGRect(x: 22, y: 112, width: size.width - 44, height: 228)
        case .holdPreset:
            let cardWidth = (size.width - 64) / 2
            return CGRect(x: 22, y: 112, width: cardWidth + 8, height: 112)
        case .addPresetDone:
            return .zero
        case .newPreset:
            return CGRect(x: (size.width - 208) / 2, y: size.height - 181, width: 208, height: 57)
        case .switchToSounds:
            return navHighlightFrame(for: .sounds, in: size)
        case .allSounds:
            return .zero
        case .addSound:
            return CGRect(x: size.width - 66, y: 90, width: 52, height: 52)
        }
    }
    
    var highlightTarget: AuraTutorialHighlightTarget? {
        switch self {
        case .startListening:
            return .startListening
        case .switchToPresets:
            return .presetsTab
        case .switchToSounds:
            return .soundsTab
        case .newPreset:
            return .newPresetButton
        default:
            return nil
        }
    }
    
    var storageName: String {
        switch self {
        case .startListening: return "startListening"
        case .recentList: return "recentList"
        case .switchToPresets: return "switchToPresets"
        case .presets: return "presets"
        case .holdPreset: return "holdPreset"
        case .addPresetDone: return "addPresetDone"
        case .newPreset: return "newPreset"
        case .switchToSounds: return "switchToSounds"
        case .allSounds: return "allSounds"
        case .addSound: return "addSound"
        }
    }
    
    private func navHighlightFrame(for tab: Tab, in size: CGSize) -> CGRect {
        let tabWidth = size.width / CGFloat(Tab.allCases.count)
        let index = CGFloat(Tab.allCases.firstIndex(of: tab) ?? 0)
        return CGRect(x: (tabWidth * index) + (tabWidth - 70) / 2, y: size.height - 91, width: 70, height: 46)
    }
}

private struct AuraTutorialOverlay: View {
    let step: AuraTutorialStep
    let currentTab: Tab
    let highlightFrame: CGRect?
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                
                if step != .allSounds && step != .addPresetDone {
                    highlightBox(in: geometry.size)
                }
                
                VStack {
                    if step == .addPresetDone {
                        EmptyView()
                    } else if step == .recentList {
                        tutorialBubble
                            .padding(.top, 118)
                        Spacer()
                    } else if step == .addSound {
                        tutorialBubble
                            .padding(.top, 148)
                        Spacer()
                    } else if step == .startListening || step == .switchToPresets || step == .switchToSounds {
                        Spacer()
                        tutorialBubble
                            .padding(.bottom, 156)
                    } else {
                        Spacer()
                        tutorialBubble
                        Spacer()
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }
    
    private func highlightBox(in size: CGSize) -> some View {
        let frame = highlightFrame ?? step.highlightFrame(in: size)
        
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                Color(red: 0.58, green: 0.86, blue: 1.0),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [9, 7])
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .shadow(color: Color(red: 0.204, green: 0.678, blue: 0.914).opacity(0.7), radius: 10)
    }
    
    private var tutorialBubble: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.46, blue: 0.68))
                    
                    Text(step.message)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.44, blue: 0.62))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.46, blue: 0.68))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(red: 0.86, green: 0.96, blue: 1.0)))
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                Text("\(step.rawValue + 1) of \(AuraTutorialStep.allCases.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.gray)
                
                Spacer()
                
                if step.requiresUserAction {
                    Text(userActionPrompt)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.204, green: 0.678, blue: 0.914))
                } else {
                    Button(action: onNext) {
                        HStack(spacing: 8) {
                            Text(step.isLast ? "Done" : "Next")
                            Image(systemName: step.isLast ? "checkmark" : "arrow.right")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color(red: 0.204, green: 0.678, blue: 0.914))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    }
    
    private var userActionPrompt: String {
        switch step {
        case .switchToPresets:
            return "Tap Presets to continue"
        case .switchToSounds:
            return "Tap Sounds to continue"
        case .holdPreset:
            return "Hold the preset to continue"
        case .addPresetDone:
            return "Tap Done to continue"
        default:
            return ""
        }
    }
}
