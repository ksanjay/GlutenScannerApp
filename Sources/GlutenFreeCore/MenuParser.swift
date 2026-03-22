import Foundation

public struct MenuParser: Sendable {
    public init() {}

    public func parse(rawText: String, sourceName: String) -> MenuDocument {
        let normalizedLines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var sections: [MenuSection] = []
        var currentSectionTitle = "Chef Picks"
        var currentItems: [MenuItem] = []

        for line in normalizedLines {
            if isSectionHeader(line) {
                if !currentItems.isEmpty {
                    sections.append(MenuSection(title: currentSectionTitle, items: currentItems))
                    currentItems = []
                }
                currentSectionTitle = line.capitalized
                continue
            }

            if let item = parseMenuItem(from: line, sectionTitle: currentSectionTitle) {
                currentItems.append(item)
            }
        }

        if !currentItems.isEmpty {
            sections.append(MenuSection(title: currentSectionTitle, items: currentItems))
        }

        if sections.isEmpty {
            sections = [
                MenuSection(
                    title: "Menu",
                    items: normalizedLines.map {
                        MenuItem(name: inferredName(from: $0), description: inferredDescription(from: $0), sectionTitle: "Menu", rawText: $0)
                    }
                )
            ]
        }

        let confidence = max(0.35, min(0.94, Double(normalizedLines.count) / Double(max(8, rawText.count / 24))))
        return MenuDocument(
            title: inferredTitle(from: sourceName),
            sourceName: sourceName,
            rawText: rawText,
            sections: sections,
            extractionConfidence: confidence
        )
    }

    private func isSectionHeader(_ line: String) -> Bool {
        let uppercase = line == line.uppercased()
        let shortEnough = line.count < 28
        let noPrice = !line.contains("$")
        let noComma = !line.contains(",")
        return shortEnough && noPrice && noComma && (uppercase || commonSections.contains(line.lowercased()))
    }

    private func parseMenuItem(from line: String, sectionTitle: String) -> MenuItem? {
        let priceMatch = line.range(of: #"\$?\d+(\.\d{2})?"#, options: .regularExpression)
        let price = priceMatch.map { String(line[$0]) }
        let cleaned = line.replacingOccurrences(of: #"\$?\d+(\.\d{2})?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }

        return MenuItem(
            name: inferredName(from: cleaned),
            description: inferredDescription(from: cleaned),
            price: price,
            sectionTitle: sectionTitle,
            cuisineTags: inferCuisineTags(in: cleaned, sectionTitle: sectionTitle),
            rawText: line
        )
    }

    private func inferredName(from line: String) -> String {
        let separators = [":", "-", "•", ","]
        for separator in separators where line.contains(separator) {
            return line.components(separatedBy: separator).first?.trimmingCharacters(in: .whitespacesAndNewlines).capitalized ?? line.capitalized
        }

        let words = line.split(separator: " ")
        if words.count > 5 {
            return words.prefix(4).joined(separator: " ").capitalized
        }
        return line.capitalized
    }

    private func inferredDescription(from line: String) -> String {
        let separators = [":", "-", "•"]
        for separator in separators where line.contains(separator) {
            let parts = line.components(separatedBy: separator)
            if parts.count > 1 {
                return parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let words = line.split(separator: " ")
        guard words.count > 4 else { return "" }
        return words.dropFirst(4).joined(separator: " ")
    }

    private func inferCuisineTags(in line: String, sectionTitle: String) -> [String] {
        let haystack = "\(sectionTitle) \(line)".lowercased()
        return cuisineKeywords.compactMap { key, value in
            haystack.contains(key) ? value : nil
        }
    }

    private func inferredTitle(from sourceName: String) -> String {
        sourceName.replacingOccurrences(of: ".pdf", with: "").replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: ".png", with: "")
    }

    private let commonSections: Set<String> = [
        "starters", "appetizers", "mains", "entrees", "desserts", "salads", "tacos", "sushi", "specials", "small plates"
    ]

    private let cuisineKeywords: [String: String] = [
        "taco": "Mexican",
        "salsa": "Mexican",
        "curry": "Indian",
        "masala": "Indian",
        "sushi": "Japanese",
        "ramen": "Japanese",
        "mezze": "Mediterranean",
        "falafel": "Mediterranean",
        "pasta": "Italian",
        "risotto": "Italian",
        "pho": "Vietnamese",
        "kimchi": "Korean"
    ]
}
