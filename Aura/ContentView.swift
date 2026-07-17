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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var current_tab: Tab = .home
    // Splash shows every launch, then hands off to onboarding or home
    @State private var showingSplash = true

    var body: some View {

        // The NavigationStack wraps the WHOLE app (tabs + NavBar), so pushed
        // screens like SoundDetailView cover the full screen instead of being
        // squeezed into the tab area behind the NavBar.
        Group {
        if showingSplash {
            SplashView()
                .task {
                    // Wait 2 seconds, then fade to the next screen
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.easeOut(duration: 0.4)) {
                        showingSplash = false
                    }
                }
        }
        else if hasCompletedOnboarding {
            
       
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    switch current_tab {
                    case .home:
                        HomeView()
                    case .presets:
                        PresetsView()
                    case .sounds:
                        SoundsView()
                    }
                }
                .padding(.bottom, 90)
                NavBar(current_tab: $current_tab)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        }
        else {
            OnBoardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        }
        // When onboarding is reset (the dev ↺ button), replay the splash too
        .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
            if newValue == false {
                showingSplash = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SoundManager())
        .environmentObject(PresetManager())
        .environmentObject(HistoryManager())
}
