import SwiftUI
import UserNotifications
import Combine

struct HomeView: View {
    @State private var isPulsing = false
    
    @EnvironmentObject var presetManager: PresetManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var listeningManager: ListeningManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                        AuraHeaderView()
                        
                        Button {
                            NotificationCenter.default.post(name: .auraRestartTutorial, object: nil)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.204, green: 0.678, blue: 0.914))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color(red: 0.90, green: 0.97, blue: 1.0)))
                                .overlay(Circle().stroke(Color(red: 0.204, green: 0.678, blue: 0.914).opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 18)
                    }
                    .padding(.top, 20)
                    
                    Text(presetManager.activePreset.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 30)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            listeningManager.toggleListening()
                            isPulsing = listeningManager.isListening
                        }
                    } label: {
                        ZStack {
                            if listeningManager.isListening {
                                Circle()
                                    .stroke(Color.green.opacity(0.22), lineWidth: 5)
                                    .frame(width: 170, height: 170)
                                    .scaleEffect(isPulsing ? 1.18 : 1.0)
                                    .opacity(isPulsing ? 0.0 : 1.0)
                                    .animation(
                                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                        value: isPulsing
                                    )
                            }
                            
                            Circle()
                                .fill(listeningManager.isListening ? Color.green.opacity(0.12) : Color.clear)
                                .frame(width: 170, height: 170)
                            
                            Circle()
                                .stroke(
                                    listeningManager.isListening ? Color.green : Color.black.opacity(0.85),
                                    style: StrokeStyle(
                                        lineWidth: 4,
                                        lineCap: .round,
                                        dash: listeningManager.isListening ? [4, 9] : []
                                    )
                                )
                                .frame(width: 170, height: 170)
                            
                            Image(systemName: "ear")
                                .font(.system(size: 92, weight: .regular))
                                .foregroundStyle(listeningManager.isListening ? .green : .black)
                        }
                        .frame(width: 180, height: 180)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 34)
                    
                    Text(listeningManager.isListening ? "Listening" : "Tap to Start\nListening")
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
            }
        }
        
        .onAppear {
            requestNotificationPermission()
            listeningManager.resumeListeningIfNeeded()
        }
        .onChange(of: listeningManager.isListening) { oldValue, newValue in
            isPulsing = newValue
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in }
    }
    
    private func isEnabledInActivePreset(_ detectedSound: String) -> Bool {
        let activeSounds = (presetManager.selectedSounds[presetManager.activePresetID] ?? Set(presetManager.activePreset.defaultSounds))
            .union(presetManager.activePreset.defaultSounds)
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
    var onReadWarning: () -> Void
    
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
                    onReadWarning()
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
