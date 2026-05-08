import Foundation
import CoreGraphics
import UIKit
import Vision

enum ImageBridge {

    /// Compute a "smart" crop center for `cg` at the given target aspect ratio.
    /// Uses Vision's attention-based saliency to find the most interesting
    /// region — typically the subject of a phone photo. Returns the centroid
    /// in pixel coordinates (top-left origin). Falls back to image center if
    /// Vision returns no salient regions.
    static func smartCropCenter(_ cg: CGImage) -> CGPoint {
        let imgW = CGFloat(cg.width)
        let imgH = CGFloat(cg.height)
        let fallback = CGPoint(x: imgW / 2, y: imgH / 2)

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([request]) } catch { return fallback }
        guard let obs = request.results?.first as? VNSaliencyImageObservation else { return fallback }
        let salient = obs.salientObjects ?? []
        guard !salient.isEmpty else { return fallback }

        var minX: CGFloat = 1, minY: CGFloat = 1, maxX: CGFloat = 0, maxY: CGFloat = 0
        for r in salient {
            let bb = r.boundingBox  // normalized 0...1, origin bottom-left
            minX = min(minX, bb.minX); minY = min(minY, bb.minY)
            maxX = max(maxX, bb.maxX); maxY = max(maxY, bb.maxY)
        }
        let cx = (minX + maxX) * 0.5
        let cyFromBottom = (minY + maxY) * 0.5
        return CGPoint(x: cx * imgW, y: (1 - cyFromBottom) * imgH)
    }

    /// Resize a UIImage to the target system pixel grid and produce a flat 0xAABBGGRR pixel array.
    /// The output array length is exactly `width * height`, matching the engine's `[UInt32]` layout.
    /// `cropRect` is normalized 0...1 in source coords (top-left origin); when supplied,
    /// the source is hard-cropped to that rect before scaling and the smart-crop step is skipped.
    /// `useSaliency: false` disables the per-call Vision saliency lookup — required for the
    /// live camera path, where saliency would burn ~50ms per frame.
    static func sourcePixels(from image: UIImage,
                             target: DithertronSettings,
                             cropRect: CGRect? = nil,
                             useSaliency: Bool = true) -> (pixels: [UInt32], width: Int, height: Int)? {
        guard var cg = image.cgImage else { return nil }
        if let r = cropRect {
            let imgW = CGFloat(cg.width), imgH = CGFloat(cg.height)
            let cropped = CGRect(
                x: r.minX * imgW,
                y: r.minY * imgH,
                width: r.width * imgW,
                height: r.height * imgH
            ).integral
            if let cgCropped = cg.cropping(to: cropped) {
                cg = cgCropped
            }
        }
        let w = target.width
        let h = target.height

        let cs = CGColorSpaceCreateDeviceRGB()
        // Memory order R, G, B, A. Reading as a UInt32 on LE Apple silicon yields 0xAABBGGRR
        // — the engine's convention (R in the lowest byte).
        let bitmapInfo: UInt32 = CGImageAlphaInfo.noneSkipLast.rawValue
        // big-endian (default) so byte 0 is "first" of the pixel which we declare to be R via skipLast (RGBX)

        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.interpolationQuality = .high
        let imgW = CGFloat(cg.width)
        let imgH = CGFloat(cg.height)
        let scaleW = CGFloat(w) / imgW
        let scaleH = CGFloat(h) / imgH
        let scale = max(scaleW, scaleH)
        let drawW = imgW * scale
        let drawH = imgH * scale

        // Saliency-based smart crop for static / captured photos. For the
        // live camera path (`useSaliency: false`) we just center-crop —
        // Vision was costing ~50ms a frame, dominating the engine cost on
        // every system.
        let center: CGPoint = useSaliency
            ? smartCropCenter(cg)
            : CGPoint(x: imgW / 2, y: imgH / 2)
        let scaledCx = center.x * scale
        let scaledCy = center.y * scale
        var x = CGFloat(w) / 2 - scaledCx
        var y = CGFloat(h) / 2 - scaledCy
        // Clamp so the canvas is fully covered (no exposed background).
        x = min(0, max(CGFloat(w) - drawW, x))
        y = min(0, max(CGFloat(h) - drawH, y))
        ctx.draw(cg, in: CGRect(x: x, y: y, width: drawW, height: drawH))

        guard let buffer = ctx.data else { return nil }
        let bytes = buffer.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let count = w * h
        var pixels = [UInt32](repeating: 0, count: count)
        // explicit byte read so we don't depend on CG's byte-order semantics
        for i in 0..<count {
            let r = UInt32(bytes[i * 4 + 0])
            let g = UInt32(bytes[i * 4 + 1])
            let b = UInt32(bytes[i * 4 + 2])
            pixels[i] = r | (g << 8) | (b << 16)
        }
        return (pixels, w, h)
    }

    /// Build a CGImage from the engine's pixel buffer.
    /// The engine stores each pixel as 0x00BBGGRR (R in the lowest byte), matching the JS reference.
    static func cgImage(fromPixels pixels: [UInt32], width: Int, height: Int) -> CGImage? {
        guard !pixels.isEmpty else { return nil }
        var rgba = [UInt8](repeating: 0, count: pixels.count * 4)
        for i in 0..<pixels.count {
            let p = pixels[i]
            rgba[i * 4 + 0] = UInt8(p & 0xff)         // R
            rgba[i * 4 + 1] = UInt8((p >> 8) & 0xff)  // G
            rgba[i * 4 + 2] = UInt8((p >> 16) & 0xff) // B
            rgba[i * 4 + 3] = 255                      // A
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        // RGBA in memory; big-endian default → CG reads byte 0 = R, 1 = G, 2 = B, 3 = X
        let bitmapInfo: UInt32 = CGImageAlphaInfo.noneSkipLast.rawValue
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
