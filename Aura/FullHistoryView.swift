//
//  FullHistoryView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI

struct FullHistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Recent Sounds")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            ScrollView {
                VStack(spacing: 16) {
                    if historyManager.events.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No sounds detected yet.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(historyManager.events) { event in
                            NavigationLink(destination: EventTimelineView(event: event)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        Text(event.name)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                        
                                        Text(event.timeAgo)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                                    }
                                    
                                    Text(event.timestamp, format: .dateTime.month().day().hour().minute())
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
    }
}

#Preview {
    FullHistoryView()
        .environmentObject(HistoryManager())
}
