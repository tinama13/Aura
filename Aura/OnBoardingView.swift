//
//  OnBoardingView.swift
//  Aura
//
//  Created by 15 BGCC Loan Libary on 7/16/26.
//

import SwiftUI
import AVFoundation
import UserNotifications

struct OnBoardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            ZStack(alignment: .trailing) {
                AuraHeaderView()
                
                Button("Skip") {
                    hasCompletedOnboarding = true
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.85, green: 0.28, blue: 0.2))
                .padding(.trailing, 24)
            }
            .padding(.top, 8)

            switch currentPage {
            case 0:
                OnBoardingPageView (
                    image: "aura-img",
                    title: "Welcome to Aura",
                    description: "Aura listens so you don't have to worry about missing what matters — sirens, doorbells, alarms, and the sounds of your everyday life. Let's get you set up in under a minute.",
                    buttonText: "Next",
                    action: { currentPage += 1 }
                )
            case 1:
                OnBoardingPageView(
                    image: "ear-wave",
                    title: "Never Miss What You can't Hear",
                    description: "Aura turns everyday sounds around you into instant visual and haptic alerts — sirens, doorbells, alarms, and more. It can also securely record detected sounds so you can review what happened later.",
                    buttonText: "Next",
                    action: { currentPage += 1 }
                )
            case 2:
                OnBoardingPageView(
                    image: "aura-listen",
                    title: "Aura Needs to Listen",
                    description: "We use your microphone to detect sounds in real time. Everything is processed on your device - audio never leaves your phone.",
                    buttonText: "Next",
                    action: {
                        requestMicrophonePermission()
                        currentPage += 1
                    }
                )
            case 3:
                OnBoardingPageView(
                    image: "aura-presets",
                    title: "Pick how you'll use Aura",
                    description: "Choose a mode to get alerts tailored to what you are doing. You can change this anytime.",
                    buttonText: "Get Started",
                    action: {
                        requestNotificationPermission()
                        hasCompletedOnboarding = true
                    }
                )
            default:
                EmptyView()
            }
            PageDots(total: 4, current: currentPage)
        }
    }
    
    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

struct PageDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color(red: 0.204, green: 0.678, blue: 0.914) : Color(white: 0.85))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 16)
    }
}


#Preview {
    OnBoardingView(hasCompletedOnboarding: .constant(false))
}
