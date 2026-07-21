//
//  NavBar.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI

struct NavBar: View {
    @Binding var current_tab: Tab
    
    private let accentBlue = Color(red: 0.204, green: 0.678, blue: 0.914)
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Spacer()
                
                Button(action: {
                    current_tab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(current_tab == tab ? accentBlue : .black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(current_tab == tab ? accentBlue.opacity(0.15) : Color.clear)
                            )
                        
                        Text(tab.rawValue)
                            .font(.custom("MarkerFelt-Thin", size: 12))
                            .foregroundColor(current_tab == tab ? accentBlue : .black.opacity(0.6))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .anchorPreference(key: AuraTutorialHighlightPreferenceKey.self, value: .bounds) { anchor in
                        if let target = highlightTarget(for: tab) {
                            return [target: anchor]
                        } else {
                            return [:]
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 30)
        .background(Color(red: 0.88, green: 0.93, blue: 0.96))
    }
    
    private func highlightTarget(for tab: Tab) -> AuraTutorialHighlightTarget? {
        switch tab {
        case .presets:
            return .presetsTab
        case .sounds:
            return .soundsTab
        case .home:
            return nil
        }
    }
}

#Preview {
    NavBar(current_tab: .constant(.home))
}
