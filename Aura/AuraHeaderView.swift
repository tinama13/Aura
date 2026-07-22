import SwiftUI

struct AuraHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.204, green: 0.678, blue: 0.914), lineWidth: 2)
                )
            
            Text("Aura")
                .font(.custom("MarkerFelt-Thin", size: 30))
                .foregroundStyle(.black)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.95, blue: 1.0),
                    Color.white
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }
}

#Preview {
    AuraHeaderView()
}
