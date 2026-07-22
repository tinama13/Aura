//
//  SplashView.swift
//  Aura
//
//  Created by 15 BGCC Loan Libary on 7/16/26.
//

import SwiftUI

struct SplashView: View {
    @State private var isSpinning = false
    
    var body: some View {
        Image("SplashIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 320, height: 320)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(
                .linear(duration: 2.0)
                .repeatForever(autoreverses: false),
                value: isSpinning
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .onAppear {
                isSpinning = true
            }
    }
}

#Preview {
    SplashView()
}
