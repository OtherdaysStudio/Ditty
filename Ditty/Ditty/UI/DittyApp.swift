import SwiftUI

@main
struct DittyApp: App {
    @State private var showSplash: Bool = {
        #if DEBUG
        // Tests pass -SkipSplash to avoid waiting on the Lottie animation.
        return !ProcessInfo.processInfo.arguments.contains("-SkipSplash")
        #else
        return true
        #endif
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)
                if showSplash {
                    SplashView(onFinished: {
                        withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
                    })
                    .transition(.opacity)
                }
            }
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
        }
    }
}
