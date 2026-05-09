import SwiftUI
import Lottie

/// Plays the Jitter export once on launch. Calls `onFinished` when the animation
/// runs to completion. Falls back to immediately finishing if the JSON is missing
/// (defensive — keeps the app launchable even if the bundle changed).
struct SplashView: View {
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            LottieFile(name: "splash", onFinished: onFinished)
                .frame(maxWidth: 280, maxHeight: 280)
        }
        .preferredColorScheme(.light)
    }
}

private struct LottieFile: UIViewRepresentable {
    let name: String
    let onFinished: () -> Void

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear

        guard let url = locate(name: name) else {
            DispatchQueue.main.async { onFinished() }
            return host
        }

        let animationView = LottieAnimationView(filePath: url.path)
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.loopMode = .playOnce
        // Original Jitter export runs ~6s; bumping speed gets us to ~2.5s,
        // which keeps the brand mark visible long enough to register without
        // delaying first interaction.
        animationView.animationSpeed = 2.4
        host.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: host.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        animationView.play { _ in onFinished() }
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func locate(name: String) -> URL? {
        // Look in the Splash.bundle folder first, then fall back to a top-level lookup.
        if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Splash.bundle") {
            return url
        }
        return Bundle.main.url(forResource: name, withExtension: "json")
    }
}
