import Foundation

public struct PreferenceMatcher: Sendable {
    public init() {}

    public func match(item: MenuItem, profile: UserPreferenceProfile) -> PreferenceMatch {
        let haystack = "\(item.sectionTitle ?? "") \(item.name) \(item.description) \(item.cuisineTags.joined(separator: " "))".lowercased()
        let normalizedCuisineTags = item.cuisineTags.map { $0.lowercased() }

        let cuisineHits = profile.likedCuisines.filter { haystack.contains($0.lowercased()) || normalizedCuisineTags.contains($0.lowercased()) }
        let likedIngredientHits = profile.likedIngredients.filter { haystack.contains($0.lowercased()) }
        let dislikedIngredientHits = profile.dislikedIngredients.filter { haystack.contains($0.lowercased()) }

        return PreferenceMatch(
            cuisineHits: cuisineHits,
            likedIngredientHits: likedIngredientHits,
            dislikedIngredientHits: dislikedIngredientHits
        )
    }
}
