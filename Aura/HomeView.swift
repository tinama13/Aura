import SwiftUI

struct HomeView: View {
    @State private var isListening = false
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Aura")
                    .font(.custom("Snell Roundhand", size: 34))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding(.top, 34)
            .padding(.horizontal, 26)

            Text("Driving")
                .font(.custom("Itim", size: 30))
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding(.top, 30)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isListening.toggle()
                }

                if isListening {
                    isPulsing = true
                } else {
                    isPulsing = false
                }
            } label: {
                ZStack {
                    if isListening {
                        Circle()
                            .stroke(Color.black.opacity(0.18), lineWidth: 3)
                            .frame(width: 170, height: 170)
                            .scaleEffect(isPulsing ? 1.12 : 1.0)
                            .opacity(isPulsing ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                value: isPulsing
                            )
                    }

                    Circle()
                        .stroke(
                            Color.black.opacity(0.85),
                            style: StrokeStyle(
                                lineWidth: 4,
                                lineCap: .round,
                                dash: isListening ? [4, 9] : []
                            )
                        )
                        .frame(width: 170, height: 170)

                    Image("EarListeningIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 105, height: 105)
                }
                .frame(width: 180, height: 180)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 34)

            Text(isListening ? "Listening" : "Start\nListening")
                .font(.custom("Itim", size: 25))
                .fontWeight(.bold)
                .lineSpacing(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .frame(height: 62)
                .padding(.top, 24)

            Rectangle()
                .fill(Color.black.opacity(0.9))
                .frame(height: 2)
                .padding(.horizontal, 20)
                .padding(.top, 46)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    HomeView()
}
