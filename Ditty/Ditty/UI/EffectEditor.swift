import SwiftUI
import UIKit

/// Inline edit panel that replaces the bottom bar (gallery / shutter / FX) when
/// the user taps the Settings icon. Modeled after the iPhone Photos editor:
/// the photo viewport stays uncovered while the user scrubs values.
///
/// Layout, top to bottom:
///   • Parameter label + numeric value
///   • Horizontal tick scrubber (or kernel chip strip when "Kernel" is active)
///   • Pill row to switch which parameter is active
///   • X (cancel/restore) on the left, ✓ (commit) on the right
struct EffectEditor: View {
    @ObservedObject var vm: DittyViewModel
    let onCancel: () -> Void
    let onCommit: () -> Void

    @State private var activeParam: FXParam = .diffuse

    /// Snapshot taken on appear. If the user taps X we restore these values.
    @State private var snapshot: Snapshot?

    private var supportedParams: [FXParam] {
        let supported = vm.currentSystem().supportedFXParams
        return FXParam.allCases.filter { supported.contains($0) }
    }

    private func paramTitle(_ p: FXParam) -> String {
        switch p {
        case .kernel:    return "Kernel"
        case .diffuse:   return "Diffuse"
        case .ordered:   return "Ordered"
        case .noise:     return "Noise"
        case .diversity: return "Diversity"
        case .palette:   return "Palette"
        }
    }

    private struct Snapshot {
        let kernel: String
        let diffuse: Double
        let ordered: Double
        let noise: Int
        let diversity: Double
    }

    var body: some View {
        VStack(spacing: 18) {
            valueRow

            switch activeParam {
            case .kernel:
                kernelChips
                    .frame(height: 56)
            case .palette:
                paletteSwatches
                    .frame(height: 56)
            default:
                TickScrubber(
                    value: scrubberBinding,
                    range: scrubberRange,
                    centerReference: scrubberCenter
                )
                .frame(height: 56)
            }

            paramPills

            actionRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            if snapshot == nil {
                snapshot = Snapshot(
                    kernel: vm.ditherKernelId,
                    diffuse: vm.diffuse,
                    ordered: vm.ordered,
                    noise: vm.noise,
                    diversity: vm.paletteDiversity
                )
            }
            // If the previously active param isn't supported by this system,
            // fall back to the first one that is.
            if !supportedParams.contains(activeParam),
               let first = supportedParams.first {
                activeParam = first
            }
        }
    }

    // MARK: - Value display

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(paramTitle(activeParam))
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text(formattedValue)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var formattedValue: String {
        switch activeParam {
        case .kernel:
            return vm.kernels.first(where: { $0.id == vm.ditherKernelId })?.name ?? vm.ditherKernelId
        case .diffuse:   return String(format: "%.2f", vm.diffuse)
        case .ordered:   return String(format: "%.2f", vm.ordered)
        case .noise:     return "\(vm.noise)"
        case .diversity: return String(format: "%.2f", vm.paletteDiversity)
        case .palette:   return "\(vm.activePalette.count) colors"
        }
    }

    // MARK: - Scrubber binding

    private var scrubberBinding: Binding<Double> {
        switch activeParam {
        case .diffuse:
            return Binding(get: { vm.diffuse }, set: { vm.diffuse = $0 })
        case .ordered:
            return Binding(get: { vm.ordered }, set: { vm.ordered = $0 })
        case .noise:
            return Binding(get: { Double(vm.noise) }, set: { vm.noise = Int($0.rounded()) })
        case .diversity:
            return Binding(get: { vm.paletteDiversity }, set: { vm.paletteDiversity = $0 })
        case .kernel, .palette:
            return .constant(0)
        }
    }

    private var scrubberRange: ClosedRange<Double> {
        switch activeParam {
        case .diffuse:           return 0...1.5
        case .ordered:           return 0...1
        case .noise:             return 0...8
        case .diversity:         return 0...2
        case .kernel, .palette:  return 0...1
        }
    }

    /// The "0" reference line that the marker triangle sits over by default.
    private var scrubberCenter: Double {
        switch activeParam {
        case .diffuse:           return 0.8   // engine default
        case .ordered:           return 0
        case .noise:             return 0
        case .diversity:         return 0
        case .kernel, .palette:  return 0
        }
    }

    // MARK: - Kernel chips

