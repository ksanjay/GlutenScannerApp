import SwiftUI

struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(AppPalette.ink.opacity(0.9), in: Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
    }
}
