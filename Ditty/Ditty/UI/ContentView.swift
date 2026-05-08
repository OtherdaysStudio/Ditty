import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DittyViewModel()
    @StateObject private var purchase = PurchaseManager()
    @StateObject private var camera = CameraSession()

    @State private var showPicker = false
    @State private var editingEffects = false
    @State private var showAppSettings = false
    @State private var showPaywall = false
    @State private var showExportSheet = false
    @State private var showSystemPicker = false
    @State private var showCropEditor = false
    @State private var showSavedToast = false
    @State private var systemBadgeOpacity: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var noCameraFeed = false

    // Persisted preferences shown in the AppSettingsSheet.
    @AppStorage("ditty.saveOriginal") private var saveOriginal: Bool = false
    @AppStorage("ditty.shutterSound") private var shutterSound: Bool = true
    @AppStorage("ditty.showGrid") private var showGrid: Bool = false
    @AppStorage("ditty.savedCount") private var savedCount: Int = 0
    /// When true (default), the dither canvas adapts to the source image's
    /// aspect so portraits display tall and landscapes display wide. When
    /// false, the canvas uses each system's native aspect (more authentic to
    /// the original hardware but crops portrait phone photos).
    @AppStorage("ditty.respectImageRatio") private var respectImageRatio: Bool = true

    /// True when the user is viewing a captured shot or a gallery-uploaded photo
    /// (i.e. not the live camera feed).
    private var isViewingStill: Bool {
        vm.captured || (!vm.liveMode && vm.sourceImage != nil)
    }

    private var orderedSystems: [DithertronSettings] {
        let free = vm.systems.filter { FreeSystems.isFree($0.id) }
        let pro = vm.systems.filter { !FreeSystems.isFree($0.id) }
        return free + pro
    }

    private var currentIndex: Int {
        orderedSystems.firstIndex(where: { $0.id == vm.systemId }) ?? 0
    }

    private var currentSystem: DithertronSettings {
        orderedSystems[safe: currentIndex] ?? orderedSystems[0]
    }

    private var isCurrentLocked: Bool {
        !purchase.isPro && !FreeSystems.isFree(currentSystem.id)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                photoViewport
                    .padding(.horizontal, 20)

                Spacer(minLength: 16)

                if editingEffects {
                    EffectEditor(
                        vm: vm,
                        onCancel: { withAnimation(.easeInOut(duration: 0.2)) { editingEffects = false } },
                        onCommit: { withAnimation(.easeInOut(duration: 0.2)) { editingEffects = false } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    bottomBar
                        .padding(.bottom, 24)
                }
            }

            if showSavedToast {
                Text("Saved to Photos")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .transition(.opacity)
            }

            if camera.permissionDenied {
                permissionScrim
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { vm.setImage($0) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(purchase: purchase)
            }
        }
        .sheet(isPresented: $showAppSettings) {
            AppSettingsSheet(
                purchase: purchase,
                saveOriginal: $saveOriginal,
                showGrid: $showGrid,
                shutterSound: $shutterSound,
                respectImageRatio: $respectImageRatio,
                savedCount: savedCount
            )
        }
        .sheet(isPresented: $showCropEditor) {
            if let src = vm.sourceImage {
                CropEditorSheet(
                    source: src,
                    canvasAspect: max(1, CGFloat(vm.canvasWidth)) / max(1, CGFloat(vm.canvasHeight)),
                    initialRect: vm.cropRect,
                    onCommit: { vm.cropRect = $0 },
                    onClear: { vm.cropRect = nil }
                )
            }
        }
        .sheet(isPresented: $showSystemPicker) {
            SystemPickerSheet(
                systems: orderedSystems,
                currentId: vm.systemId,
                isPro: purchase.isPro,
                isFree: { FreeSystems.isFree($0) },
                onPick: { sys in vm.systemId = sys.id },
                onLockedPick: { showPaywall = true }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showExportSheet) {
            ExportOptionsSheet(image: vm.previewImage) { aspect in
                showExportSheet = false
                guard let img = vm.previewImage,
                      let rendered = ExportRenderer.render(img, aspect: aspect)
                else { return }
                UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                savedCount += 1
                showToast()
            }
            .presentationDetents([.medium])
        }
        .task {
            vm.respectImageRatio = respectImageRatio
            await purchase.bootstrap()

            #if DEBUG
            // Debug-only helpers used by tests and ad-hoc QA. Compiled out of
            // Release builds so launch arguments can't influence the shipped app.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-PreloadSample"),
               let url = Bundle.main.url(forResource: "parrot", withExtension: "jpg",
                                         subdirectory: "Sample.bundle"),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                vm.setImage(img)
            }
            if args.contains("-OpenExport") {
                try? await Task.sleep(nanoseconds: 800_000_000)
                showExportSheet = true
            }
            if args.contains("-OpenEditor") {
                try? await Task.sleep(nanoseconds: 600_000_000)
                editingEffects = true
            }
            let disableCamera = args.contains("-DisableCamera")
            #else
            let disableCamera = false
            #endif

            if !disableCamera {
                camera.start()
                // If we report "running" but never receive a frame within 2.5s,
                // the host (e.g. iOS Simulator) probably has no camera. Surface a hint.
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if vm.previewImage == nil {
                    noCameraFeed = true
                }
            } else {
                noCameraFeed = true
            }
        }
        .onReceive(camera.$frame.compactMap { $0 }) { image in
            noCameraFeed = false
            // Pass through the matching full-res frame so save-original gets
            // the highest fidelity available.
            vm.ingestLiveFrame(image, fullRes: camera.fullResFrame)
        }
        .onChange(of: respectImageRatio) { newValue in
            vm.respectImageRatio = newValue
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            // Top-left: gallery-add by default; becomes a back arrow while the
            // user is viewing a captured/uploaded still.
            CircleIconButton(
                iconAsset: isViewingStill ? "icon-back" : "icon-gallery-add",
                accessibilityLabel: isViewingStill ? "Back to camera" : "Upload from gallery"
            ) {
                if isViewingStill {
                    vm.resumeLive()
                    vm.sourceImage = nil
                } else {
                    showPicker = true
                }
            }

            Spacer()
            Text("DITTY")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Color.black.opacity(0.4))
            Spacer()

            // Top-right: app settings (subscription, Pro features, prefs).
            CircleIconButton(
                iconAsset: "icon-settings",
                accessibilityLabel: "Settings"
            ) {
                showAppSettings = true
            }
        }
    }

    // MARK: - Photo viewport (live preview + swipe)

    private var photoViewport: some View {
        GeometryReader { geo in
            ZStack {
                // Outline matches the original Figma design — soft gray stroke,
                // no black mat behind the image. The viewport's outer
                // .aspectRatio reserves layout space; the image inside fits to
                // that frame.
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(white: 0.85), lineWidth: 1)

                Group {
                    if let img = vm.previewImage {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(8)
                    } else if camera.isRunning && !noCameraFeed {
                        ProgressView()
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: noCameraFeed ? "camera.fill.badge.ellipsis" : "camera.viewfinder")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.black.opacity(0.4))
                            Text(noCameraFeed
                                 ? "No camera feed.\nTap the gallery icon to pick a photo."
                                 : "Starting camera…")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .padding(.horizontal, 16)
                        }
                    }
                }

                if showGrid {
                    GridOverlay()
                        .padding(8)
                        .allowsHitTesting(false)
                }

                // Floating "Crop" pill — visible only when viewing a still.
                if isViewingStill {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button { showCropEditor = true } label: {
                                Label(vm.cropRect == nil ? "Crop" : "Crop ✓",
                                      systemImage: "crop")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                        }
                    }
                }

                if isCurrentLocked, vm.previewImage != nil {
                    lockOverlay
                }

                if systemBadgeOpacity > 0 {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text(currentSystem.name)
                                .font(.headline.weight(.semibold))
                            Text("·")
                            Text("\(currentIndex + 1) of \(orderedSystems.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.bottom, 16)
                    }
                    .opacity(systemBadgeOpacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .gesture(swipeGesture)
            .onLongPressGesture(minimumDuration: 0.45) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showSystemPicker = true
            }
        }
        .aspectRatio(400.0/640.0, contentMode: .fit)
    }

    private var lockOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(currentSystem.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Button {
                    showPaywall = true
                } label: {
                    Text("Unlock")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
            .padding()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Swipe gesture (system switcher)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width
                if systemBadgeOpacity == 0 {
                    withAnimation(.easeOut(duration: 0.15)) { systemBadgeOpacity = 1 }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width <= -threshold {
                    advance(by: 1)
                } else if value.translation.width >= threshold {
                    advance(by: -1)
                }
                dragOffset = 0
                withAnimation(.easeIn(duration: 0.6).delay(0.4)) {
                    systemBadgeOpacity = 0
                }
            }
    }

    private func advance(by step: Int) {
        let next = (currentIndex + step + orderedSystems.count) % orderedSystems.count
        let id = orderedSystems[next].id
        vm.systemId = id
        // System changed — if we're on a captured photo, re-converge against it.
        if vm.captured, vm.sourceImage != nil { /* didSet on systemId already triggers restart */ }
        withAnimation(.easeOut(duration: 0.15)) { systemBadgeOpacity = 1 }
        withAnimation(.easeIn(duration: 0.6).delay(0.6)) { systemBadgeOpacity = 0 }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 36) {
            // Bottom-left: FX → opens the inline effect editor.
            CapsuleIconButton(
                iconAsset: "icon-fx",
                size: 64,
                accessibilityLabel: "Effects"
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    editingEffects = true
                }
            }

            // Center: shutter when live, save when viewing a still.
            ShutterButton(
                mode: isViewingStill ? .save : .capture,
                accessibilityLabel: isViewingStill ? "Save" : "Capture"
            ) {
                if isViewingStill {
                    if isCurrentLocked { showPaywall = true; return }
                    guard vm.previewImage != nil else { return }
                    showExportSheet = true
                } else {
                    // Capture the live frame. If the user opted in to "Save
                    // original", write the full-res camera frame to Photos
                    // immediately at capture time (not at export) — they get
                    // the un-dithered shot the moment they shoot.
                    if saveOriginal, let original = camera.fullResFrame {
                        UIImageWriteToSavedPhotosAlbum(original, nil, nil, nil)
                    }
                    vm.captureCurrentFrame(highRes: camera.fullResFrame)
                }
            }

            // Bottom-right: face/sticker → switch front/back camera.
            CapsuleIconButton(
                iconAsset: "icon-gallery", // sticker-smile asset
                size: 64,
                accessibilityLabel: "Switch camera"
            ) { camera.toggleCamera() }
        }
    }

    // MARK: - Permission scrim

    private var permissionScrim: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                Text("Camera access denied")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Enable camera access in Settings to use Ditty live, or pick from your gallery.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 40)
                Button("Pick from Gallery") { showPicker = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 8)
            }
        }
    }

    private func showToast() {
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { showSavedToast = false }
        }
    }
}

