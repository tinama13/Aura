//
//  ContentView.swift
//  Aura
//
//  Created by Tina Ma on 7/7/26.
//

import SwiftUI
import AudioToolbox
import UIKit

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
    @State private var showAlert = false
    @State private var currentAlertSound = ""
    @State private var pendingEvent: DetectedEvent?
    @State private var eventToOpen: DetectedEvent?
    @State private var tutorialStep: AuraTutorialStep?

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
                    .allowsHitTesting(tutorialStep == nil)
                
                if showAlert {
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                        
                        AlertPopupView(
                            soundName: currentAlertSound,
                            onDismiss: { withAnimation { showAlert = false } },
                            onViewDetails: {
                                eventToOpen = pendingEvent
                                withAnimation { showAlert = false }
                            },
                            onReadWarning: {}
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(2)
                }
                
                if let tutorialStep {
                    AuraTutorialOverlay(
                        step: tutorialStep,
                        onNext: advanceTutorial,
                        onSkip: finishTutorial
                    )
                    .zIndex(3)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationDestination(item: $eventToOpen) { event in
                EventTimelineView(event: event)
            }
        }
        .onChange(of: listeningManager.latestAcceptedEvent) { oldValue, newValue in
            guard let event = newValue else { return }
            currentAlertSound = listeningManager.latestAlertSound
            pendingEvent = event
            if isAlarmSound(event.name) {
                triggerAlarmVibration()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAlert = true
            }
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .active {
                listeningManager.applyPendingControlRequests(presetManager: presetManager)
                listeningManager.resumeListeningIfNeeded()
                openPendingNotificationEventIfNeeded()
            } else if newValue == .background {
                listeningManager.refreshListeningNotificationIfNeeded()
            }
        }
        .onChange(of: current_tab) { oldValue, newValue in
            if newValue == .home {
                listeningManager.resumeListeningIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraOpenDetectedEvent)) { notification in
            openNotificationEvent(notification.userInfo?["eventID"] as? String)
        }
        .onReceive(NotificationCenter.default.publisher(for: .auraRestartTutorial)) { _ in
            startTutorial()
        }
        .onAppear {
            listeningManager.configureControlRequests(presetManager: presetManager, historyManager: historyManager)
            listeningManager.applyPendingControlRequests(presetManager: presetManager)
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
        showAlert = false
        eventToOpen = event
    }
    
    private func isAlarmSound(_ soundName: String) -> Bool {
        let normalizedName = soundName.lowercased()
        return normalizedName.contains("alarm")
            || normalizedName.contains("siren")
            || normalizedName.contains("smoke")
            || normalizedName.contains("emergency")
    }
    
    private func triggerAlarmVibration() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private func startTutorial() {
        current_tab = .home
        withAnimation(.easeInOut(duration: 0.2)) {
            tutorialStep = .startListening
        }
    }
    
    private func advanceTutorial() {
        guard let tutorialStep else { return }
        if let nextStep = tutorialStep.next {
            current_tab = nextStep.tab
            withAnimation(.easeInOut(duration: 0.2)) {
                self.tutorialStep = nextStep
            }
        } else {
            finishTutorial()
        }
    }
    
    private func finishTutorial() {
        hasCompletedTutorial = true
        withAnimation(.easeInOut(duration: 0.2)) {
            tutorialStep = nil
        }
    }
}

extension Notification.Name {
    static let auraRestartTutorial = Notification.Name("auraRestartTutorial")
}

private enum AuraTutorialStep: Int, CaseIterable {
    case startListening
    case presets
    case presetSounds
    case changeSounds
    case newPreset
    case allSounds
    case addSound
    
    var tab: Tab {
        switch self {
        case .startListening:
            return .home
        case .presets, .presetSounds, .changeSounds, .newPreset:
            return .presets
        case .allSounds, .addSound:
            return .sounds
        }
    }
    
    var title: String {
        switch self {
        case .startListening:
            return "Start Listening"
        case .presets:
            return "Use Presets"
        case .presetSounds:
            return "Preset Categories"
        case .changeSounds:
            return "Change Noises"
        case .newPreset:
            return "Make New Presets"
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
        case .presets:
            return "Presets are categories for different situations. Pick one to decide which sounds Aura should listen for."
        case .presetSounds:
            return "Each preset has a sound list. Checked sounds are active for that preset."
        case .changeSounds:
            return "Tap a sound to check or uncheck it. Built-in preset sounds may stay locked so the preset keeps its core purpose."
        case .newPreset:
            return "Use Make New Preset to create your own category with the symbol and sounds you want."
        case .allSounds:
            return "All Sounds shows every sound Aura knows about. Tap any sound to view or edit its details."
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
            return CGRect(x: (size.width - 210) / 2, y: 210, width: 210, height: 210)
        case .presets:
            return CGRect(x: 22, y: 105, width: size.width - 44, height: 250)
        case .presetSounds, .changeSounds:
            return CGRect(x: 20, y: 360, width: size.width - 40, height: min(250, size.height - 470))
        case .newPreset:
            return CGRect(x: (size.width - 230) / 2, y: size.height - 165, width: 230, height: 62)
        case .allSounds:
            return CGRect(x: 18, y: 116, width: size.width - 58, height: min(430, size.height - 220))
        case .addSound:
            return CGRect(x: size.width - 74, y: 82, width: 54, height: 54)
        }
    }
}

private struct AuraTutorialOverlay: View {
    let step: AuraTutorialStep
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                
                highlightBox(in: geometry.size)
                
                VStack {
                    if step == .addSound {
                        tutorialBubble
                            .padding(.top, 148)
                        Spacer()
                    } else if step == .startListening || step == .presetSounds || step == .changeSounds {
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
        let frame = step.highlightFrame(in: size)
        
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
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(SoundManager())
        .environmentObject(PresetManager())
        .environmentObject(HistoryManager())
        .environmentObject(ListeningManager.shared)
}
