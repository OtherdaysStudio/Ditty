import SwiftUI
import AudioToolbox
import AVFoundation

struct ContentView: View {
    @StateObject private var vm = DittyViewModel()
    @StateObject private var purchase = PurchaseManager()
    @StateObject private var camera = CameraSession()
    @StateObject private var favorites = SystemFavorites()
    @StateObject private var recorder = LoopRecorder()
    @StateObject private var burst = BurstCapture()

    @State private var showPicker = false
    @State private var editingEffects = false
    @State private var showAppSettings = false
    @State private var showPaywall = false
    @State private var showExportSheet = false
    @State private var showSystemPicker = false
    @State private var showSampleLibrary = false
    @State private var showCropEditor = false
    @State private var shutterFlash: Bool = false
    @State private var viewportScale: CGFloat = 1.0
    @State private var shareItem: UIImage? = nil
    @State private var recordedGIFURL: URL? = nil
    @State private var showSavedToast = false
    @State private var systemBadgeOpacity: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var noCameraFeed = false

    // Live-camera gestures: pinch zoom + tap-to-focus.
    @State private var zoomFactor: CGFloat = 1.0
    @State private var pinchStartZoom: CGFloat? = nil
    @State private var focusRing: FocusRingState? = nil

    private struct FocusRingState: Identifiable, Equatable {
        let id = UUID()
        let position: CGPoint
        let createdAt: Date = .init()
    }

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
    /// Stamp every export with a small "DITTY · <system>" tag. Free users have
    /// this forced on; Pro users can toggle it off in Settings.
    @AppStorage("ditty.watermark") private var watermarkEnabled: Bool = true
    @AppStorage("ditty.didShowOnboarding") private var didShowOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

    /// True when the user is viewing a captured shot or a gallery-uploaded photo
    /// (i.e. not the live camera feed).
    private var isViewingStill: Bool {
        vm.captured || (!vm.liveMode && vm.sourceImage != nil)
    }

