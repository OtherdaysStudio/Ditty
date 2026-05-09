import SwiftUI

/// First-launch onboarding rebuilt as a full-screen card carousel.
/// Each card is a separate page in a horizontal TabView — swipe to advance,
/// or tap the primary button. The final card's CTA dismisses the flow.
struct OnboardingOverlay: View {
    @Binding var isPresented: Bool

    @State private var page: Int = 0

    private let cards: [Card] = [
        Card(
            illustration: .liveDither,
            kicker: "Welcome to Ditty",
            headline: "Your camera, in 8-bit.",
            body: "Point at anything. Ditty re-dithers every frame live, in the actual palette and pixel grid of 40+ retro systems."
        ),
        Card(
            illustration: .picker,
            kicker: "Pick a system",
            headline: "Tap. Long-press. Done.",
            body: "Scroll the row beneath the photo and tap any console. Long-press the photo for the full searchable list."
        ),
        Card(
            illustration: .effects,
            kicker: "Tune the look",
            headline: "FX makes it yours.",
            body: "Tap FX to scrub diffuse, ordered, kernel, or diversity. The image responds while you drag."
        ),
        Card(
            illustration: .save,
            kicker: "Take it home",
            headline: "Save and share.",
            body: "Hit the shutter, choose an aspect, and Ditty drops it into Photos. Share it straight from the app."
        ),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(cards.indices, id: \.self) { i in
                    OnboardingCard(card: cards[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Skip top-right.
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.trailing, 24)
                .padding(.top, 16)
            }

            // Bottom nav: page dots + primary CTA.
            VStack(spacing: 18) {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(cards.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.white : Color.white.opacity(0.25))
                            .frame(width: i == page ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: page)
                    }
                }
                Button {
                    if page < cards.count - 1 {
                        withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
                    }
                } label: {
                    Text(page < cards.count - 1 ? "Next" : "Start dithering")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Card model + view

private struct Card {
    enum Illustration {
        case liveDither, picker, effects, save
    }
    let illustration: Illustration
    let kicker: String
    let headline: String
    let body: String
}

private struct OnboardingCard: View {
    let card: Card

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            illustration
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .padding(.horizontal, 32)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 10) {
                Text(card.kicker.uppercased())
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                Text(card.headline)
                    .font(.system(.largeTitle, design: .default).weight(.semibold))
                    .foregroundStyle(.white)
                Text(card.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)

            // Reserve space for the bottom nav so cards don't jump.
            Color.clear.frame(height: 140)
        }
    }

    @ViewBuilder
    private var illustration: some View {
        switch card.illustration {
        case .liveDither:    liveDitherCard
        case .picker:        pickerCard
        case .effects:       effectsCard
        case .save:          saveCard
        }
    }

    // MARK: Card illustrations
    //
    // Drawn with SwiftUI primitives so we don't ship binary assets just for
    // onboarding. Each one is a stylised mockup of the real screen so the
    // card matches what the user lands on.

    private var liveDitherCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)

            // Stylised retro pattern — a plain checker-of-circles vibe that
            // reads as "dithered output" without needing a real photo.
            GeometryReader { geo in
                let cell: CGFloat = 16
                let cols = Int(geo.size.width / cell)
                let rows = Int(geo.size.height / cell)
                Canvas { ctx, size in
                    let palette: [Color] = [
                        Color(red: 0.19, green: 0.36, blue: 0.30),
                        Color(red: 0.36, green: 0.66, blue: 0.55),
                        Color(red: 0.62, green: 0.82, blue: 0.74),
                        Color(red: 0.85, green: 0.92, blue: 0.85),
                    ]
                    for y in 0..<rows {
                        for x in 0..<cols {
                            let bayer = ((x ^ y) % 4 + (x % 3) + (y % 2)) % palette.count
                            let rect = CGRect(x: CGFloat(x) * cell,
                                              y: CGFloat(y) * cell,
                                              width: cell,
                                              height: cell)
                            ctx.fill(Path(rect), with: .color(palette[bayer]))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(1)
        }
    }

    private var pickerCard: some View {
        VStack(spacing: 18) {
            // Mock photo viewport.
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                .overlay(
                    Image(systemName: "rectangle.portrait")
                        .font(.system(size: 60, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                )
                .frame(height: 220)

            // Mock pill row.
            HStack(spacing: 8) {
                pill("Game Boy", active: true)
                pill("NES")
                pill("C-64")
                pill("ZX")
            }
        }
    }

    private var effectsCard: some View {
        VStack(spacing: 16) {
            // Top: photo placeholder.
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                .overlay(
                    Image(systemName: "photo.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.16))
                )
                .frame(height: 200)

            // Bottom: mock FX panel.
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DIFFUSE")
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("0.80").monospacedDigit().foregroundStyle(.white)
                }
                // Tick row.
                HStack(spacing: 3) {
                    ForEach(0..<32, id: \.self) { i in
                        Capsule()
                            .fill(i == 16
                                  ? Color(red: 0.99, green: 0.78, blue: 0.27)
                                  : Color.white.opacity(i % 8 == 0 ? 0.4 : 0.22))
                            .frame(width: 2, height: i % 8 == 0 ? 16 : 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 8) {
                    pill("Kernel")
                    pill("Diffuse", active: true)
                    pill("Ordered")
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var saveCard: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
            }
            .frame(height: 220)

            HStack(spacing: 10) {
                pill("Original")
                pill("1:1", active: true)
                pill("4:5")
                pill("16:9")
            }
        }
    }

    private func pill(_ text: String, active: Bool = false) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced).weight(active ? .bold : .regular))
            .foregroundStyle(active ? .black : .white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Color.white : Color.white.opacity(0.1), in: Capsule())
    }
}
