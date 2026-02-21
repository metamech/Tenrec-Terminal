import SwiftUI
import SwiftData
import AppKit

// MARK: - ProfileEditorView

/// Form for editing a single TerminalProfile's fields.
/// All changes are applied immediately through the ViewModel.
struct ProfileEditorView: View {
    let profile: TerminalProfile
    let viewModel: TerminalProfileViewModel

    // Local state for the color pickers (bound two-way to profile via viewModel)
    @State private var foregroundColorPicker: Color = .white
    @State private var backgroundColorPicker: Color = .black
    @State private var cursorColorPicker: Color = .white

    // ANSI colors (16 entries)
    @State private var ansiColorPickers: [Color] = Array(repeating: .black, count: 16)

    var body: some View {
        Form {
            Section("Font") {
                HStack {
                    Text("Family")
                    Spacer()
                    TextField("Font name", text: Binding(
                        get: { profile.fontFamily },
                        set: { viewModel.updateProfile(id: profile.id, fontFamily: $0) }
                    ))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 160)
                }

                HStack {
                    Text("Size")
                    Spacer()
                    TextField("Size", value: Binding(
                        get: { profile.fontSize },
                        set: { viewModel.updateProfile(id: profile.id, fontSize: $0) }
                    ), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                }
            }

            Section("Colors") {
                ColorRow(label: "Foreground", color: $foregroundColorPicker) { newColor in
                    viewModel.updateProfile(id: profile.id, foregroundColor: newColor.hexString)
                }

                ColorRow(label: "Background", color: $backgroundColorPicker) { newColor in
                    viewModel.updateProfile(id: profile.id, backgroundColor: newColor.hexString)
                }

                ColorRow(label: "Cursor", color: $cursorColorPicker) { newColor in
                    viewModel.updateProfile(id: profile.id, cursorColor: newColor.hexString)
                }
            }

            Section("Cursor Style") {
                Picker("Style", selection: Binding(
                    get: { profile.cursorStyle },
                    set: { viewModel.updateProfile(id: profile.id, cursorStyle: $0) }
                )) {
                    Text("Block").tag("block")
                    Text("Underline").tag("underline")
                    Text("Bar").tag("bar")
                }
                .pickerStyle(.segmented)
            }

            Section("Opacity") {
                HStack {
                    Slider(value: Binding(
                        get: { profile.opacity },
                        set: { viewModel.updateProfile(id: profile.id, opacity: $0) }
                    ), in: 0.1...1.0, step: 0.05)
                    Text("\(Int(profile.opacity * 100))%")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("ANSI Colors") {
                AnsiColorGrid(
                    colors: $ansiColorPickers,
                    onChange: { index, newColor in
                        var updated = profile.ansiColors
                        if index < updated.count {
                            updated[index] = newColor.hexString
                        }
                        viewModel.updateProfile(id: profile.id, ansiColors: updated)
                    }
                )
            }

            // Terminal preview swatch
            Section("Preview") {
                TerminalPreviewSwatch(profile: profile)
                    .frame(height: 80)
            }
        }
        .formStyle(.grouped)
        .onAppear { syncColors() }
        .onChange(of: profile.id) { syncColors() }
        .disabled(profile.isBuiltIn)
        .overlay(alignment: .top) {
            if profile.isBuiltIn {
                Label("Built-in profiles cannot be edited. Duplicate to customize.", systemImage: "lock.fill")
                    .font(.caption)
                    .padding(8)
                    .background(.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    private func syncColors() {
        foregroundColorPicker = Color(hex: profile.foregroundColor) ?? .white
        backgroundColorPicker = Color(hex: profile.backgroundColor) ?? .black
        cursorColorPicker     = Color(hex: profile.cursorColor)     ?? .white
        ansiColorPickers = profile.ansiColors.prefix(16).map {
            Color(hex: $0) ?? .black
        }
        // Pad if fewer than 16 stored
        while ansiColorPickers.count < 16 {
            ansiColorPickers.append(.black)
        }
    }
}

// MARK: - ColorRow

private struct ColorRow: View {
    let label: String
    @Binding var color: Color
    let onChange: (Color) -> Void

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: $color)
                .labelsHidden()
                .onChange(of: color) { _, newValue in
                    onChange(newValue)
                }
        }
    }
}

// MARK: - AnsiColorGrid

private struct AnsiColorGrid: View {
    @Binding var colors: [Color]
    let onChange: (Int, Color) -> Void

    private let ansiNames = [
        "Black", "Red", "Green", "Yellow",
        "Blue", "Magenta", "Cyan", "White",
        "Bright Black", "Bright Red", "Bright Green", "Bright Yellow",
        "Bright Blue", "Bright Magenta", "Bright Cyan", "Bright White"
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
            ForEach(0..<16) { index in
                VStack(spacing: 2) {
                    ColorPicker("", selection: Binding(
                        get: { colors[index] },
                        set: { newColor in
                            colors[index] = newColor
                            onChange(index, newColor)
                        }
                    ))
                    .labelsHidden()

                    Text(ansiNames[index])
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TerminalPreviewSwatch

/// A simple color swatch that mimics a terminal appearance using the profile colors.
struct TerminalPreviewSwatch: View {
    let profile: TerminalProfile

    var body: some View {
        let bg = Color(hex: profile.backgroundColor) ?? .black
        let fg = Color(hex: profile.foregroundColor) ?? .white

        ZStack(alignment: .topLeading) {
            bg
            VStack(alignment: .leading, spacing: 2) {
                Text("$ ls -la")
                    .foregroundStyle(fg)
                Text("total 42")
                    .foregroundStyle(fg.opacity(0.7))
                HStack(spacing: 4) {
                    Text("$")
                        .foregroundStyle(fg)
                    Rectangle()
                        .fill(fg)
                        .frame(width: 7, height: 14)
                }
            }
            .font(.custom(profile.fontFamily, size: 11).monospaced())
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Color+Hex helpers

extension Color {
    /// Initializes a Color from a hex string like "#RRGGBB" or "#RRGGBBAA".
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str = String(str.dropFirst()) }

        let scanner = Scanner(string: str)
        var rgba: UInt64 = 0
        guard scanner.scanHexInt64(&rgba) else { return nil }

        switch str.count {
        case 6:
            self.init(
                red:   Double((rgba >> 16) & 0xFF) / 255,
                green: Double((rgba >>  8) & 0xFF) / 255,
                blue:  Double( rgba        & 0xFF) / 255
            )
        case 8:
            self.init(
                red:   Double((rgba >> 24) & 0xFF) / 255,
                green: Double((rgba >> 16) & 0xFF) / 255,
                blue:  Double((rgba >>  8) & 0xFF) / 255,
                opacity: Double(rgba & 0xFF) / 255
            )
        default:
            return nil
        }
    }

    /// Returns the color as a "#RRGGBB" hex string (lossy — ignores opacity).
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int((nsColor.redComponent   * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent  * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preview

#Preview {
    ProfileEditorView(
        profile: TerminalProfile(name: "Preview Profile"),
        viewModel: TerminalProfileViewModel(
            modelContext: try! ModelContainer(
                for: TerminalProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext
        )
    )
    .frame(width: 400, height: 600)
}
