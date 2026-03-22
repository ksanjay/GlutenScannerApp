import SwiftUI
import GlutenFreeCore

struct ConfidenceBadge: View {
    let tier: GlutenConfidenceTier

    var body: some View {
        Text(tier.title)
            .font(.caption.weight(.black))
            .tracking(0.2)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(.white)
    }

    private var backgroundColor: Color {
        switch tier {
        case .definitelyGood: AppPalette.sage
        case .mediumProbability: AppPalette.amber
        case .mightBeGood: AppPalette.sand
        }
    }
}
