//
//  SplashView.swift
//  Aura
//
//  Created by 15 BGCC Loan Libary on 7/16/26.
//

import SwiftUI

struct SplashView: View {
    @State private var isRotating = false
    var body: some View {
        Image("Icon").rotationEffect(.degrees(isRotating ? 360 : 0)).animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: isRotating).onAppear{
            isRotating = true
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        
    }
}

#Preview {
    SplashView()
}
