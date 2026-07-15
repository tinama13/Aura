//
//  EventTimelineView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI

struct EventTimelineView: View {
    let event: DetectedEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            
            // Title & Audio Player placeholder
            VStack(spacing: 12) {
                Text(event.name)
                    .font(.system(size: 28, weight: .bold))
                
                Text(event.timestamp, style: .date)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
                
                // Play Button
                Button {
                    // Playback logic will go here
                    print("Playing back event audio...")
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play Recording")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color(red: 0.204, green: 0.678, blue: 0.914).opacity(0.15))
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 30)
            
            // The Timeline Graphics
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(event.timeline.enumerated()), id: \.element.id) { index, node in
                        HStack(alignment: .top, spacing: 16) {
                            
                            // 1. Timestamp (e.g. "0:03")
                            Text(node.formattedTime)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 45, alignment: .trailing)
                            
                            // 2. The Line and Dot
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(node.isSilence ? Color.gray.opacity(0.5) : Color(red: 0.85, green: 0.28, blue: 0.2))
                                    .frame(width: 14, height: 14)
                                    .padding(.top, 2)
                                
                                // Draw the line unless it's the very last item
                                if index != event.timeline.count - 1 {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                        .frame(minHeight: 40) // Adjust height between nodes
                                }
                            }
                            
                            // 3. The Sound Label
                            Text(node.label)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(node.isSilence ? .gray : .black)
                                .padding(.top, -1)
                                .padding(.bottom, 24) // Adds breathing room before the next row
                            
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

// Temporary preview data
#Preview {
    let mockEvent = DetectedEvent(
        name: "Glass Breaking",
        timestamp: Date(),
        timeline: [
            TimelineNode(timeOffset: 0, label: "Glass Breaking"),
            TimelineNode(timeOffset: 2, label: "Silence"),
            TimelineNode(timeOffset: 5, label: "Footsteps"),
            TimelineNode(timeOffset: 12, label: "Silence")
        ]
    )
    return EventTimelineView(event: mockEvent)
}
