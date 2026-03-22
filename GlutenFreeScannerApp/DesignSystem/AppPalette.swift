import SwiftUI

enum AppPalette {
    static let canvas = LinearGradient(
        colors: [Color(red: 0.995, green: 0.965, blue: 0.92), Color(red: 0.95, green: 0.9, blue: 0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ink = Color(red: 0.21, green: 0.16, blue: 0.11)
    static let card = Color.white.opacity(0.82)
    static let accent = Color(red: 0.88, green: 0.42, blue: 0.24)
    static let sage = Color(red: 0.47, green: 0.62, blue: 0.4)
    static let amber = Color(red: 0.85, green: 0.64, blue: 0.2)
    static let sand = Color(red: 0.72, green: 0.64, blue: 0.49)
    static let mist = Color(red: 0.93, green: 0.89, blue: 0.82)
}