    private var orderedSystems: [DithertronSettings] {
        // Favorites float to the very front, then free systems, then pro.
        let favs = vm.systems.filter { favorites.contains($0.id) }
        let nonFav = vm.systems.filter { !favorites.contains($0.id) }
        let free = nonFav.filter { FreeSystems.isFree($0.id) }
        let pro = nonFav.filter { !FreeSystems.isFree($0.id) }
        return favs + free + pro
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
                    .scaleEffect(viewportScale)

                systemPicker
                    .padding(.top, 12)

                Spacer(minLength: 12)

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

            // Shutter flash — full-screen white veneer that fades in fast,
            // out a touch slower, mimicking a physical shutter's blink.
            if shutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if showOnboarding {
                OnboardingOverlay(isPresented: $showOnboarding)
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
                presetStore: vm.presetStore,
                paletteStore: vm.paletteStore,
                saveOriginal: $saveOriginal,
                showGrid: $showGrid,
                shutterSound: $shutterSound,
                respectImageRatio: $respectImageRatio,
                watermarkEnabled: $watermarkEnabled,
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
        .sheet(isPresented: $showSampleLibrary) {
            SampleLibrarySheet { vm.setImage($0) }
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
                guard let img = vm.previewImage else { return }
                // Free users always get the watermark; Pro users honor the toggle.
                let mark: String? = (purchase.isPro && !watermarkEnabled)
                    ? nil
                    : "DITTY · \(currentSystem.name)"
                guard let rendered = ExportRenderer.render(img, aspect: aspect, watermark: mark) else { return }
                UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                savedCount += 1
                showToast()
                // Defer presenting the share sheet until the export sheet has
                // fully dismissed — chaining two `.sheet(item:)` modifiers
                // alongside `.sheet(isPresented:)` race-conditions otherwise
                // (the share sheet flickers open/closed in a loop).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    shareItem = rendered
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: Binding(
            get: { shareItem.map { ShareItem(image: $0) } },
            set: { shareItem = $0?.image }
        )) { item in
            ShareSheet(items: [item.image])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { recordedGIFURL.map { GIFItem(url: $0) } },
            set: { recordedGIFURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .task {
            vm.respectImageRatio = respectImageRatio
            await purchase.bootstrap()
            #if DEBUG
            let skipOnboarding = ProcessInfo.processInfo.arguments.contains("-SkipOnboarding")
            #else
            let skipOnboarding = false
            #endif
            if !didShowOnboarding && !skipOnboarding {
                // Tiny delay so the splash dismissal lands first.
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeIn(duration: 0.25)) { showOnboarding = true }
                didShowOnboarding = true
            }

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
        // Pipe each newly dithered preview into recorder + burst (no-ops when
        // those features aren't active).
        .onReceive(vm.$previewImage.compactMap { $0 }) { image in
            recorder.appendIfNeeded(image)
        }
        // Once a GIF finishes encoding, kick off the share sheet (after a
        // brief delay so any other dismissing sheet has fully unmounted).
        .onReceive(recorder.$lastEncodedURL.compactMap { $0 }) { url in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                recordedGIFURL = url
                recorder.consumeLastEncodedURL()
            }
        }
        // When the burst completes, drop the user into the share sheet.
        // Tiny delay matches the export → share handoff so SwiftUI doesn't
        // race two sheet bindings.
        .onReceive(burst.$contactSheet.compactMap { $0 }) { image in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shareItem = image
                burst.consumeContactSheet()
            }
        }
        .onChange(of: respectImageRatio) { newValue in
            vm.respectImageRatio = newValue
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            // Top-left: gallery-add by default; becomes a back arrow while the
            // user is viewing a captured/uploaded still. Long-press the
            // gallery icon to jump to bundled sample images.
            CircleIconButton(
                iconAsset: isViewingStill ? "icon-back" : "icon-gallery-add",
                accessibilityLabel: isViewingStill ? "Back to camera" : "Upload from gallery"
            ) {
                if isViewingStill {
                    vm.resumeLive()
                    vm.sourceImage = nil
                    zoomFactor = 1.0
                    camera.setZoom(1.0)
                } else {
                    showPicker = true
                }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                guard !isViewingStill else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showSampleLibrary = true
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

    // MARK: - System picker carousel
    //
    // Always-visible horizontal pill row of every system. Tapping a pill jumps
    // straight to that system without the swipe-through dance. Pro-locked
    // systems show a small lock badge and route through the paywall.

    private var systemPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(orderedSystems) { sys in
                        systemPill(sys)
                            .id(sys.id)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                proxy.scrollTo(vm.systemId, anchor: .center)
            }
            .onChange(of: vm.systemId) { newId in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    private func systemPill(_ sys: DithertronSettings) -> some View {
        let active = sys.id == vm.systemId
        let locked = !purchase.isPro && !FreeSystems.isFree(sys.id)
        let starred = favorites.contains(sys.id)
        return Button {
            if locked {
                showPaywall = true
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.systemId = sys.id
            }
        } label: {
            HStack(spacing: 6) {
                if starred {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(active ? Color(red: 0.99, green: 0.78, blue: 0.27) : Color(red: 0.99, green: 0.78, blue: 0.27))
                }
                Text(sys.name)
                    .font(.system(.footnote, design: .monospaced)
                        .weight(active ? .semibold : .regular))
                    .lineLimit(1)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(active ? .white : Color.black.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                active ? Color.black : Color.black.opacity(0.05),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        // Long-press: toggle favorite. Free + Pro systems alike — favoriting
        // a Pro system still surfaces the lock badge until the user upgrades.
        .onLongPressGesture(minimumDuration: 0.45) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            favorites.toggle(sys.id)
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
                        // Fill the entire viewport — crop any overflow from
                        // mismatched aspect. The outline + corner radius are
                        // preserved by clipping at the viewport bounds.
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else if vm.sourceImage != nil {
                        // Have an input but the engine hasn't produced a
                        // dither yet — covers the ~200ms after a system
                        // switch with a fresh palette reduce.
                        ProgressView()
                            .tint(Color.black.opacity(0.6))
                            .scaleEffect(1.2)
                    } else if camera.isRunning && !noCameraFeed {
                        ProgressView()
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: noCameraFeed ? "photo.stack" : "camera.viewfinder")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.black.opacity(0.35))
                            Text(noCameraFeed
                                 ? "No camera feed.\nUpload a photo or try a sample."
                                 : "Warming up the camera…")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .padding(.horizontal, 16)
                            if noCameraFeed {
                                HStack(spacing: 10) {
                                    Button { showPicker = true } label: {
                                        Label("Upload", systemImage: "photo.fill.on.rectangle.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.black.opacity(0.05), in: Capsule())
                                            .foregroundStyle(.black)
                                    }
                                    .buttonStyle(.plain)
                                    Button { showSampleLibrary = true } label: {
                                        Label("Samples", systemImage: "sparkles")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.black, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }

                if showGrid {
                    GridOverlay()
                        .padding(8)
                        .allowsHitTesting(false)
                }

                // Subtle "still cooking" pill while the engine re-converges
                // after a system/FX change. Only shown for static photos —
                // live mode runs one iteration per frame and never sets
                // isProcessing for long enough to be useful.
                if vm.isProcessing, vm.previewImage != nil {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                    .tint(.white)
                                Text("Dithering…")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            Spacer()
                        }
                        .padding(10)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
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

                // Zoom badge — visible briefly while pinching.
                if !isViewingStill, zoomFactor > 1.05 {
                    VStack {
                        HStack {
                            Spacer()
                            Text(String(format: "%.1f×", zoomFactor))
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(10)
                        }
                        Spacer()
                    }
                }

                // Tap-to-focus ring — animated yellow ring at tap location.
                if let ring = focusRing {
                    FocusRingView()
                        .position(x: ring.position.x, y: ring.position.y)
                        .id(ring.id)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .gesture(swipeGesture)
            .simultaneousGesture(pinchGesture)
            .onLongPressGesture(minimumDuration: 0.45) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showSystemPicker = true
            }
            .onTapGesture { location in
                guard !isViewingStill else { return }
                let normalized = CGPoint(
                    x: max(0, min(1, location.x / max(1, geo.size.width))),
                    y: max(0, min(1, location.y / max(1, geo.size.height)))
                )
                camera.focus(at: normalized)
                let ring = FocusRingState(position: location)
                focusRing = ring
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    if focusRing?.id == ring.id {
                        withAnimation(.easeOut(duration: 0.3)) { focusRing = nil }
                    }
                }
            }
        }
        .aspectRatio(400.0/640.0, contentMode: .fit)
    }

    /// Pinch-to-zoom on the live preview. Multiplies the camera's
    /// videoZoomFactor and clamps to [1, 8] inside the streamer.
    private var pinchGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.02)
            .onChanged { scale in
                guard !isViewingStill else { return }
                if pinchStartZoom == nil { pinchStartZoom = zoomFactor }
                let proposed = max(1, min(8, (pinchStartZoom ?? 1) * scale))
                zoomFactor = proposed
                camera.setZoom(proposed)
            }
            .onEnded { _ in pinchStartZoom = nil }
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
            // Bottom-left: FX → opens the inline effect editor. Long-press
            // triggers a 5-frame burst contact sheet.
            CapsuleIconButton(
                iconAsset: "icon-fx",
                size: 64,
                accessibilityLabel: "Effects"
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    editingEffects = true
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                guard !isViewingStill, !burst.isCapturing, !recorder.isRecording else { return }
                if isCurrentLocked { showPaywall = true; return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                burst.start { [weak vm] in vm?.previewImage }
            }

            // Center: shutter when live, save when viewing a still.
            // Tap = capture, hold = record GIF (live mode only).
            shutterControl

            // Bottom-right: face/sticker → switch front/back camera.
            CapsuleIconButton(
                iconAsset: "icon-gallery", // sticker-smile asset
                size: 64,
                accessibilityLabel: "Switch camera"
            ) { camera.toggleCamera() }
        }
    }

    @ViewBuilder
    private var shutterControl: some View {
        if isViewingStill {
            ShutterButton(
                mode: .save,
                progress: 0,
                accessibilityLabel: "Save"
            ) {
                if isCurrentLocked { showPaywall = true; return }
                guard vm.previewImage != nil else { return }
                showExportSheet = true
            }
        } else {
            ZStack {
                ShutterButton(
                    mode: .capture,
                    progress: recorder.progress,
                    accessibilityLabel: recorder.isRecording ? "Stop recording" : "Capture"
                ) {
                    // Tap behavior: instant capture (only fires when not in
                    // a hold-record). The longPress gesture below cancels the
                    // tap if the press lasts long enough.
                    triggerShutterEffect()
                    if saveOriginal, let original = camera.fullResFrame {
                        UIImageWriteToSavedPhotosAlbum(original, nil, nil, nil)
                    }
                    vm.captureCurrentFrame(highRes: camera.fullResFrame)
                }
                // Long-press gesture = start recording. Released finger ends.
                // Built as a DragGesture so we can detect press-down + release.
                .gesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            switch value {
                            case .first(_):
                                break
                            case .second(true, _):
                                if !recorder.isRecording {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    recorder.start()
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { _ in
                            if recorder.isRecording { recorder.stop() }
                        }
                )
            }
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
                Text("Camera off")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Ditty needs camera access for live retro effects. You can also dither photos straight from your library.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 40)
                Button("Pick from Library") { showPicker = true }
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

    /// Camera shutter "snap": white flash (in fast, out slower), a tiny scale
    /// punch on the photo viewport, and the system's camera-shutter sound
    /// (suppressed if the user has Shutter Sound off in settings, and routed
    /// through an .ambient audio session so the device's silent switch
    /// silences it where the law allows).
    private func triggerShutterEffect() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if shutterSound {
            // Configure an ambient session so the silent switch suppresses
            // the sound (App Store conduct policy doesn't require the
            // shutter sound outside JP/KR; users in those regions still get
            // it because the system's 1108 SystemSoundID is mandatory there
            // regardless of session category).
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [])
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
            AudioServicesPlaySystemSound(1108)
        }
        withAnimation(.easeIn(duration: 0.05)) {
            shutterFlash = true
            viewportScale = 0.97
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.22)) {
                shutterFlash = false
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                viewportScale = 1.0
            }
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

/// Animated yellow focus ring that fades in fast, settles smaller, then fades out.
private struct FocusRingView: View {
    @State private var scale: CGFloat = 1.6
    @State private var opacity: Double = 0
    var body: some View {
        Circle()
            .strokeBorder(Color(red: 0.99, green: 0.78, blue: 0.27), lineWidth: 1.5)
            .frame(width: 64, height: 64)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    scale = 1.0
                    opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeIn(duration: 0.3)) { opacity = 0 }
                }
            }
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
    var progress: Double = 0
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Recording ring fills clockwise from 12 o'clock as progress goes 0→1.
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 92, height: 92)
                }
                Circle()
                    .fill(progress > 0 ? Color.red : .black)
                    // Same shadow stack scaled for the dark shutter — keeps the
                    // tactile feel consistent with the lighter chrome buttons.
                    .shadow(color: .black.opacity(0.12), radius: 1.35, x: 0, y: 0.67)
                    .shadow(color: .black.opacity(0.25), radius: 1.10, x: 0, y: 2.02)
                if progress > 0 {
                    // While recording, show a square inside the red disc
                    // (universal "stop" iconography).
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                } else {
                    Image(mode == .save ? "icon-save" : "icon-shutter")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
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

/// Lightweight Identifiable wrapper so the share sheet's `.sheet(item:)` can
/// reuse the same UIImage value type without forcing UIImage to be Identifiable.
private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct GIFItem: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    ContentView()
}
