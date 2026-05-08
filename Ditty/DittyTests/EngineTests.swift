import XCTest
import UIKit
@testable import Ditty

final class EngineTests: XCTestCase {

    func testKernelsLoadAllSystems() {
        XCTAssertGreaterThan(Systems.all.count, 20)
        for sys in Systems.all {
            XCTAssertGreaterThan(sys.pal.count, 0, "system \(sys.id) has no palette")
            XCTAssertGreaterThan(sys.width, 0)
            XCTAssertGreaterThan(sys.height, 0)
        }
    }

    func testFreePaletteEngineConverges() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "parrot", withExtension: "jpg", subdirectory: "Sample.bundle")
                ?? bundle.url(forResource: "parrot", withExtension: "jpg") else {
            throw XCTSkip("missing sample image")
        }
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else {
            XCTFail("could not decode sample"); return
        }

        let sys = Systems.lookup["pico8"]!
        guard let prepared = ImageBridge.sourcePixels(from: img, target: sys) else {
            XCTFail("could not prepare pixels"); return
        }
        XCTAssertEqual(prepared.pixels.count, sys.width * sys.height)

        let engine = Dithertron(sysparams: sys)
        engine.setSourceImage(prepared.pixels)
        var iter = 0
        while engine.iterate() {
            iter += 1
            if iter > Dithertron.maxIterateCount + 1 { break }
        }
        // We expect convergence within MAX_ITERATE_COUNT; the inner canvas is held by the engine.
        XCTAssertLessThanOrEqual(iter, Dithertron.maxIterateCount + 1)

        // Validate the indexed buffer references real palette entries
        let canv = engine.dithcanv!
        for i in 0..<min(canv.indexed.count, 100) {
            XCTAssertGreaterThanOrEqual(canv.indexed[i], 0)
            XCTAssertLessThan(canv.indexed[i], canv.pal.count)
        }
    }

    func testC64MultiHasCellConstraints() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "parrot", withExtension: "jpg", subdirectory: "Sample.bundle")
                ?? bundle.url(forResource: "parrot", withExtension: "jpg") else {
            throw XCTSkip("missing sample image")
        }
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else {
            XCTFail("could not decode sample"); return
        }

        let sys = Systems.lookup["c64.multi"]!
        guard let prepared = ImageBridge.sourcePixels(from: img, target: sys) else {
            XCTFail("could not prepare pixels"); return
        }

        let engine = Dithertron(sysparams: sys)
        engine.setSourceImage(prepared.pixels)
        var iter = 0
        while engine.iterate() {
            iter += 1
            if iter > 25 { break }   // C64 takes longer; sample early
        }

        let canv = engine.dithcanv!
        // each 4x8 block should only contain at most 4 distinct palette colors (background + 3 chosen)
        let bw = 4, bh = 8
        for by in 0..<(canv.height / bh) {
            for bx in 0..<(canv.width / bw) {
                var seen = Set<Int>()
                for yy in 0..<bh {
                    for xx in 0..<bw {
                        let idx = (by * bh + yy) * canv.width + (bx * bw + xx)
                        seen.insert(canv.indexed[idx])
                    }
                }
                XCTAssertLessThanOrEqual(seen.count, 4, "block (\(bx),\(by)) has \(seen.count) colors")
            }
        }
    }

    func testZXDebugBlockSelection() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "parrot", withExtension: "jpg") else { throw XCTSkip("missing sample") }
        let data = try Data(contentsOf: url)
        let img = UIImage(data: data)!

        let sys = Systems.lookup["zx"]!
        let prepared = ImageBridge.sourcePixels(from: img, target: sys)!
        // pick a green block - parrot body bottom half
        let blockX = 8, blockY = 18    // pixel coords / 8
        let pxBaseX = blockX * 8
        let pxBaseY = blockY * 8
        var rs = 0, gs = 0, bs = 0
        for y in 0..<8 {
            for x in 0..<8 {
                let p = prepared.pixels[(pxBaseY + y) * sys.width + (pxBaseX + x)]
                rs += Int(p & 0xff)
                gs += Int((p >> 8) & 0xff)
                bs += Int((p >> 16) & 0xff)
            }
        }
        print("Sampled block avg: R=\(rs/64), G=\(gs/64), B=\(bs/64)")

        let engine = Dithertron(sysparams: sys)
        engine.setSourceImage(prepared.pixels)
        _ = engine.iterate()
        let canv = engine.dithcanv as! ZXSpectrumCanvas
        let blockOffset = blockY * canv.block.columns + blockX
        let cols = canv.extractColorsFromBlockParams(blockOffset, 2)
        print("Block (\(blockX),\(blockY)) colors after iter 1: \(cols)")
        for c in cols {
            let p = canv.pal[c]
            print("  \(c): R=\(p & 0xff) G=\((p>>8) & 0xff) B=\((p>>16) & 0xff)")
        }
        // also print darkColors and brightColors closest matches for the block-average pixel
        let avgRGB = UInt32(rs/64) | (UInt32(gs/64) << 8) | (UInt32(bs/64) << 16)
        let closestDark = getClosestRGB(avgRGB, [0,1,2,3,4,5,6,7], canv.pal, canv.errfn)
        let closestBright = getClosestRGB(avgRGB, [8,9,10,11,12,13,14,15], canv.pal, canv.errfn)
        print("Closest dark to avg: \(closestDark)")
        print("Closest bright to avg: \(closestBright)")
    }

    func testRendersDitheredImagesForVisualInspection() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "parrot", withExtension: "jpg") else {
            throw XCTSkip("missing sample image")
        }
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else {
            XCTFail("could not decode sample"); return
        }

        let outDir = "/tmp/ditty-render"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let systemsToCheck = ["pico8", "c64.multi", "zx", "gb", "msx", "apple2.hires", "atarist"]
        for sysId in systemsToCheck {
            guard let sys = Systems.lookup[sysId],
                  let prepared = ImageBridge.sourcePixels(from: img, target: sys) else { continue }
            let engine = Dithertron(sysparams: sys)
            engine.setSourceImage(prepared.pixels)
            var iter = 0
            while engine.iterate() {
                iter += 1
                if iter > Dithertron.maxIterateCount { break }
            }
            let canv = engine.dithcanv!
            guard let cg = ImageBridge.cgImage(fromPixels: canv.img,
                                                width: canv.width,
                                                height: canv.height) else { continue }
            let uiImg = UIImage(cgImage: cg)
            let pngData = uiImg.pngData()!
            let safe = sysId.replacingOccurrences(of: "/", with: "_")
            let path = "\(outDir)/\(safe).png"
            try? pngData.write(to: URL(fileURLWithPath: path))
            print("rendered \(sysId) to \(path) (\(iter) iters)")
        }
    }

    func testZXSpectrumCellConstraint() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "parrot", withExtension: "jpg", subdirectory: "Sample.bundle")
                ?? bundle.url(forResource: "parrot", withExtension: "jpg") else {
            throw XCTSkip("missing sample image")
        }
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else {
            XCTFail("could not decode sample"); return
        }

        let sys = Systems.lookup["zx"]!
        guard let prepared = ImageBridge.sourcePixels(from: img, target: sys) else {
            XCTFail("could not prepare pixels"); return
        }
        let engine = Dithertron(sysparams: sys)
        engine.setSourceImage(prepared.pixels)
        var iter = 0
        while engine.iterate() {
            iter += 1
            if iter > 20 { break }
        }
        let canv = engine.dithcanv!
        // each 8x8 cell should only have at most 2 colors AND both should be in the same brightness half
        for by in 0..<(canv.height / 8) {
            for bx in 0..<(canv.width / 8) {
                var seen = Set<Int>()
                for yy in 0..<8 {
                    for xx in 0..<8 {
                        let idx = (by * 8 + yy) * canv.width + (bx * 8 + xx)
                        seen.insert(canv.indexed[idx])
                    }
                }
                XCTAssertLessThanOrEqual(seen.count, 2, "ZX cell (\(bx),\(by)) has \(seen.count) colors")
                // brightness half check
                let halves = Set(seen.map { $0 < 8 ? 0 : 1 })
                XCTAssertEqual(halves.count, 1, "ZX cell (\(bx),\(by)) mixes brightness halves: \(seen)")
            }
        }
    }
}
