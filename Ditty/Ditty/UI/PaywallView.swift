import SwiftUI

struct PaywallView: View {
    @ObservedObject var purchase: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                bullets
                Spacer(minLength: 12)
                buyButton
                restoreButton
                if let err = purchase.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                Text("One-time purchase. Unlocks every system on every device signed in to your Apple ID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await purchase.bootstrap() }
        .onChange(of: purchase.isPro) { unlocked in
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "tv.inset.filled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Ditty Pro")
                .font(.largeTitle.bold())
            Text("Unlock every retro system.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(icon: "tv", title: "40+ retro systems",
                detail: "Apple II, Atari ST/VCS, Amstrad CPC, MSX, PICO-8, TIC-80, Game Gear, Mac 128K, EGA, and more")
            row(icon: "rectangle.split.3x3.fill", title: "C-64 FLI variants",
                detail: "Authentic FLI mode with the original VIC bug or clean blanking")
            row(icon: "paintpalette", title: "Every dither kernel",
                detail: "Floyd-Steinberg, Atkinson, Stucki, Sierra, ordered, and more")
            row(icon: "bolt.fill", title: "Lifetime access",
                detail: "Pay once. No subscription.")
        }
        .padding(20)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var buyButton: some View {
        Button {
            Task { await purchase.buy() }
        } label: {
            HStack {
                if purchase.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Unlock everything")
                        .font(.headline)
                    if let p = purchase.proProduct {
                        Text("· \(p.displayPrice)")
                            .font(.headline)
                            .opacity(0.85)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(purchase.isPurchasing || purchase.proProduct == nil)
    }

    private var restoreButton: some View {
        Button {
            Task { await purchase.restore() }
        } label: {
            Text("Restore purchase")
                .font(.subheadline)
        }
        .disabled(purchase.isPurchasing)
    }
}
