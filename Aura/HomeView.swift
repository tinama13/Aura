//
//  HomeView.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack {
            Text("Hello, Home!")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    HomeView()
}
