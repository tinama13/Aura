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
            AuraHeaderView()
            
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
                        Text(audioPlayer.isPlaying ? "Stop Playing Detection Recording" : "Play Detection Recording")
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
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlayerNodeAttached = false
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    
    func togglePlayback(url: URL?) {
        guard let url = resolvedAudioURL(from: url) else {
            print("Detection recording file was not found.")
            return
        }
        
        if isPlaying {
            stopPlayback()
        } else {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try audioSession.setActive(true)
                try audioSession.overrideOutputAudioPort(.speaker)
                
                do {
                    if try playWithAudioEngine(url: url) {
                        return
                    }
                } catch {
                    print("Audio engine could not play detection audio: \(error.localizedDescription)")
                }
                
                playWithAVAudioPlayer(url: url)
            } catch {
                print("Failed to set up detection playback: \(error.localizedDescription)")
                isPlaying = false
            }
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playerNode.stop()
        audioEngine.stop()
        isPlaying = false
    }
    
    private func playWithAudioEngine(url: URL) throws -> Bool {
        let audioFile = try AVAudioFile(forReading: url)
        guard audioFile.length > 0 else { return false }
        
        if !isPlayerNodeAttached {
            audioEngine.attach(playerNode)
            isPlayerNodeAttached = true
        }
        
        audioEngine.stop()
        playerNode.stop()
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.audioEngine.stop()
            }
        }
        
        try audioEngine.start()
        playerNode.play()
        isPlaying = true
        return true
    }
    
    private func playWithAVAudioPlayer(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            isPlaying = audioPlayer?.play() ?? false
        } catch {
            print("AVAudioPlayer could not play detection audio: \(error.localizedDescription)")
            audioPlayer = nil
            isPlaying = false
        }
    }
    
    private func resolvedAudioURL(from url: URL?) -> URL? {
        guard let url else { return nil }
        
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            return documentsURL
        }
        
        return nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

@MainActor
class EventNarrator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func toggleReading(_ text: String) {
        if isSpeaking {
            stopReading()
        } else {
            read(text)
        }
    }
    
    func stopReading() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    private func read(_ text: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up speech audio session: \(error.localizedDescription)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
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
