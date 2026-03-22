import Foundation

public enum SampleData {
    public static let onboardingProfile = UserPreferenceProfile(
        likedCuisines: ["Mexican", "Japanese", "Mediterranean"],
        likedIngredients: ["avocado", "lime", "salmon", "rice"],
        dislikedIngredients: ["mushroom"]
    )

    public static let demoMenuText = """
    TACOS
    Salmon Rice Bowl - avocado, cucumber, tamari, sesame 18
    Crispy Fish Taco - cabbage, house sauce, lime 8
    Carne Asada Plate - grilled steak, corn tortilla, salsa verde 21

    SMALL PLATES
    Ceviche - citrus, chili, avocado 16
    Fried Calamari - lemon aioli 17
    Roasted Cauliflower - tahini, herbs, pistachio 14
    """
}
