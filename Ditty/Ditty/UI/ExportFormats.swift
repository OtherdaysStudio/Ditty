import UIKit

/// User-selectable export aspect ratios.
///
/// All renders preserve the dithered image's pixel grid (no smoothing, no
/// stretching) — the source image is centered into the chosen frame and any
/// remaining space is filled with `padColor` (defaults to black so it reads as
/// a CRT mat).
enum ExportAspect: String, CaseIterable, Identifiable {
    case original
    case square
    case portrait4x5
    case portrait2x3   // a.k.a. 4:6
    case portrait9x16
    case landscape3x2
    case landscape16x9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original:        return "Original"
        case .square:          return "Square (1:1)"
        case .portrait4x5:     return "Portrait (4:5)"
        case .portrait2x3:     return "Portrait (4:6)"
        case .portrait9x16:    return "Story (9:16)"
        case .landscape3x2:    return "Landscape (3:2)"
        case .landscape16x9:   return "Landscape (16:9)"
        }
    }

    /// Width / Height. `nil` means use the source image's own ratio.
    var ratio: CGFloat? {
        switch self {
        case .original:      return nil
        case .square:        return 1.0
        case .portrait4x5:   return 4.0/5.0
        case .portrait2x3:   return 2.0/3.0      // 4:6 simplified
        case .portrait9x16:  return 9.0/16.0
        case .landscape3x2:  return 3.0/2.0
        case .landscape16x9: return 16.0/9.0
        }
    }
}

enum ExportRenderer {

    /// Render `image` into `aspect` by **center-cropping** the source to fill the
    /// canvas — no black bars. Pixels are sampled nearest-neighbor so the chunky
    /// retro grid stays crisp.
    ///
    /// `watermark` (when non-nil) draws a small "DITTY · <system>" tag in the
    /// bottom-right corner. Free users always get the watermark; Pro users
    /// can opt out via Settings.
    static func render(
        _ image: UIImage,
        aspect: ExportAspect,
        watermark: String? = nil,
        targetLongEdge: CGFloat = 2048
    ) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let imageW = CGFloat(cg.width)
        let imageH = CGFloat(cg.height)
        guard imageW > 0, imageH > 0 else { return nil }

        let canvasRatio = aspect.ratio ?? (imageW / imageH)
        let (canvasW, canvasH) = pixelDimensions(forRatio: canvasRatio, longEdge: targetLongEdge)

        // Scale to FILL the canvas so there's no padding; the longer dimension
        // overflows and gets cropped by the canvas bounds.
        let scale = max(canvasW / imageW, canvasH / imageH)
        let drawW = imageW * scale
        let drawH = imageH * scale
        let drawX = (canvasW - drawW) / 2.0
        let drawY = (canvasH - drawH) / 2.0

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasW, height: canvasH),
            format: format
        )

        return renderer.image { context in
            let cgctx = context.cgContext
            cgctx.interpolationQuality = .none
            cgctx.saveGState()
            cgctx.translateBy(x: 0, y: canvasH)
            cgctx.scaleBy(x: 1, y: -1)
            cgctx.draw(cg, in: CGRect(x: drawX, y: canvasH - drawY - drawH, width: drawW, height: drawH))
            cgctx.restoreGState()

            if let mark = watermark, !mark.isEmpty {
                drawWatermark(in: cgctx, canvasSize: CGSize(width: canvasW, height: canvasH), text: mark)
            }
        }
    }

    private static func drawWatermark(in ctx: CGContext, canvasSize: CGSize, text: String) {
        // Scale the watermark with the canvas so a 9:16 story still gets a
        // legible-but-small tag. ~2.5% of the long edge feels right.
        let longEdge = max(canvasSize.width, canvasSize.height)
        let fontSize = max(12, longEdge * 0.025)
        let pad: CGFloat = fontSize * 0.6

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let textSize = attributed.size()
        let bgRect = CGRect(
            x: canvasSize.width - textSize.width - pad * 2 - fontSize * 0.6,
            y: canvasSize.height - textSize.height - pad * 1.4,
            width: textSize.width + pad,
            height: textSize.height + pad * 0.5
        )

        // Translucent dark pill behind the text.
        ctx.saveGState()
        let path = UIBezierPath(roundedRect: bgRect, cornerRadius: bgRect.height / 2)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        UIGraphicsPushContext(ctx)
        attributed.draw(at: CGPoint(
            x: bgRect.minX + pad / 2,
            y: bgRect.minY + pad / 4
        ))
        UIGraphicsPopContext()
    }

    private static func pixelDimensions(forRatio ratio: CGFloat, longEdge: CGFloat) -> (CGFloat, CGFloat) {
        if ratio >= 1 {
            return (longEdge, longEdge / ratio)
        } else {
            return (longEdge * ratio, longEdge)
        }
    }
}