    private var kernelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.kernels) { k in
                    let active = vm.ditherKernelId == k.id
                    Button {
                        vm.ditherKernelId = k.id
                    } label: {
                        Text(k.name)
                            .font(.footnote.weight(active ? .semibold : .regular))
                            .foregroundStyle(active ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(active ? Color.white : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Palette presets

    private var paletteSwatches: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // "Auto" / system default first.
                    paletteCard(
                        title: "Auto",
                        colors: vm.customPalette == nil ? vm.activePalette : Array(vm.activePalette.prefix(8)),
                        active: vm.customPalette == nil
                    ) {
                        vm.resetCustomPalette()
                    }
                    ForEach(PalettePresets.all) { preset in
                        let active = paletteMatchesPreset(preset)
                        paletteCard(
                            title: preset.name,
                            colors: preset.colors,
                            active: active
                        ) {
                            vm.customPalette = preset.colors
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            Text(vm.customPalette == nil
                 ? "Tap a preset to apply a custom palette"
                 : "Custom palette active — tap Auto to reset")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func paletteCard(title: String,
                             colors: [UInt32],
                             active: Bool,
                             onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(Array(colors.prefix(8).enumerated()), id: \.offset) { _, c in
                        Rectangle()
                            .fill(swiftUIColor(from: c))
                            .frame(width: 8, height: 18)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(active ? Color(red: 0.99, green: 0.78, blue: 0.27)
                                              : Color.white.opacity(0.18),
                                      lineWidth: active ? 2 : 1)
                )
                Text(title)
                    .font(.caption2.weight(active ? .bold : .regular))
                    .foregroundStyle(active ? .white : .white.opacity(0.7))
            }
            .padding(6)
            .background(active ? Color.white.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func paletteMatchesPreset(_ preset: PalettePreset) -> Bool {
        guard let custom = vm.customPalette else { return false }
        return custom == preset.colors
    }

    // MARK: - Color helpers

    private func swiftUIColor(from rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 0) & 0xff) / 255,
              green: Double((rgb >> 8) & 0xff) / 255,
              blue: Double((rgb >> 16) & 0xff) / 255)
    }

    // MARK: - Param pill row

    private var paramPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(supportedParams, id: \.self) { p in
                    let active = activeParam == p
                    Button { activeParam = p } label: {
                        Text(paramTitle(p))
                            .font(.system(.footnote, design: .monospaced).weight(active ? .bold : .regular))
                            .tracking(0.5)
                            .foregroundStyle(active ? .black : .white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(active ? Color.white : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - X / ✓

    private var actionRow: some View {
        HStack {
            Button { restoreAndCancel() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 44)
            }
            .accessibilityLabel("Cancel edits")
            .accessibilityIdentifier("Cancel edits")

            Spacer()

            Button { onCommit() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                    .frame(width: 56, height: 44)
            }
            .accessibilityLabel("Done editing")
            .accessibilityIdentifier("Done editing")
        }
    }

    private func restoreAndCancel() {
        if let s = snapshot {
            vm.ditherKernelId = s.kernel
            vm.diffuse = s.diffuse
            vm.ordered = s.ordered
            vm.noise = s.noise
            vm.paletteDiversity = s.diversity
        }
        onCancel()
    }
}

// MARK: - Tick scrubber

/// Horizontal tick row with a fixed-center marker. Dragging horizontally scrubs
/// the bound value across `range`. Tens are taller than ones for an analog feel.
struct TickScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Reference value highlighted by a brighter tick (Apple uses this for "0"/default).
    let centerReference: Double

    @State private var dragStartValue: Double?

    private let totalTicks: Int = 81
    private let tickSpacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let activeFloat = progress * Double(totalTicks - 1)
            let centerFloat = Double(totalTicks - 1) / 2.0
            // ZStack centers a child by default. To put the value's tick at the
            // horizontal center, shift the centered HStack by (center - active) ticks.
            let rowOffsetX = CGFloat(centerFloat - activeFloat) * tickSpacing

            ZStack {
                HStack(spacing: 0) {
                    ForEach(0..<totalTicks, id: \.self) { i in
                        Rectangle()
                            .fill(tickColor(at: i, currentProgress: progress))
                            .frame(width: 2, height: tickHeight(at: i))
                            .frame(width: tickSpacing)
                    }
                }
                .offset(x: rowOffsetX)

                Triangle()
                    .fill(Color(red: 0.99, green: 0.78, blue: 0.27))
                    .frame(width: 10, height: 8)
                    .offset(y: -16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragStartValue == nil { dragStartValue = value }
                        let trackWidth = CGFloat(totalTicks - 1) * tickSpacing
                        let pixelsPerUnit = trackWidth / CGFloat(range.upperBound - range.lowerBound)
                        // Drag right → ticks slide right under the marker → marker
                        // sees lower-valued ticks, so value DECREASES.
                        let delta = -g.translation.width / pixelsPerUnit
                        let proposed = (dragStartValue ?? value) + Double(delta)
                        value = min(range.upperBound, max(range.lowerBound, proposed))
                        _ = geo // silence unused warning
                    }
                    .onEnded { _ in dragStartValue = nil }
            )
        }
    }

    private func tickHeight(at i: Int) -> CGFloat {
        let isMajor = i % 10 == 0
        return isMajor ? 22 : 12
    }

    private func tickColor(at i: Int, currentProgress: Double) -> Color {
        let p = currentProgress.isFinite ? min(1, max(0, currentProgress)) : 0
        let activeIndex = Int((p * Double(totalTicks - 1)).rounded())
        if i == activeIndex {
            return Color(red: 0.99, green: 0.78, blue: 0.27)  // gold
        }
        return Color.white.opacity(i % 10 == 0 ? 0.45 : 0.22)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
