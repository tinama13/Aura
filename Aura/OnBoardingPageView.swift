//
//  OnBoardingPageView.swift
//  Aura
//
//  Created by 15 BGCC Loan Libary on 7/16/26.
//

import SwiftUI

struct OnBoardingPageView: View {
    // These properties become the parameters you pass in from OnBoardingView.
    let image: String
    let title: String
    let description: String
    let buttonText: String
    let action: () -> Void   // a function to run when the button is tapped

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
//                .lineSpacing(4)

            Spacer()

            Button(action: action) {
                Text(buttonText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.204, green: 0.678, blue: 0.914))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 24)
    }
}


#Preview{
    // .constant(false) makes a fake binding just for the preview
    OnBoardingView(hasCompletedOnboarding: .constant(false))
}
