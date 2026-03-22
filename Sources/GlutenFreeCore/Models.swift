import Foundation

public enum GlutenConfidenceTier: String, Codable, CaseIterable, Sendable {
    case definitelyGood
    case mediumProbability
    case mightBeGood

    public var title: String {
        switch self {
        case .definitelyGood: "Definitely good"
        case .mediumProbability: "Medium probability"
        case .mightBeGood: "Might be good"
        }
    }

    public var sortPriority: Int {
        switch self {
        case .definitelyGood: 0
        case .mediumProbability: 1
        case .mightBeGood: 2
        }
    }
}

public enum EvidenceKind: String, Codable, Sendable {
    case safeSignal
    case riskSignal
    case ambiguity
    case preference
}

public struct AnalysisEvidence: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var kind: EvidenceKind
    public var label: String
    public var weight: Double

    public init(id: UUID = UUID(), kind: EvidenceKind, label: String, weight: Double) {
        self.id = id
        self.kind = kind
        self.label = label
        self.weight = weight
    }
}

public struct PreferenceMatch: Codable, Hashable, Sendable {
    public var cuisineHits: [String]
    public var likedIngredientHits: [String]
    public var dislikedIngredientHits: [String]

    public init(
        cuisineHits: [String] = [],
        likedIngredientHits: [String] = [],
        dislikedIngredientHits: [String] = []
    ) {
        self.cuisineHits = cuisineHits
        self.likedIngredientHits = likedIngredientHits
        self.dislikedIngredientHits = dislikedIngredientHits
    }

    public var score: Int {
        (cuisineHits.count * 3) + (likedIngredientHits.count * 2) - (dislikedIngredientHits.count * 4)
    }

    public var isMatch: Bool {
        score > 0 && dislikedIngredientHits.isEmpty
    }
}

public struct UserPreferenceProfile: Codable, Hashable, Sendable {
    public var likedCuisines: [String]
    public var likedIngredients: [String]
    public var dislikedIngredients: [String]
    public var conservativeMode: Bool

    public init(
        likedCuisines: [String] = [],
        likedIngredients: [String] = [],
        dislikedIngredients: [String] = [],
        conservativeMode: Bool = true
    ) {
        self.likedCuisines = likedCuisines
        self.likedIngredients = likedIngredients
        self.dislikedIngredients = dislikedIngredients
        self.conservativeMode = conservativeMode
    }
}

public struct MenuItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var price: String?
    public var sectionTitle: String?
    public var cuisineTags: [String]
    public var rawText: String

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        price: String? = nil,
        sectionTitle: String? = nil,
        cuisineTags: [String] = [],
        rawText: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.sectionTitle = sectionTitle
        self.cuisineTags = cuisineTags
        self.rawText = rawText
    }

    public var combinedText: String {
        [name, description, rawText].joined(separator: " ").lowercased()
    }
}

public struct MenuSection: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var items: [MenuItem]

    public init(id: UUID = UUID(), title: String, items: [MenuItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct MenuDocument: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var sourceName: String
    public var extractedAt: Date
    public var rawText: String
    public var sections: [MenuSection]
    public var extractionConfidence: Double

    public init(
        id: UUID = UUID(),
        title: String,
        sourceName: String,
        extractedAt: Date = .now,
        rawText: String,
        sections: [MenuSection],
        extractionConfidence: Double
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.extractedAt = extractedAt
        self.rawText = rawText
        self.sections = sections
        self.extractionConfidence = extractionConfidence
    }

    public var allItems: [MenuItem] {
        sections.flatMap(\.items)
    }
}

public struct AnalyzedMenuItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var item: MenuItem
    public var confidenceTier: GlutenConfidenceTier
    public var evidence: [AnalysisEvidence]
    public var explanation: String
    public var missingInfo: Bool
    public var preferenceMatch: PreferenceMatch

    public init(
        id: UUID = UUID(),
        item: MenuItem,
        confidenceTier: GlutenConfidenceTier,
        evidence: [AnalysisEvidence],
        explanation: String,
        missingInfo: Bool,
        preferenceMatch: PreferenceMatch = .init()
    ) {
        self.id = id
        self.item = item
        self.confidenceTier = confidenceTier
        self.evidence = evidence
        self.explanation = explanation
        self.missingInfo = missingInfo
        self.preferenceMatch = preferenceMatch
    }
}

public struct AnalysisSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var menuDocument: MenuDocument
    public var analyzedItems: [AnalyzedMenuItem]

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        menuDocument: MenuDocument,
        analyzedItems: [AnalyzedMenuItem]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.menuDocument = menuDocument
        self.analyzedItems = analyzedItems
    }
}
