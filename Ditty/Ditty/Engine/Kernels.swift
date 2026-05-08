import Foundation

typealias DitherKernel = [[Double]]

enum Kernels {
    static let floyd: DitherKernel = [
        [1, 0, 7.0/16.0], [-1, 1, 3.0/16.0], [0, 1, 5.0/16.0], [1, 1, 1.0/16.0]
    ]
    static let falseFloyd: DitherKernel = [
        [1, 0, 3.0/8.0], [0, 1, 3.0/8.0], [1, 1, 2.0/8.0]
    ]
    static let atkinson: DitherKernel = [
        [1, 0, 1.0/6.0], [2, 0, 1.0/6.0],
        [-1, 1, 1.0/6.0], [0, 1, 1.0/6.0], [1, 1, 1.0/6.0],
        [0, 2, 1.0/6.0]
    ]
    static let sierra2: DitherKernel = [
        [1, 0, 4.0/16.0], [2, 0, 3.0/16.0],
        [-2, 1, 1.0/16.0], [-1, 1, 2.0/16.0], [0, 1, 3.0/16.0], [1, 1, 2.0/16.0], [2, 1, 1.0/16.0]
    ]
    static let sierraLite: DitherKernel = [
        [1, 0, 2.0/4.0], [-1, 1, 1.0/4.0], [0, 1, 1.0/4.0]
    ]
    static let stucki: DitherKernel = [
        [1, 0, 8.0/42.0], [2, 0, 4.0/42.0],
        [-2, 1, 2.0/42.0], [1, -1, 4.0/42.0], [0, 1, 8.0/42.0], [1, 1, 4.0/42.0], [2, 1, 2.0/42.0],
        [-2, 2, 1.0/42.0], [-1, 2, 2.0/42.0], [0, 2, 4.0/42.0], [1, 2, 2.0/42.0], [2, 2, 1.0/42.0]
    ]
    static let twoD: DitherKernel = [[1, 0, 0.5], [0, 1, 0.5]]
    static let right: DitherKernel = [[1, 0, 1.0]]
    static let down: DitherKernel = [[0, 1, 1.0]]
    static let doubleDown: DitherKernel = [[0, 1, 2.0/4.0], [0, 2, 1.0/4.0], [1, 2, 1.0/4.0]]
    static let diag: DitherKernel = [[1, 1, 1.0]]
    static let vDiamond: DitherKernel = [
        [0, 1, 6.0/16.0], [-1, 1, 3.0/16.0], [1, 1, 3.0/16.0],
        [-2, 2, 1.0/16.0], [0, 2, 2.0/16.0], [2, 2, 1.0/16.0]
    ]
}

struct DitherSettingDef: Identifiable, Hashable {
    let id: String
    let name: String
    let kernel: DitherKernel
    static func == (a: DitherSettingDef, b: DitherSettingDef) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DitherKernels {
    static let all: [DitherSettingDef] = [
        DitherSettingDef(id: "floyd", name: "Floyd-Steinberg", kernel: Kernels.floyd),
        DitherSettingDef(id: "falseFloyd", name: "False Floyd-Steinberg", kernel: Kernels.falseFloyd),
        DitherSettingDef(id: "atkinson", name: "Atkinson", kernel: Kernels.atkinson),
        DitherSettingDef(id: "sierra2", name: "Sierra 2 Row", kernel: Kernels.sierra2),
        DitherSettingDef(id: "sierraLite", name: "Sierra Lite", kernel: Kernels.sierraLite),
        DitherSettingDef(id: "stucki", name: "Stucki", kernel: Kernels.stucki),
        DitherSettingDef(id: "twoD", name: "2D Average", kernel: Kernels.twoD),
        DitherSettingDef(id: "right", name: "Right Only", kernel: Kernels.right),
        DitherSettingDef(id: "down", name: "Down Only", kernel: Kernels.down),
        DitherSettingDef(id: "doubleDown", name: "Double Down", kernel: Kernels.doubleDown),
        DitherSettingDef(id: "diag", name: "Diagonal", kernel: Kernels.diag),
        DitherSettingDef(id: "vDiamond", name: "Vertical Diamond", kernel: Kernels.vDiamond),
    ]
}
