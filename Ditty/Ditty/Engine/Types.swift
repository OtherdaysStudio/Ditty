import Foundation

struct PaletteRange: Hashable {
    var min: Int
    var max: Int
}

struct PaletteChoices {
    var prefillReference: Bool = false
    var background: Bool = false
    var aux: Bool = false
    var border: Bool = false
    var colors: Int = 0
    var backgroundRange: PaletteRange = PaletteRange(min: 0, max: 0)
    var auxRange: PaletteRange = PaletteRange(min: 0, max: 0)
    var borderRange: PaletteRange = PaletteRange(min: 0, max: 0)
    var colorsRange: PaletteRange = PaletteRange(min: 0, max: 0)
}

struct PartialPaletteChoices {
    var prefillReference: Bool? = nil
    var background: Bool? = nil
    var aux: Bool? = nil
    var border: Bool? = nil
    var colors: Int? = nil
    var backgroundRange: PaletteRange? = nil
    var auxRange: PaletteRange? = nil
    var borderRange: PaletteRange? = nil
    var colorsRange: PaletteRange? = nil
}

struct BlockSpec {
    var w: Int
    var h: Int
    var colors: Int = 2
    var xb: Int = 0
    var yb: Int = 0
    var msbToLsb: Bool = true
}

struct CellSpec {
    var w: Int
    var h: Int
    var msbToLsb: Bool = true
    var xb: Int? = nil
    var yb: Int? = nil
}

struct CbSpec {
    var w: Int
    var h: Int
    var xb: Int? = nil
    var yb: Int? = nil
    var msbToLsb: Bool = true
}

struct ParamSpec {
    var block: Bool? = nil
    var cb: Bool? = nil
    var cell: Bool = false
    var extra: Int = 0
}

struct FliSpec {
    var bug: Bool
    var blankLeft: Bool
    var blankRight: Bool
    var blankColumns: Int
}

struct DithertronSettings: Identifiable, Hashable {
    let id: String
    let name: String
    /// Mutable so callers can override the canvas to match a source image's
    /// aspect ratio (the "respect image ratio" mode in settings).
    var width: Int
    var height: Int
    let conv: String
    let pal: [UInt32]

    var scaleX: Double = 1.0
    var errfn: ErrorFunctionKind = .perceptual
    var reduce: Int? = nil
    var extraColors: Int = 0
    var diffuse: Double = 0.8
    var ordered: Double = 0.0
    var noise: Int = 0
    var paletteDiversity: Double = 0.0
    var ditherKernelId: String = "floyd"

    var block: BlockSpec? = nil
    var cell: CellSpec? = nil
    var cb: CbSpec? = nil
    var paletteChoices: PartialPaletteChoices? = nil
    var param: ParamSpec? = nil
    var fli: FliSpec? = nil
    var customize: [String: Any]? = nil

    /// User-defined palette that overrides the system's default and skips the
    /// `reduce` step. Set per-frame from the viewmodel's `customPalette`.
    var customPalette: [UInt32]? = nil

    static func == (lhs: DithertronSettings, rhs: DithertronSettings) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Which effect-editor parameters meaningfully affect this system. Mirrors
    /// the per-system option visibility from the original dithertron web UI:
    /// systems with a fixed/built-in palette don't expose `diversity`, and a
    /// few systems (e.g. Bally Astrocade in the original) constrain the set
    /// further.
    var supportedFXParams: Set<FXParam> {
        switch id {
        case "astrocade":
            return [.diversity, .diffuse, .ordered]
        default:
            break
        }
        // Default: kernel, diffuse, ordered. Diversity only when the system
        // reduces its palette. Noise + palette are deliberately excluded —
        // both confused more than they helped in user testing.
        var s: Set<FXParam> = [.kernel, .diffuse, .ordered]
        if reduce != nil { s.insert(.diversity) }
        return s
    }
}

/// Identifiers for the effect-editor parameter pills. Lives in the engine layer
/// so per-system support sets can reference them without importing the UI.
enum FXParam: String, CaseIterable, Hashable {
    case kernel
    case diffuse
    case ordered
    case noise
    case diversity
    case palette
}

struct PixelsAvailableMessage {
    let img: [UInt32]
    let width: Int
    let height: Int
    let pal: [UInt32]
    let indexed: [Int]
    let final: Bool
    let iterationCount: Int
}
