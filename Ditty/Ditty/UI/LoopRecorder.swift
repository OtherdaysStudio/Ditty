import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Captures dithered preview frames into an in-memory buffer and encodes them
/// to an animated GIF when finished. Used by the live-record (hold-shutter)
/// flow.
///
/// Frame cadence is sampled — `appendIfNeeded` is cheap to call on every UI
/// update because it short-circuits when the minimum interval hasn't elapsed.
@MainActor
final class LoopRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    /// 0…1 fill of the ring around the shutter.
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastEncodedURL: URL? = nil
    @Published private(set) var isEncoding: Bool = false

    /// Length cap (seconds). 3s at 12fps → ~36 frames → ~1MB GIFs.
    let maxDuration: Double = 3.0
    /// Target frames per second.
    let fps: Int = 12

    private var frames: [UIImage] = []
    private var startedAt: Date?
    private var timer: Timer?

    func start() {
        guard !isRecording else { return }
        frames.removeAll(keepingCapacity: true)
        startedAt = Date()
        progress = 0
        isRecording = true
        // Drives the progress fill independent of frame appends.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startedAt else { return }
                let elapsed = Date().timeIntervalSince(start)
                self.progress = min(1, elapsed / self.maxDuration)
                if elapsed >= self.maxDuration {
                    self.stop()
                }
            }
        }
    }

    /// Append `image` if enough time has elapsed since the last frame to hit
    /// the target FPS. Cheap no-op when not recording.
    func appendIfNeeded(_ image: UIImage) {
        guard isRecording, let start = startedAt else { return }
        let elapsed = Date().timeIntervalSince(start)
        let expectedFrame = Int(elapsed * Double(fps))
        if expectedFrame >= frames.count {
            frames.append(image)
        }
    }

    /// Stop recording and encode to GIF on a background queue. Calls `then`
    /// with the file URL once written, or nil on failure.
    func stop(then completion: ((URL?) -> Void)? = nil) {
        guard isRecording else {
            completion?(lastEncodedURL)
            return
        }
        isRecording = false
        timer?.invalidate()
        timer = nil

        let snapshot = frames
        frames.removeAll(keepingCapacity: false)
        startedAt = nil
        progress = 0

        guard !snapshot.isEmpty else {
            completion?(nil)
            return
        }

        isEncoding = true
        let fps = self.fps
        DispatchQueue.global(qos: .userInitiated).async {
            let url = LoopRecorder.encodeGIF(frames: snapshot, fps: fps)
            DispatchQueue.main.async {
                self.isEncoding = false
                self.lastEncodedURL = url
                completion?(url)
            }
        }
    }

    nonisolated private static func encodeGIF(frames: [UIImage], fps: Int) -> URL? {
        let frameDelay = 1.0 / Double(max(1, fps))
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("ditty-\(Int(Date().timeIntervalSince1970)).gif")
        let type: CFString
        if #available(iOS 14.0, *) {
            type = UTType.gif.identifier as CFString
        } else {
            type = "com.compuserve.gif" as CFString
        }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type, frames.count, nil) else {
            return nil
        }

        let fileProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(dest, fileProps as CFDictionary)

        let frameProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay
            ]
        ]

        for frame in frames {
            guard let cg = frame.cgImage else { continue }
            CGImageDestinationAddImage(dest, cg, frameProps as CFDictionary)
        }

        if CGImageDestinationFinalize(dest) {
            return url
        }
        return nil
    }
}
