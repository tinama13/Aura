//
//  ContentView.swift
//  Aura
//
//  Created by Tina Ma on 7/7/26.
//

import SwiftUI

enum Tab: String, CaseIterable {
    case home = "Home"
    case presets = "Presets"
    case sounds = "Sounds"
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .presets: return "slider.horizontal.3"
        case .sounds: return "speaker"
        }
    }
}

struct ContentView: View {
    @State private var current_tab: Tab = .home
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                if current_tab == .home {
                    HomeView()
                } else {
                    Text("\(current_tab.rawValue) Screen")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.bottom, 90)
            NavBar(current_tab: $current_tab)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

#Preview {
    ContentView()
}
