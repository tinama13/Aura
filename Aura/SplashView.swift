//
//  SplashView.swift
//  Aura
//
//  Created by 15 BGCC Loan Libary on 7/16/26.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        Image("SplashIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 320, height: 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}

#Preview {
    SplashView()
}
