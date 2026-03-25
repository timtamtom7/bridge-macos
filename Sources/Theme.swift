import SwiftUI

enum Theme {
    static let primaryBlue = Color(hex: "#007AFF")
    static let secondaryGray = Color(hex: "#8E8E93")
    static let successGreen = Color(hex: "#34C759")
    static let warningOrange = Color(hex: "#FF9500")
    static let dangerRed = Color(hex: "#FF3B30")
    static let backgroundPrimary = Color(NSColor.windowBackgroundColor)
    static let backgroundSecondary = Color(NSColor.controlBackgroundColor)
    static let backgroundTertiary = Color(NSColor.textBackgroundColor)
    static let textPrimary = Color(NSColor.labelColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)
    static let textTertiary = Color(NSColor.tertiaryLabelColor)
    static let spacing2: CGFloat = 2
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 4
    static let cornerRadiusMedium: CGFloat = 8
}

extension Color {
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intVal: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&intVal)
        var a: UInt64 = 255, r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        let cnt = hexClean.count
        if cnt == 3 { a = 255; r = ((intVal >> 8) & 0xF) * 17; g = ((intVal >> 4) & 0xF) * 17; b = (intVal & 0xF) * 17 }
        else if cnt == 6 { a = 255; r = (intVal >> 16) & 0xFF; g = (intVal >> 8) & 0xFF; b = intVal & 0xFF }
        else if cnt == 8 { a = (intVal >> 24) & 0xFF; r = (intVal >> 16) & 0xFF; g = (intVal >> 8) & 0xFF; b = intVal & 0xFF }
        else { a = 255; r = 0; g = 0; b = 0 }
        self.init(.sRGB, red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: Double(a) / 255.0)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Theme.backgroundSecondary).cornerRadius(Theme.cornerRadiusMedium)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
extension View { func cardStyle() -> some View { modifier(CardStyle()) } }
