import Foundation
import UIKit

/// 5-frame burst sampler — Game Boy Camera tribute. Triggered from the
/// bottom-bar burst button; samples one preview every ~250ms and renders a
/// 2-row contact sheet at the end.
@MainActor
final class BurstCapture: ObservableObject {
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var capturedCount: Int = 0
    /// Fully-rendered contact sheet, ready to share/save. nil while not done.
    @Published private(set) var contactSheet: UIImage? = nil

    let frameTarget: Int = 5
    let interval: TimeInterval = 0.28

    private var frames: [UIImage] = []
    private var timer: Timer?
    private var supplier: (() -> UIImage?)?

    /// Start capturing. `supplier` should return the latest dithered preview
    /// each tick — we call it on the main actor.
    func start(supplier: @escaping () -> UIImage?) {
        guard !isCapturing else { return }
        contactSheet = nil
        frames.removeAll(keepingCapacity: true)
        capturedCount = 0
        isCapturing = true
        self.supplier = supplier
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let supplier else { return }
        if let img = supplier() {
            frames.append(img)
            capturedCount = frames.count
        }
        if frames.count >= frameTarget {
            finish()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isCapturing = false
        frames.removeAll()
        capturedCount = 0
        supplier = nil
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        isCapturing = false
        supplier = nil

        let sheet = BurstCapture.makeContactSheet(frames: frames)
        contactSheet = sheet
        frames.removeAll()
    }

    /// Lay 5 frames into a 2x3 grid (last cell shows the DITTY mark).
    /// Each cell is sized to the frame's aspect, rendered nearest-neighbor
    /// to keep the dither crisp.
    static func makeContactSheet(frames: [UIImage]) -> UIImage? {
        guard !frames.isEmpty, let first = frames.first?.cgImage else { return nil }
        let frameW = CGFloat(first.width)
        let frameH = CGFloat(first.height)
        let cellsPerRow: CGFloat = 3
        let rows: CGFloat = 2
        let pad: CGFloat = max(8, frameW * 0.04)
        // Scale frames up so the long edge of the contact sheet is ~2400px.
        let cellLong: CGFloat = max(frameW, frameH)
        let scale = max(1, 2400.0 / (cellsPerRow * cellLong + (cellsPerRow + 1) * pad))
        let cellW = frameW * scale
        let cellH = frameH * scale
        let padScaled = pad * scale
        let canvasW = cellsPerRow * cellW + (cellsPerRow + 1) * padScaled
        let canvasH = rows * cellH + (rows + 1) * padScaled

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasW, height: canvasH),
            format: format
        )
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
            cg.interpolationQuality = .none

            for i in 0..<6 {
                let row = i / 3
                let col = i % 3
                let x = padScaled + CGFloat(col) * (cellW + padScaled)
                let y = padScaled + CGFloat(row) * (cellH + padScaled)
                let rect = CGRect(x: x, y: y, width: cellW, height: cellH)

                if i < frames.count, let frame = frames[i].cgImage {
                    cg.saveGState()
                    cg.translateBy(x: 0, y: y + cellH)
                    cg.scaleBy(x: 1, y: -1)
                    cg.draw(frame, in: CGRect(x: x, y: 0, width: cellW, height: cellH))
                    cg.restoreGState()
                } else {
                    // Last cell: subtle DITTY tag so the grid feels complete.
                    cg.setFillColor(UIColor(white: 0.10, alpha: 1).cgColor)
                    cg.fill(rect)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.monospacedSystemFont(ofSize: cellH * 0.10, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let str = NSAttributedString(string: "DITTY", attributes: attrs)
                    let strSize = str.size()
                    UIGraphicsPushContext(cg)
                    str.draw(at: CGPoint(
                        x: rect.midX - strSize.width / 2,
                        y: rect.midY - strSize.height / 2
                    ))
                    UIGraphicsPopContext()
                }
            }
        }
    }
}
