import Foundation
import AVFoundation
import UIKit
import Combine

/// Streams downscaled camera frames as `UIImage`s on the main thread.
///
/// SwiftUI consumes the published `frame`. The AVFoundation delegate runs on a
/// private capture queue inside `CameraStreamer`; the streamer hops UIImages back
/// onto the main actor.
@MainActor
final class CameraSession: ObservableObject {

    enum Position { case back, front }

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var position: Position = .back
    @Published private(set) var permissionDenied: Bool = false
    /// Downscaled preview frame fed to the dither engine each tick.
    @Published private(set) var frame: UIImage?
    /// Most recent full-resolution frame. Cheap to store (replaced each tick),
    /// used when the user captures so "Save original" gets the highest fidelity.
    @Published private(set) var fullResFrame: UIImage?

    private let streamer = CameraStreamer()

    init() {
        streamer.onFrame = { [weak self] preview, fullRes in
            // Already hopped to main by the streamer.
            self?.frame = preview
            self?.fullResFrame = fullRes
        }
    }

    func start() {
        Task { await ensurePermissionAndStart() }
    }

    func stop() {
        streamer.stop()
        isRunning = false
    }

    func toggleCamera() {
        position = (position == .back) ? .front : .back
        streamer.setPosition(position == .back ? .back : .front)
    }

    private func ensurePermissionAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            streamer.start(position: position == .back ? .back : .front)
            isRunning = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                streamer.start(position: position == .back ? .back : .front)
                isRunning = true
            } else {
                permissionDenied = true
            }
        default:
            permissionDenied = true
        }
    }
}

/// All AVFoundation work lives here, off the main actor.
final class CameraStreamer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Called on the main thread for each emitted frame. Two images are
    /// supplied: a downscaled preview for the dither pipeline, and a
    /// full-resolution copy for the "Save original" path.
    var onFrame: ((UIImage, UIImage) -> Void)?

    /// Longest edge (in pixels) for the *preview* image fed to the dither
    /// engine. The full-resolution image is also published separately.
    var maxPreviewEdge: CGFloat = 480

    /// Soft FPS cap — the engine costs more than the camera. The dither
    /// pipeline drops frames it can't keep up with via `liveBusy`, so we publish
    /// up to 30fps to feel responsive while letting the engine self-throttle.
    /// Drops to 12fps automatically when the device is in Low Power Mode so
    /// we don't drain the battery while iOS is asking apps to ease up.
    var targetFPS: Double {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? 12 : 30
    }

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "ditty.camera.capture", qos: .userInitiated)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var lastEmit: CFTimeInterval = 0
    private var currentPosition: AVCaptureDevice.Position = .back

    func start(position: AVCaptureDevice.Position) {
        currentPosition = position
        captureQueue.async { [weak self] in
            self?.configure()
            self?.session.startRunning()
        }
    }

    func stop() {
        captureQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func setPosition(_ position: AVCaptureDevice.Position) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            // Bail if the requested position has no usable device (e.g. some iPads
            // don't expose a back wide camera). Avoids an empty input config that
            // produces FigCaptureSourceRemote errors.
            guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) != nil else {
                return
            }
            self.currentPosition = position
            self.session.beginConfiguration()
            self.reconfigureInputs()
            self.session.commitConfiguration()
        }
    }

    private func configure() {
        guard session.outputs.isEmpty else { return }
        session.beginConfiguration()
        // Pick the highest preset the device actually supports. Hard-coding 1280x720
        // can produce -17281 on devices that don't expose that exact preset.
        for preset: AVCaptureSession.Preset in [.hd1280x720, .high, .medium] {
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
                break
            }
        }
        reconfigureInputs()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        applyConnectionSettings()
        session.commitConfiguration()
    }

    private func reconfigureInputs() {
        for input in session.inputs { session.removeInput(input) }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
        applyConnectionSettings()
    }

    private func applyConnectionSettings() {
        guard let connection = videoOutput.connection(with: .video) else { return }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (currentPosition == .front)
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        let minStep = 1.0 / max(1, targetFPS)
        if now - lastEmit < minStep { return }
        lastEmit = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ci.extent

        // Build the full-resolution UIImage first (this is what we save when
        // "Save original" is on).
        guard let fullCG = ciContext.createCGImage(ci, from: extent) else { return }
        let fullImage = UIImage(cgImage: fullCG)

        // Build the downscaled preview for the dither pipeline.
        let edge = max(extent.width, extent.height)
        let scale = edge > maxPreviewEdge ? maxPreviewEdge / edge : 1
        let previewImage: UIImage
        if scale < 1 {
            let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            if let previewCG = ciContext.createCGImage(scaled, from: scaled.extent) {
                previewImage = UIImage(cgImage: previewCG)
            } else {
                previewImage = fullImage
            }
        } else {
            previewImage = fullImage
        }

        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(previewImage, fullImage)
        }
    }
}
