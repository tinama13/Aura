//
//  EventTimelineView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI
import AVFoundation
import Combine

struct EventTimelineView: View {
    let event: DetectedEvent
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var audioPlayer = EventAudioPlayer()
    @StateObject private var narrator = EventNarrator()
    
    private var eventSummaryText: String {
        let contextLabels = event.timeline
            .filter { !$0.isSilence }
            .map(\.label)
            .reduce(into: [String]()) { labels, label in
                if labels.last != label {
                    labels.append(label)
                }
            }
        
        let opening = contextLabels.first ?? "\(event.name) was detected"
        var summary = "Aura heard \(opening.lowercased())."
        
        if let durationText = event.durationText, let silenceText = event.silenceText {
            summary += " \(durationText), and \(silenceText.lowercased())."
        } else if let durationText = event.durationText {
            summary += " \(durationText)."
        }
        
        let extraContext = contextLabels.dropFirst().prefix(2)
        if !extraContext.isEmpty {
            summary += " During the recording, it also sounded like "
            summary += extraContext.map { $0.lowercased() }.joined(separator: ", then ")
            summary += "."
        }
        
        return summary
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Event Summary")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            VStack(spacing: 12) {
                Text(event.name)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(event.timestamp, style: .date)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
                
                Button {
                    audioPlayer.togglePlayback(url: event.audioFileURL)
                } label: {
                    HStack {
                        Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                        Text(audioPlayer.isPlaying ? "Stop Recording" : "Play Detection Recording")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color(red: 0.204, green: 0.678, blue: 0.914).opacity(0.15))
                    .clipShape(Capsule())
                }
                .padding(.top, 14)
                .disabled(event.audioFileURL == nil)
                .opacity(event.audioFileURL == nil ? 0.4 : 1.0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
            
            ScrollView {
                Text(eventSummaryText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
            }
            
            Spacer(minLength: 16)
            
            Button {
                narrator.toggleReading(eventSummaryText)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: narrator.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    Text(narrator.isSpeaking ? "Stop Reading" : "Read Summary")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color(red: 0.42, green: 0.29, blue: 0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            narrator.stopReading()
            audioPlayer.stopPlayback()
        }
    }
}

class EventAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    
    func togglePlayback(url: URL?) {
        guard let url = url else { return }
        
        if isPlaying {
            stopPlayback()
        } else {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Failed to play audio: \(error.localizedDescription)")
            }
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

class EventNarrator: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var readTimer: Timer?
    @Published var isSpeaking = false
    
    func toggleReading(_ text: String) {
        if isSpeaking {
            stopReading()
        } else {
            read(text)
        }
    }
    
    func stopReading() {
        readTimer?.invalidate()
        readTimer = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    private func read(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
        
        readTimer?.invalidate()
        let estimatedDuration = max(2.0, Double(text.split(separator: " ").count) * 0.38)
        readTimer = Timer.scheduledTimer(withTimeInterval: estimatedDuration, repeats: false) { [weak self] _ in
            self?.isSpeaking = false
        }
    }
}

#Preview {
    let now = Date()
    let mockEvent = DetectedEvent(
        name: "Glass Breaking",
        timestamp: now,
        endedAt: now.addingTimeInterval(12),
        timeline: [
            TimelineNode(exactTime: now, label: "Glass breaking detected"),
            TimelineNode(exactTime: now.addingTimeInterval(5), label: "Glass Breaking started quieting down"),
            TimelineNode(exactTime: now.addingTimeInterval(12), label: "Silence")
        ],
        audioFileURL: nil
    )
    return EventTimelineView(event: mockEvent)
}
