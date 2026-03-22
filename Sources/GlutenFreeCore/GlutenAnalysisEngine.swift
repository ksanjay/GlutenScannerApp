import Foundation

public protocol AIAdvising: Sendable {
    func recommendation(for item: MenuItem, evidence: [AnalysisEvidence]) -> AIRecommendation
}

public struct AIRecommendation: Sendable {
    public var summary: String
    public var missingInfo: Bool

    public init(summary: String, missingInfo: Bool) {
        self.summary = summary
        self.missingInfo = missingInfo
    }
}

public struct HeuristicAIAdvisor: AIAdvising {
    public init() {}

    public func recommendation(for item: MenuItem, evidence: [AnalysisEvidence]) -> AIRecommendation {
        let riskCount = evidence.filter { $0.kind == .riskSignal }.count
        let ambiguityCount = evidence.filter { $0.kind == .ambiguity }.count
        let safeCount = evidence.filter { $0.kind == .safeSignal }.count

        let summary: String
        if riskCount > 0 {
            summary = "Detected strong gluten-risk signals in the dish wording."
        } else if ambiguityCount > 0 {
            summary = "Some ingredients look promising, but the menu leaves important preparation details unclear."
        } else if safeCount > 0 {
            summary = "The menu language includes direct or high-confidence gluten-friendly cues."
        } else {
            summary = "This item may work, but the available text is too sparse to treat it as clearly gluten-friendly."
        }

        return AIRecommendation(summary: summary, missingInfo: ambiguityCount > 0 || item.description.count < 10)
    }
}

public struct GlutenAnalysisEngine: Sendable {
    private let aiAdvisor: AIAdvising

    public init(aiAdvisor: AIAdvising = HeuristicAIAdvisor()) {
        self.aiAdvisor = aiAdvisor
    }

    public func analyze(document: MenuDocument, profile: UserPreferenceProfile) -> AnalysisSession {
        let analyzedItems = document.allItems.map { analyze(item: $0, documentConfidence: document.extractionConfidence, profile: profile) }
            .sorted(using: sortComparator)
        return AnalysisSession(menuDocument: document, analyzedItems: analyzedItems)
    }

    public func analyze(item: MenuItem, documentConfidence: Double, profile: UserPreferenceProfile) -> AnalyzedMenuItem {
        let lowercased = item.combinedText
        var evidence: [AnalysisEvidence] = []

        let safeSignals = matchTokens(in: lowercased, vocabulary: safeVocabulary, kind: .safeSignal, weight: 0.28)
        let riskSignals = matchTokens(in: lowercased, vocabulary: riskVocabulary, kind: .riskSignal, weight: -0.4)
        let ambiguitySignals = matchTokens(in: lowercased, vocabulary: ambiguityVocabulary, kind: .ambiguity, weight: -0.22)

        evidence.append(contentsOf: safeSignals)
        evidence.append(contentsOf: riskSignals)
        evidence.append(contentsOf: ambiguitySignals)

        if documentConfidence < 0.6 {
            evidence.append(.init(kind: .ambiguity, label: "Low OCR confidence", weight: -0.24))
        }

        if item.description.count < 8 && !lowercased.contains("gluten-free") {
            evidence.append(.init(kind: .ambiguity, label: "Limited menu detail", weight: -0.18))
        }

        let preferenceMatch = PreferenceMatcher().match(item: item, profile: profile)
        evidence.append(contentsOf: preferenceMatch.cuisineHits.map { .init(kind: .preference, label: "Cuisine match: \($0)", weight: 0.08) })
        evidence.append(contentsOf: preferenceMatch.likedIngredientHits.map { .init(kind: .preference, label: "Likes \($0)", weight: 0.06) })
        evidence.append(contentsOf: preferenceMatch.dislikedIngredientHits.map { .init(kind: .preference, label: "Contains disliked ingredient: \($0)", weight: -0.25) })

        let aiRecommendation = aiAdvisor.recommendation(for: item, evidence: evidence)
        let tier = determineTier(evidence: evidence, hasExplicitSafeSignal: lowercased.contains("gluten-free"), conservativeMode: profile.conservativeMode)

        return AnalyzedMenuItem(
            item: item,
            confidenceTier: tier,
            evidence: evidence.sorted { $0.weight > $1.weight },
            explanation: aiRecommendation.summary,
            missingInfo: aiRecommendation.missingInfo,
            preferenceMatch: preferenceMatch
        )
    }

    private func determineTier(
        evidence: [AnalysisEvidence],
        hasExplicitSafeSignal: Bool,
        conservativeMode: Bool
    ) -> GlutenConfidenceTier {
        let riskCount = evidence.filter { $0.kind == .riskSignal }.count
        let ambiguityCount = evidence.filter { $0.kind == .ambiguity }.count
        let safeCount = evidence.filter { $0.kind == .safeSignal }.count
        let score = evidence.reduce(0.0) { $0 + $1.weight }

        if riskCount > 0 {
            return ambiguityCount > 1 ? .mightBeGood : .mightBeGood
        }

        if hasExplicitSafeSignal && ambiguityCount == 0 {
            return .definitelyGood
        }

        if conservativeMode {
            if safeCount > 0 && ambiguityCount == 0 && score >= 0.2 {
                return .definitelyGood
            }
            if safeCount > 0 && ambiguityCount <= 2 && score >= -0.05 {
                return .mediumProbability
            }
            return .mightBeGood
        }

        if score >= 0.25 {
            return .definitelyGood
        }
        if score >= -0.1 {
            return .mediumProbability
        }
        return .mightBeGood
    }

    private func matchTokens(
        in text: String,
        vocabulary: [String],
        kind: EvidenceKind,
        weight: Double
    ) -> [AnalysisEvidence] {
        vocabulary.compactMap { token in
            text.contains(token) ? AnalysisEvidence(kind: kind, label: token.capitalized, weight: weight) : nil
        }
    }

    private var sortComparator: KeyPathComparator<AnalyzedMenuItem> {
        KeyPathComparator(\.confidenceTier.sortPriority, order: .forward)
    }

    private let safeVocabulary = [
        "gluten-free", "corn tortilla", "ceviche", "sashimi", "lettuce wrap", "rice bowl", "tamari", "polenta", "risotto", "grilled", "roasted vegetables"
    ]

    private let riskVocabulary = [
        "breaded", "soy sauce", "roux", "flour tortilla", "pasta", "beer batter", "bun", "crouton", "malt", "tempura", "seitan", "fried chicken", "udon"
    ]

    private let ambiguityVocabulary = [
        "fried", "crispy", "special sauce", "chef's special", "house sauce", "marinade", "dumpling", "shared fryer", "seasonal"
    ]
}
