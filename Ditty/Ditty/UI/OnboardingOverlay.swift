import SwiftUI

/// First-launch overlay teaching the three non-obvious gestures: tap a system
/// pill to jump, FX for inline effects, long-press for the full picker. Stays
/// dismissed via @AppStorage after the user taps Done.
struct OnboardingOverlay: View {
    @Binding var isPresented: Bool

    @State private var page: Int = 0

    private let pages: [Page] = [
        Page(symbol: "rectangle.split.3x1.fill",
             title: "Pick a system",
             body: "Scroll the row under the photo and tap any console to switch instantly. Long-press the photo for the full list."),
        Page(symbol: "slider.horizontal.below.rectangle",
             title: "Adjust the effect",
             body: "Tap FX to scrub diffuse, ordered, kernel, and diversity. The dither updates as you drag."),
        Page(symbol: "crop",
             title: "Recompose your shot",
             body: "When viewing a photo, the Crop pill in the corner lets you reframe before you save."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 32) {
                Spacer()

                let p = pages[page]
                Image(systemName: p.symbol)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white)
                    .frame(height: 80)

                VStack(spacing: 12) {
                    Text(p.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(p.body)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 32)
                }

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }

                Button {
                    if page < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Next" : "Got it")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                Button("Skip") {
                    withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }
}