// MARK: - Buttons

// MARK: - Figma button chrome
//
// Layered look from the Figma spec:
//   • Background fill: linear gradient #F4F4F4 → #FEFEFE
//   • Border: linear gradient #FFFFFF → #ECECEC, ~1pt
//   • Drop shadows (stacked, top to bottom in design layers):
//       0 / 0     blur 0     spread 3     #F2F2F2     (inner ring halo)
//       0 / 0.67  blur 2.7   spread 0.67  #000 12%
//       0 / 2.02  blur 2.19  spread -1.01 #000 25%    (sharper bottom edge)
//       0 / 0     blur 0.17  spread 0.51  #000 5%
//       0 / 0     blur 0.17  spread 0.17  #000 7%
private struct DittyButtonChrome: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0xF4/255, green: 0xF4/255, blue: 0xF4/255),
                                 Color(red: 0xFE/255, green: 0xFE/255, blue: 0xFE/255)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white,
                                         Color(red: 0xEC/255, green: 0xEC/255, blue: 0xEC/255)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF2/255), radius: 0, x: 0, y: 0)
                .shadow(color: .black.opacity(0.12), radius: 1.35, x: 0, y: 0.67)
                .shadow(color: .black.opacity(0.25), radius: 1.10, x: 0, y: 2.02)
                .shadow(color: .black.opacity(0.05), radius: 0.085, x: 0, y: 0)
                .shadow(color: .black.opacity(0.07), radius: 0.085, x: 0, y: 0)
        }
        .frame(width: size, height: size)
    }
}

