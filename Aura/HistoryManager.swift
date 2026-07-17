//
//  HistoryManager.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI
import Combine

struct TimelineNode: Identifiable, Hashable {
    let id = UUID()
    let exactTime: Date
    let label: String
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: exactTime)
    }
    
    var isSilence: Bool {
        return label.lowercased() == "silence" || label.lowercased() == "background noise"
    }
}

struct DetectedEvent: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let timestamp: Date
    let endedAt: Date?
    let timeline: [TimelineNode]
    
    var audioFileURL: URL?
    
    var durationText: String? {
        guard let endedAt else { return nil }
        let seconds = max(1, Int(endedAt.timeIntervalSince(timestamp).rounded()))
        return "it stayed active for about \(formattedDuration(seconds))"
    }
    
    var silenceText: String? {
        guard let endedAt else { return nil }
        let seconds = max(1, Int(endedAt.timeIntervalSince(timestamp).rounded()))
        return "the area quieted down about \(formattedDuration(seconds)) after detection"
    }
    
    private func formattedDuration(_ totalSeconds: Int) -> String {
        if totalSeconds < 60 {
            return "\(totalSeconds) \(totalSeconds == 1 ? "second" : "seconds")"
        }
        
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let minuteText = "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        guard seconds > 0 else { return minuteText }
        let secondText = "\(seconds) \(seconds == 1 ? "second" : "seconds")"
        return "\(minuteText) and \(secondText)"
    }
    
    var timeAgo: String {
        let minutes = Int(Date().timeIntervalSince(timestamp) / 60)
        if minutes == 0 { return "Just now" }
        if minutes > 1440 { return "1+ days" }
        if minutes > 60 { return "\(minutes / 60) hr" }
        return "\(minutes) min"
    }
}

class HistoryManager: ObservableObject {
    @Published var events: [DetectedEvent] = []
    
    func logEvent(name: String, timestamp: Date = Date(), endedAt: Date? = nil, timeline: [TimelineNode], audioFileURL: URL? = nil) -> DetectedEvent {
        let newEvent = DetectedEvent(name: name, timestamp: timestamp, endedAt: endedAt, timeline: timeline, audioFileURL: audioFileURL)
        events.insert(newEvent, at: 0)
        return newEvent
    }
}
