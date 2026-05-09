import SwiftUI

/// Sheet for creating or editing a user palette: name + 4-16 hex codes.
/// Each swatch uses a SwiftUI ColorPicker; users can add/remove swatches
/// up to the 16-color cap.
struct CustomPaletteBuilder: View {
    @ObservedObject var store: CustomPaletteStore
    let editing: UserPalette?
    let onSave: (UserPalette) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var colors: [Color]

    private static let defaultColors: [Color] = [
        Color(red: 0.07, green: 0.13, blue: 0.27),
        Color(red: 0.30, green: 0.16, blue: 0.32),
        Color(red: 0.79, green: 0.30, blue: 0.18),
        Color(red: 0.99, green: 0.78, blue: 0.27),
    ]

    init(store: CustomPaletteStore,
         editing: UserPalette?,
         onSave: @escaping (UserPalette) -> Void) {
        self.store = store
        self.editing = editing
        self.onSave = onSave
        if let p = editing {
            _name = State(initialValue: p.name)
            _colors = State(initialValue: p.colors.map { Self.color(from: $0) })
        } else {
            _name = State(initialValue: "My palette")
            _colors = State(initialValue: Self.defaultColors)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    swatchGrid
                    addRemoveControls
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(editing == nil ? "New Palette" : "Edit Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                        .disabled(colors.count < 4)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NAME")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
            TextField("", text: $name, prompt: Text("My palette").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }

    private var swatchGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COLORS")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(colors.count) of 16")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(colors.indices, id: \.self) { i in
                    swatch(index: i)
                }
            }
        }
    }

    private func swatch(index: Int) -> some View {
        ColorPicker("", selection: Binding(
            get: { colors[index] },
            set: { colors[index] = $0 }
        ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 64, height: 64)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var addRemoveControls: some View {
        HStack(spacing: 12) {
            Button {
                if colors.count > 4 { colors.removeLast() }
            } label: {
                Label("Remove", systemImage: "minus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.count > 4 ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(colors.count <= 4)

            Button {
                if colors.count < 16 { colors.append(.gray) }
            } label: {
                Label("Add color", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.count < 16 ? .black : .white.opacity(0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(colors.count < 16 ? Color.white : Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(colors.count >= 16)

            Spacer()

            if let editing {
                Button(role: .destructive) {
                    store.remove(editing.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(10)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        let rgb = colors.map { Self.rgb(from: $0) }
        if let editing {
            var updated = editing
            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : name
            updated.colors = rgb
            store.update(updated)
            onSave(updated)
        } else {
            let new = UserPalette(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : name,
                colors: rgb
            )
            store.add(new)
            onSave(new)
        }
        dismiss()
    }

    // MARK: - Color <-> UInt32
    //
    // Engine packs colors as `R | (G << 8) | (B << 16)` (see Color.swift's `RGB`).
    // Matches the BGR ordering used by every other place that renders engine
    // palette values (see EffectEditor.swiftUIColor).

    static func color(from rgb: UInt32) -> Color {
        Color(red: Double(rgb & 0xff) / 255,
              green: Double((rgb >> 8) & 0xff) / 255,
              blue: Double((rgb >> 16) & 0xff) / 255)
    }

    static func rgb(from color: Color) -> UInt32 {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let R = UInt32(max(0, min(255, r * 255)))
        let G = UInt32(max(0, min(255, g * 255)))
        let B = UInt32(max(0, min(255, b * 255)))
        return R | (G << 8) | (B << 16)
    }
}