private struct CircleIconButton: View {
    let iconAsset: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                DittyButtonChrome(size: 50)
                Image(iconAsset)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityLabel)
    }
}

private struct CapsuleIconButton: View {
    let iconAsset: String
    let size: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                DittyButtonChrome(size: size)
                Image(iconAsset)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .accessibilityHidden(true)
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityLabel)
    }
}

private struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width, h = geo.size.height
                p.move(to: CGPoint(x: w / 3, y: 0));        p.addLine(to: CGPoint(x: w / 3, y: h))
                p.move(to: CGPoint(x: 2 * w / 3, y: 0));    p.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                p.move(to: CGPoint(x: 0, y: h / 3));        p.addLine(to: CGPoint(x: w, y: h / 3))
                p.move(to: CGPoint(x: 0, y: 2 * h / 3));    p.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        }
    }
}

private struct ShutterButton: View {
    enum Mode { case capture, save }
    let mode: Mode
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.black)
                    // Same shadow stack scaled for the dark shutter — keeps the
                    // tactile feel consistent with the lighter chrome buttons.
                    .shadow(color: .black.opacity(0.12), radius: 1.35, x: 0, y: 0.67)
                    .shadow(color: .black.opacity(0.25), radius: 1.10, x: 0, y: 2.02)
                Image(mode == .save ? "icon-save" : "icon-shutter")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 84, height: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityLabel)
    }
}

