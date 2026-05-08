import Foundation

final class Dithertron {

    static let maxIterateCount = 100
    private static let temperatureStartIterations = 10
    private static let temperatureStep = 0.01

    var sysparams: DithertronSettings
    var sourceImageData: [UInt32] = []
    var dithcanv: BaseDitheringCanvas?
    var pixelsAvailable: ((PixelsAvailableMessage) -> Void)?

    init(sysparams: DithertronSettings = Systems.all[0]) {
        self.sysparams = sysparams
    }

    func setSettings(_ sys: DithertronSettings) {
        self.sysparams = sys
    }

    func setSourceImage(_ imageData: [UInt32]) {
        self.sourceImageData = imageData
    }

    func clear() { dithcanv = nil }

    /// Returns false when the iteration has converged or exceeded the iteration cap.
    @discardableResult
    func iterate() -> Bool {
        if dithcanv == nil {
            let sys = sysparams
            let errfn = sys.errfn.fn
            var pal: [UInt32]
            if let custom = sys.customPalette, !custom.isEmpty {
                // User-defined palette wins outright — skip reduce and use as-is.
                pal = custom
            } else {
                pal = sys.pal
                if let reduce = sys.reduce {
                    pal = reducePalette(imageData: sourceImageData,
                                        colors: pal,
                                        count: reduce,
                                        diversity: sys.paletteDiversity,
                                        distfn: errfn)
                }
            }
            if sys.extraColors > 0 {
                pal.append(contentsOf: [UInt32](repeating: 0, count: sys.extraColors))
            }
            let canvas = makeCanvas(named: sys.conv,
                                    img: sourceImageData,
                                    width: sys.width,
                                    pal: pal,
                                    sys: sys)
            canvas.errfn = errfn
            canvas.noise = sys.noise > 0 ? (1 << sys.noise) : 0
            canvas.diffuse = sys.diffuse
            canvas.ordered = sys.ordered
            canvas.ditherfn = DitherKernels.all.first { $0.id == sys.ditherKernelId }?.kernel ?? Kernels.floyd
            canvas.initialize()
            dithcanv = canvas
        }

        guard let canvas = dithcanv else { return false }
        canvas.iterate()
        canvas.noise >>= 1
        if canvas.iterateCount >= Self.temperatureStartIterations {
            canvas.errorThreshold += Self.temperatureStep
        }
        let final = canvas.changes == 0 || canvas.iterateCount > Self.maxIterateCount

        pixelsAvailable?(PixelsAvailableMessage(
            img: canvas.img,
            width: canvas.width,
            height: canvas.height,
            pal: canvas.pal,
            indexed: canvas.indexed,
            final: final,
            iterationCount: canvas.iterateCount
        ))

        return !final
    }
}

private func makeCanvas(named conv: String,
                        img: [UInt32],
                        width: Int,
                        pal: [UInt32],
                        sys: DithertronSettings) -> BaseDitheringCanvas {
    switch conv {
    case "DitheringCanvas":
        return DitheringCanvas(img: img, width: width, pal: pal, sys: sys)
    case "VICIICanvas":
        return VICIICanvas(img: img, width: width, pal: pal, sys: sys)
    case "ZXSpectrumCanvas":
        return ZXSpectrumCanvas(img: img, width: width, pal: pal, sys: sys)
    case "MSXCanvas":
        return MSXCanvas(img: img, width: width, pal: pal, sys: sys)
    case "SNESCanvas":
        return SNESCanvas(img: img, width: width, pal: pal, sys: sys)
    case "Apple2Canvas":
        return Apple2Canvas(img: img, width: width, pal: pal, sys: sys)
    case "NESCanvas":
        return NESCanvas(img: img, width: width, pal: pal, sys: sys)
    case "CompucolorCanvas":
        return CompucolorCanvas(img: img, width: width, pal: pal, sys: sys)
    case "TeletextCanvas":
        return TeletextCanvas(img: img, width: width, pal: pal, sys: sys)
    case "VCSColorPlayfieldCanvas":
        return VCSColorPlayfieldCanvas(img: img, width: width, pal: pal, sys: sys)
    case "HAM6Canvas":
        return HAM6Canvas(img: img, width: width, pal: pal, sys: sys)
    default:
        return DitheringCanvas(img: img, width: width, pal: pal, sys: sys)
    }
}
