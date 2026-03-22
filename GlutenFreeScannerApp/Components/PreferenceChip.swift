import SwiftUI

struct PreferenceChip: View {
    let title: String
    var isSelected = true

    var body: some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? AppPalette.ink : .secondary)
            .background(isSelected ? AppPalette.accent.opacity(0.16) : AppPalette.mist.opacity(0.55), in: Capsule())
    }
}
