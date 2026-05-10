import SwiftUI
import StoreKit

/// Subscription / app-level preferences sheet. Distinct from the inline FX
/// editor — this is reserved for Pro purchase, restore, and persistent toggles
/// (saved to UserDefaults).
struct AppSettingsSheet: View {
    @ObservedObject var purchase: PurchaseManager
    @ObservedObject var presetStore: SystemFXPresetStore
    @ObservedObject var paletteStore: CustomPaletteStore
    @ObservedObject var favorites: SystemFavorites
    @Binding var saveOriginal: Bool
    @Binding var showGrid: Bool
    @Binding var shutterSound: Bool
    @Binding var respectImageRatio: Bool
    @Binding var watermarkEnabled: Bool
    let savedCount: Int
    /// Coordinated reset of every observable state the user can mutate.
    /// Closure so AppSettingsSheet doesn't need direct access to the view
    /// model's @AppStorage values.
    let onResetApp: () -> Void

    @State private var showPaywall = false
    @State private var showShareSheet = false
    @State private var showResetConfirm = false
    @State private var showResetDone = false
    @Environment(\.dismiss) private var dismiss

    /// System-id → display-name map so Preset Management can show "Game Boy"
    /// instead of "gb".
    private var systemNamesById: [String: String] {
        Dictionary(uniqueKeysWithValues: Systems.all.map { ($0.id, $0.name) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    proCard
                    filmUsageCard
                    usageSection
                    presetsSection
                    contactSection
                    dangerSection
                    Text("Ditty · v1.1")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            .alert("Reset Ditty?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { performReset() }
            } message: {
                Text("Wipes onboarding, saved presets, custom palettes, favorites, and counters. Pro purchases are not affected — restore them from the App Store. Force-quit and reopen the app for a true cold launch.")
            }
            .alert("Ditty reset", isPresented: $showResetDone) {
                Button("OK") { dismiss() }
            } message: {
                Text("Now force-quit Ditty (swipe up from the home indicator and flick the Ditty card up) and reopen for a fresh launch.")
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close settings")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(purchase: purchase)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareLink(item: URL(string: "https://otherdays.studio/ditty")!,
                      message: Text("Ditty — retro dithering for your photos"))
                .presentationDetents([.medium])
        }
    }

    // MARK: - Pro card

    private var proCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(purchase.isPro
                          ? Color(red: 0.99, green: 0.78, blue: 0.27).opacity(0.18)
                          : Color.white.opacity(0.06))
                Image(systemName: purchase.isPro ? "star.circle.fill" : "tv.inset.filled")
                    .font(.system(size: 30))
                    .foregroundStyle(purchase.isPro
                                     ? Color(red: 0.99, green: 0.78, blue: 0.27)
                                     : Color.white.opacity(0.7))
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                if purchase.isPro {
                    Text("Ditty Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Every system unlocked. Thank you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Get Ditty Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("One-time unlock for every retro system.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !purchase.isPro {
                Button("Unlock") { showPaywall = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Film usage

    private var filmUsageCard: some View {
        HStack {
            Text("Film usage")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(savedCount)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .scaleEffect(x: -1, y: 1)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Use section

    private var usageSection: some View {
        sectionCard(header: "USE") {
            row(label: "Restore purchases", trailing: chevron) {
                Task { await purchase.restore() }
            }
            divider
            toggleRow(label: "Save original image", isOn: $saveOriginal)
            divider
            toggleRow(label: "Match image ratio", isOn: $respectImageRatio)
            divider
            toggleRow(label: "Shutter sound", isOn: $shutterSound)
            divider
            toggleRow(label: "Show grid", isOn: $showGrid)
            divider
            // Free users see the toggle but it's locked-on with a Pro badge.
            // Pro users get full control.
            watermarkRow
        }
    }

    private var watermarkRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Watermark")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                if !purchase.isPro {
                    Text("Pro unlocks the toggle")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                }
            }
            Spacer()
            if purchase.isPro {
                Toggle("", isOn: $watermarkEnabled)
                    .tint(Color(red: 0.99, green: 0.78, blue: 0.27))
                    .labelsHidden()
            } else {
                // Locked-on for free users: show a static "ON" with a lock.
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("ON")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Per-system presets

    private var presetsSection: some View {
        sectionCard(header: "PER-SYSTEM PRESETS") {
            let entries = presetStore.presets
                .sorted { lhs, rhs in
                    (systemNamesById[lhs.key] ?? lhs.key) < (systemNamesById[rhs.key] ?? rhs.key)
                }
            if entries.isEmpty {
                emptyHint("Save a preset from the FX panel and it will appear here.")
            } else {
                ForEach(entries, id: \.key) { entry in
                    presetRow(systemId: entry.key, preset: entry.value)
                    if entry.key != entries.last?.key { divider }
                }
            }
        }
    }

    private func presetRow(systemId: String, preset: SystemFXPreset) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(systemNamesById[systemId] ?? systemId)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text("kernel · \(preset.ditherKernelId) · diffuse \(String(format: "%.2f", preset.diffuse)) · diversity \(String(format: "%.2f", preset.diversity))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive) {
                presetStore.reset(systemId: systemId)
            } label: {
                Image(systemName: "trash")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(systemNamesById[systemId] ?? systemId) preset")
        }
        .padding(.vertical, 10)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Contact section

    private var contactSection: some View {
        sectionCard(header: "CONTACT US") {
            row(label: "Suggestions and Feedback", trailing: chevron) {
                if let url = URL(string: "mailto:lovish@otherdays.studio") {
                    UIApplication.shared.open(url)
                }
            }
            divider
            row(label: "Share Ditty", trailing: chevron) { showShareSheet = true }
        }
    }

    // MARK: - Danger / reset

    private var dangerSection: some View {
        sectionCard(header: "RESET") {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Ditty")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        Text("Wipes all local state and sends you back to first launch.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            #if DEBUG
            divider
            Button {
                purchase.debugClearProState()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Pro state (debug)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("Flips isPro=false in memory so you can replay the paywall. Delete the underlying transaction in Xcode → Debug → StoreKit → Manage Transactions for a permanent reset.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    private func performReset() {
        // Stores wipe their own UserDefaults blob + in-memory state.
        presetStore.resetAll()
        paletteStore.resetAll()
        favorites.resetAll()

        // Toggles + counters owned by ContentView's @AppStorage. Removing
        // the keys directly is fine — @AppStorage falls back to the
        // declared default on the next read.
        let prefs: [String] = [
            "ditty.saveOriginal",
            "ditty.shutterSound",
            "ditty.showGrid",
            "ditty.savedCount",
            "ditty.respectImageRatio",
            "ditty.watermark",
            "ditty.didShowOnboarding",
        ]
        for key in prefs {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Ask ContentView to apply its own in-memory cleanup (clears the
        // photo, returns to live mode, etc.).
        onResetApp()
        showResetDone = true
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(.caption.weight(.medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }

    private func row(label: String, trailing: AnyView, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                trailing
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Color(red: 0.99, green: 0.78, blue: 0.27))
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
    }

    private var chevron: AnyView {
        AnyView(
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        )
    }
}