// MARK: - Export options sheet

struct ExportOptionsSheet: View {
    let image: UIImage?
    let onChoose: (ExportAspect) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("The image is center-cropped to fit the chosen aspect — no padding bars.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(ExportAspect.allCases) { aspect in
                            Button { onChoose(aspect) } label: {
                                AspectShapeCard(aspect: aspect, sourceImage: image)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }

                Spacer()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct AspectShapeCard: View {
    let aspect: ExportAspect
    let sourceImage: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            // Shape-only preview: a rectangle whose proportions match the chosen
            // aspect. We deliberately don't render the image — it confused users
            // because every cropped preview looked similar at thumbnail size.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: cardWidth, height: cardHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(white: 0.88), lineWidth: 1)
                )
                .overlay(
                    Text(dimensionsLabel)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                )
                .frame(width: 144, height: 200, alignment: .center) // pad each card to a uniform footprint

            Text(aspect.displayName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 144)
        }
    }

    /// Resolved aspect for this card, falling back to the source's aspect for `.original`.
    private var ratio: CGFloat {
        if let r = aspect.ratio { return r }
        guard let img = sourceImage else { return 1 }
        let w = max(1, img.size.width)
        let h = max(1, img.size.height)
        return w / h
    }

    /// Cap the card to a 144×180 box and pick the side that fills it.
    private var cardWidth: CGFloat {
        ratio >= 1 ? 144 : 180 * ratio
    }
    private var cardHeight: CGFloat {
        ratio >= 1 ? 144 / ratio : 180
    }

    private var dimensionsLabel: String {
        switch aspect {
        case .original:        return "—"
        case .square:          return "1 : 1"
        case .portrait4x5:     return "4 : 5"
        case .portrait2x3:     return "4 : 6"
        case .portrait9x16:    return "9 : 16"
        case .landscape3x2:    return "3 : 2"
        case .landscape16x9:   return "16 : 9"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview {
    ContentView()
}
