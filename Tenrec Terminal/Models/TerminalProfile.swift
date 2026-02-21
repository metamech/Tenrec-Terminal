import Foundation
import SwiftData

@Model
final class TerminalProfile {
    var id: UUID
    var name: String
    var fontFamily: String
    var fontSize: Double
    var foregroundColor: String
    var backgroundColor: String
    var cursorColor: String
    var cursorStyle: String
    var selectionColor: String
    var ansiColors: [String]
    var opacity: Double
    var isBuiltIn: Bool

    init(
        name: String,
        fontFamily: String = "Menlo",
        fontSize: Double = 13.0,
        foregroundColor: String = "#C7C7C7",
        backgroundColor: String = "#1E1E1E",
        cursorColor: String = "#C7C7C7",
        cursorStyle: String = "block",
        selectionColor: String = "#4D90FE80",
        ansiColors: [String] = TerminalProfile.defaultAnsiColors,
        opacity: Double = 1.0,
        isBuiltIn: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.cursorColor = cursorColor
        self.cursorStyle = cursorStyle
        self.selectionColor = selectionColor
        self.ansiColors = ansiColors
        self.opacity = opacity
        self.isBuiltIn = isBuiltIn
    }

    // Standard 16 ANSI colors (xterm defaults)
    static let defaultAnsiColors: [String] = [
        "#1E1E1E", "#CC0000", "#4E9A06", "#C4A000",
        "#3465A4", "#75507B", "#06989A", "#D3D7CF",
        "#555753", "#EF2929", "#8AE234", "#FCE94F",
        "#729FCF", "#AD7FA8", "#34E2E2", "#EEEEEC"
    ]
}
