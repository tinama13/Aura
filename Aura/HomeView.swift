import SwiftUI
import UserNotifications
import Combine
import AudioToolbox
import UIKit

struct HomeView: View {
    @State private var isListening = false
    @State private var isPulsing = false
    
    @StateObject private var recognizer = SoundRecognizer()
    
    @State private var showAlert = false
    @State private var currentAlertSound = ""
    
    @State private var eventToNavigateTo: DetectedEvent? = nil
    @State private var pendingEvent: DetectedEvent? = nil
    
    @EnvironmentObject var presetManager: PresetManager
    @EnvironmentObject var historyManager: HistoryManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Text("Aura")
                            .font(.custom("MarkerFelt-Thin", size: 34))
                            .foregroundStyle(.black)
                        Spacer()
                    }
                    .padding(.top, 34)
                    .padding(.horizontal, 26)
                    
                    Text(presetManager.activePreset.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 30)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isListening.toggle()
                        }
                        
                        if isListening {
                            isPulsing = true
                            recognizer.startListening()
                        } else {
                            isPulsing = false
                            recognizer.stopListening()
                        }
                    } label: {
                        ZStack {
                            if isListening {
                                Circle()
                                    .stroke(Color.black.opacity(0.18), lineWidth: 3)
                                    .frame(width: 170, height: 170)
                                    .scaleEffect(isPulsing ? 1.12 : 1.0)
                                    .opacity(isPulsing ? 0.0 : 1.0)
                                    .animation(
                                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                        value: isPulsing
                                    )
                            }
                            
                            Circle()
                                .stroke(
                                    Color.black.opacity(0.85),
                                    style: StrokeStyle(
                                        lineWidth: 4,
                                        lineCap: .round,
                                        dash: isListening ? [4, 9] : []
                                    )
                                )
                                .frame(width: 170, height: 170)
                            
                            Image("EarListeningIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 105, height: 105)
                        }
                        .frame(width: 180, height: 180)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 34)
                    
                    Text(isListening ? "Listening" : "Tap to Start\nListening")
                        .font(.system(size: 25, weight: .bold))
                        .lineSpacing(1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .frame(height: 62)
                        .padding(.top, 24)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.9))
                        .frame(height: 2)
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Recent")
                                .font(.system(size: 22, weight: .bold))
                            
                            Spacer()
                            
                            NavigationLink(destination: FullHistoryView()) {
                                Text("View all")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                            }
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 16)
                        
                        ForEach(historyManager.events.prefix(3)) { event in
                            NavigationLink(destination: EventTimelineView(event: event)) {
                                HStack {
                                    Text(event.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Text(event.timeAgo)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                                .padding(.horizontal, 26)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .opacity(showAlert ? 0.3 : 1.0)
                
                if showAlert {
                    AlertPopupView(
                        soundName: currentAlertSound,
                        onDismiss: { withAnimation { showAlert = false } },
                        onViewDetails: {
                            self.eventToNavigateTo = self.pendingEvent
                            withAnimation { showAlert = false }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationDestination(item: $eventToNavigateTo) { event in
                EventTimelineView(event: event)
            }
        }
        
        .onAppear {
            requestNotificationPermission()
        }
        .onChange(of: recognizer.latestDetection) { oldValue, newValue in
            guard let detection = newValue else { return }
            triggerAlert(for: detection)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in }
    }
    
    private func triggerAlert(for detection: SoundDetection) {
        let displayName = formattedSoundName(detection.name)
        currentAlertSound = displayName
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showAlert = true
        }
        
        let newEvent = historyManager.logEvent(
            name: displayName,
            timestamp: detection.timestamp,
            endedAt: detection.endedAt,
            timeline: detection.timeline,
            audioFileURL: detection.audioFileURL
        )
        self.pendingEvent = newEvent
        
        if isAlarmSound(displayName) {
            triggerAlarmVibration()
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Aura"
        content.body = displayName
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
    
    private func isEnabledInActivePreset(_ detectedSound: String) -> Bool {
        let activeSounds = presetManager.selectedSounds[presetManager.activePresetID] ?? Set(presetManager.activePreset.defaultSounds)
        let normalizedDetection = normalizedSoundName(detectedSound)
        
        return activeSounds.contains { activeSound in
            let normalizedActiveSound = normalizedSoundName(activeSound)
            return normalizedActiveSound == normalizedDetection
                || normalizedActiveSound.contains(normalizedDetection)
                || normalizedDetection.contains(normalizedActiveSound)
        }
    }
    
    private func normalizedSoundName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
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

struct AlertPopupView: View {
    var soundName: String
    var onDismiss: () -> Void
    var onViewDetails: () -> Void
    
    @StateObject private var narrator = EventNarrator()
    
    private var warningText: String {
        "Aura detected \(soundName). Please check your surroundings."
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(Color(red: 0.85, green: 0.28, blue: 0.2))
                    .padding(.top, 20)
                
                Text("Haptic pulse active")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .background(
                RadialGradient(gradient: Gradient(colors: [Color.red.opacity(0.15), Color.clear]), center: .top, startRadius: 10, endRadius: 100)
            )
            
            Divider()
                .padding(.horizontal, 20)
            
            Text("\(soundName) Detected")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 8)
            
            VStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
                
                Button(action: onViewDetails) {
                    Text("View Details")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
                
                Button {
                    narrator.toggleReading(warningText)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        Text(narrator.isSpeaking ? "Stop Reading" : "Read Warning")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.42, green: 0.29, blue: 0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onDisappear {
            narrator.stopReading()
        }
        .frame(width: 320)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    HomeView()
        .environmentObject(SoundManager())
        .environmentObject(PresetManager())
        .environmentObject(HistoryManager())
}
