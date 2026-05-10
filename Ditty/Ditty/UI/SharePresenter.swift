import UIKit

/// Presents UIActivityViewController via UIKit's window machinery so the
/// share flow doesn't fight SwiftUI's `.sheet(item:)` stack. SwiftUI gets
/// flaky when multiple `.sheet` modifiers race during dismissal — this
/// helper avoids the issue entirely.
enum SharePresenter {
    static func present(_ items: [Any], from sourceView: UIView? = nil) {
        guard let root = topViewController() else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad requires a popover anchor; iPhone ignores it.
        if let pop = vc.popoverPresentationController {
            pop.sourceView = sourceView ?? root.view
            pop.sourceRect = (sourceView ?? root.view).bounds
        }
        root.present(vc, animated: true)
    }

    /// Walk the active window scene to the top-most presented controller —
    /// presenting from any other vc throws a "view not in window hierarchy"
    /// warning and silently fails.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let window = scene?.windows.first(where: { $0.isKeyWindow })
                ?? scene?.windows.first,
              var vc = window.rootViewController else { return nil }
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }
}
