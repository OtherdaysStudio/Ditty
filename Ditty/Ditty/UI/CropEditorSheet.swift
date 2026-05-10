import SwiftUI

/// Manual crop sheet. Lets the user position a viewfinder rectangle (in the
/// system canvas's aspect ratio) over the source image to choose what gets
/// dithered. The viewfinder size matches the largest rect of the canvas
/// aspect that fits inside the source — only its position is adjustable.
struct CropEditorSheet: View {
    let source: UIImage
    /// Canvas aspect ratio (width / height). The crop rect uses this aspect.
    let canvasAspect: CGFloat
    /// Initial normalized rect (0...1 in source coords). nil = fully fitted.
    let initialRect: CGRect?
    /// Callback when the user commits a new crop. Rect is normalized 0...1
    /// in source-image coordinates.
    let onCommit: (CGRect) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Stored normalized rect (0...1 in source coords).
    @State private var normalizedRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// Snapshot at gesture start so deltas don't accumulate as the user drags.
    @State private var dragStart: CGRect?
    /// Snapshot at the start of a pinch so scale deltas don't compound.
    @State private var pinchStart: CGRect?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let imgAspect = source.size.width / max(1, source.size.height)
                // Layout the source so it fits the available area.
                let layout = fitFrame(containerSize: geo.size, aspect: imgAspect)
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: source)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: layout.size.width, height: layout.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    cropOverlay(displayFrame: layout, sourceSize: source.size)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Recompose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("Cancel").foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onCommit(normalizedRect)
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                            .font(.body.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        onClear()
                        dismiss()
                    } label: {
                        Text("Reset to auto")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .onAppear {
                if let initial = initialRect { normalizedRect = initial }
                else { normalizedRect = defaultRect() }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Crop overlay

    private func cropOverlay(displayFrame: CGRect, sourceSize: CGSize) -> some View {
        // The crop rect's display frame within the displayed image.
        let imgW = displayFrame.size.width
        let imgH = displayFrame.size.height
        let rectW = imgW * normalizedRect.width
        let rectH = imgH * normalizedRect.height
        let rectX = imgW * normalizedRect.minX - imgW / 2 + rectW / 2
        let rectY = imgH * normalizedRect.minY - imgH / 2 + rectH / 2

        return ZStack {
            // Dim layer with rectangle "cut out" via alpha.
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: imgW, height: imgH)
                .mask(
                    Rectangle()
                        .frame(width: imgW, height: imgH)
                        .overlay(
                            Rectangle()
                                .frame(width: rectW, height: rectH)
                                .blendMode(.destinationOut)
                                .offset(x: rectX, y: rectY)
                        )
                )
                .allowsHitTesting(false)

            // Inner draggable area + visible stroke. The whole interior
            // accepts gestures (drag to reposition, pinch to resize). The
            // stroke is purely cosmetic on top.
            ZStack {
                Color.white.opacity(0.001) // tappable transparent fill
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
                    .allowsHitTesting(false)
                // Rule-of-thirds guides — fade in only while the user is
                // actively dragging or pinching.
                if dragStart != nil || pinchStart != nil {
                    Path { p in
                        p.move(to: CGPoint(x: rectW / 3, y: 0))
                        p.addLine(to: CGPoint(x: rectW / 3, y: rectH))
                        p.move(to: CGPoint(x: 2 * rectW / 3, y: 0))
                        p.addLine(to: CGPoint(x: 2 * rectW / 3, y: rectH))
                        p.move(to: CGPoint(x: 0, y: rectH / 3))
                        p.addLine(to: CGPoint(x: rectW, y: rectH / 3))
                        p.move(to: CGPoint(x: 0, y: 2 * rectH / 3))
                        p.addLine(to: CGPoint(x: rectW, y: 2 * rectH / 3))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: rectW, height: rectH)
            .offset(x: rectX, y: rectY)
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if dragStart == nil { dragStart = normalizedRect }
                            let start = dragStart ?? normalizedRect
                            let dx = g.translation.width / imgW
                            let dy = g.translation.height / imgH
                            let newX = max(0, min(1 - start.width, start.minX + dx))
                            let newY = max(0, min(1 - start.height, start.minY + dy))
                            normalizedRect = CGRect(
                                x: newX, y: newY,
                                width: start.width,
                                height: start.height
                            )
                        }
                        .onEnded { _ in dragStart = nil },
                    MagnificationGesture()
                        .onChanged { scale in
                            if pinchStart == nil { pinchStart = normalizedRect }
                            let start = pinchStart ?? normalizedRect
                            // Inverse: pinch-out enlarges the crop window
                            // (which means LESS zoom on the subject); most
                            // photo editors do it this way.
                            let factor = max(0.2, min(5, 1 / scale))
                            let newW = max(0.05, min(1, start.width * factor))
                            let newH = max(0.05, min(1, start.height * factor))
                            // Keep the rect's center where it was so the
                            // user's focal subject doesn't slide off-screen.
                            let cx = start.minX + start.width / 2
                            let cy = start.minY + start.height / 2
                            var newX = cx - newW / 2
                            var newY = cy - newH / 2
                            newX = max(0, min(1 - newW, newX))
                            newY = max(0, min(1 - newH, newY))
                            normalizedRect = CGRect(
                                x: newX, y: newY,
                                width: newW, height: newH
                            )
                        }
                        .onEnded { _ in pinchStart = nil }
                )
            )
        }
        .frame(width: imgW, height: imgH)
    }

    // MARK: - Helpers

    private func fitFrame(containerSize: CGSize, aspect: CGFloat) -> CGRect {
        let safe = CGSize(width: containerSize.width - 32, height: containerSize.height - 100)
        let cAspect = safe.width / safe.height
        let size: CGSize
        if aspect > cAspect {
            size = CGSize(width: safe.width, height: safe.width / aspect)
        } else {
            size = CGSize(width: safe.height * aspect, height: safe.height)
        }
        return CGRect(origin: .zero, size: size)
    }

    private func defaultRect() -> CGRect {
        // Largest rect of `canvasAspect` that fits inside source aspect, centered.
        let imgAspect = source.size.width / max(1, source.size.height)
        if canvasAspect >= imgAspect {
            // Rect spans full width, less height.
            let h = imgAspect / canvasAspect
            return CGRect(x: 0, y: (1 - h) / 2, width: 1, height: h)
        } else {
            let w = canvasAspect / imgAspect
            return CGRect(x: (1 - w) / 2, y: 0, width: w, height: 1)
        }
    }
}
