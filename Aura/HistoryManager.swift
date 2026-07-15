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
    let timeline: [TimelineNode]
    
    var audioFileURL: URL?
    
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
    
    func logEvent(name: String, timeline: [TimelineNode], audioFileURL: URL? = nil) -> DetectedEvent {
        let newEvent = DetectedEvent(name: name, timestamp: Date(), timeline: timeline, audioFileURL: audioFileURL)
        events.insert(newEvent, at: 0)
        return newEvent
    }
}
