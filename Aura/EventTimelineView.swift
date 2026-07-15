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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Event Timeline")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            VStack(spacing: 12) {
                Text(event.name)
                    .font(.system(size: 28, weight: .bold))
                
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
                .padding(.top, 8)
                .disabled(event.audioFileURL == nil)
                .opacity(event.audioFileURL == nil ? 0.4 : 1.0)
            }
            .padding(.bottom, 30)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(event.timeline.enumerated()), id: \.element.id) { index, node in
                        HStack(alignment: .top, spacing: 16) {
                            
                            Text(node.formattedTime)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 75, alignment: .trailing)
                            
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(node.isSilence ? Color.gray.opacity(0.5) : Color(red: 0.85, green: 0.28, blue: 0.2))
                                    .frame(width: 14, height: 14)
                                    .padding(.top, 2)
                                
                                if index != event.timeline.count - 1 {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                        .frame(minHeight: 40)
                                }
                            }
                            
                            Text(node.label)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(node.isSilence ? .gray : .black)
                                .padding(.top, -1)
                                .padding(.bottom, 24)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
}

class EventAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    
    func togglePlayback(url: URL?) {
        guard let url = url else { return }
        
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
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
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

#Preview {
    let now = Date()
    let mockEvent = DetectedEvent(
        name: "Glass Breaking",
        timestamp: now,
        timeline: [
            TimelineNode(exactTime: now, label: "Glass Breaking"),
            TimelineNode(exactTime: now.addingTimeInterval(2), label: "Silence"),
            TimelineNode(exactTime: now.addingTimeInterval(5), label: "Footsteps"),
            TimelineNode(exactTime: now.addingTimeInterval(12), label: "Silence")
        ],
        audioFileURL: nil
    )
    return EventTimelineView(event: mockEvent)
}
