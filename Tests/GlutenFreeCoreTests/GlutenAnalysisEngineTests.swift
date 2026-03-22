import XCTest
@testable import GlutenFreeCore

final class GlutenAnalysisEngineTests: XCTestCase {
    func testExplicitGlutenFreeItemBecomesDefinitelyGood() {
        let item = MenuItem(name: "Chicken Bowl", description: "gluten-free rice bowl with herbs", rawText: "Chicken Bowl gluten-free")
        let engine = GlutenAnalysisEngine()

        let analyzed = engine.analyze(item: item, documentConfidence: 0.9, profile: .init())

        XCTAssertEqual(analyzed.confidenceTier, .definitelyGood)
    }

    func testBreadedItemNeverBecomesDefinitelyGood() {
        let item = MenuItem(name: "Crispy Chicken", description: "breaded with house sauce", rawText: "breaded crispy chicken")
        let engine = GlutenAnalysisEngine()

        let analyzed = engine.analyze(item: item, documentConfidence: 0.95, profile: .init())

        XCTAssertEqual(analyzed.confidenceTier, .mightBeGood)
    }

    func testAmbiguousFriedDishStaysBelowTopTier() {
        let item = MenuItem(name: "Fried Shrimp", description: "special sauce", rawText: "fried shrimp with special sauce")
        let engine = GlutenAnalysisEngine()

        let analyzed = engine.analyze(item: item, documentConfidence: 0.9, profile: .init())

        XCTAssertNotEqual(analyzed.confidenceTier, .definitelyGood)
    }

    func testPreferenceScoreDoesNotOverrideRisk() {
        let item = MenuItem(name: "Pasta Primavera", description: "avocado basil", cuisineTags: ["Italian"], rawText: "pasta avocado basil")
        let profile = UserPreferenceProfile(likedCuisines: ["Italian"], likedIngredients: ["avocado"], dislikedIngredients: [])
        let engine = GlutenAnalysisEngine()

        let analyzed = engine.analyze(item: item, documentConfidence: 0.95, profile: profile)

        XCTAssertEqual(analyzed.preferenceMatch.score, 5)
        XCTAssertEqual(analyzed.confidenceTier, .mightBeGood)
    }

    func testParserBuildsSectionsAndItems() {
        let parser = MenuParser()
        let document = parser.parse(rawText: SampleData.demoMenuText, sourceName: "demo-menu.jpg")

        XCTAssertEqual(document.sections.count, 2)
        XCTAssertGreaterThan(document.allItems.count, 3)
    }
}
