import SwiftUI
import GlutenFreeCore

struct ResultsView: View {
    @EnvironmentObject private var appModel: AppModel
    let session: AnalysisSession
    @State private var selectedScope: ResultScope = .bestMatches
    @State private var selectedCuisine: String = "All"
    @State private var safestFirst = true

    private var cuisines: [String] {
        let tags = Set(session.analyzedItems.flatMap(\.item.cuisineTags))
        return ["All"] + tags.sorted()
    }

    private var filteredItems: [AnalyzedMenuItem] {
        var items = session.analyzedItems

        if selectedScope == .bestMatches {
            let matched = items.filter { $0.preferenceMatch.isMatch && $0.preferenceMatch.dislikedIngredientHits.isEmpty }
            items = matched.isEmpty ? items : matched
        }

        if selectedCuisine != "All" {
            items = items.filter { $0.item.cuisineTags.contains(selectedCuisine) || $0.item.sectionTitle == selectedCuisine }
        }

        if safestFirst {
            items = items.sorted {
                if $0.confidenceTier.sortPriority != $1.confidenceTier.sortPriority {
                    return $0.confidenceTier.sortPriority < $1.confidenceTier.sortPriority
                }
                return $0.preferenceMatch.score > $1.preferenceMatch.score
            }
        }

        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Ranked recommendations")
                        Text("Safer menu picks")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text("Use these tiers as a starting point, not a substitute for ingredient confirmation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        cautionBanner
                    }
                }

                filters

                if filteredItems.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("No matches yet")
                            Text("Nothing fits this filter mix.")
                                .font(.title3.weight(.bold))
                            Text("Try widening cuisine filters or switch to all safer options to see the best available picks.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(GlutenConfidenceTier.allCases, id: \.self) { tier in
                    let group = filteredItems.filter { $0.confidenceTier == tier }
                    if !group.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tier.title)
                                        .font(.title3.weight(.bold))
                                    Text("\(group.count) dishes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                ConfidenceBadge(tier: tier)
                            }
                            ForEach(group) { item in
                                ResultCard(item: item)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle(session.menuDocument.title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedScope)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedCuisine)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: safestFirst)
    }

    private var cautionBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.text.rectangle.fill")
                .foregroundStyle(AppPalette.accent)
            Text("If fryer setup, sauces, marinades, or soy-based ingredients are unclear, ask staff before ordering.")
                .font(.footnote.weight(.semibold))
        }
        .padding(14)
        .background(AppPalette.mist.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var filters: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Tune the list")
                Picker("Scope", selection: $selectedScope) {
                    ForEach(ResultScope.allCases, id: \.self) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(cuisines, id: \.self) { cuisine in
                            Button {
                                selectedCuisine = cuisine
                            } label: {
                                PreferenceChip(title: cuisine, isSelected: selectedCuisine == cuisine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Toggle("Show safest first", isOn: $safestFirst)
                    .tint(AppPalette.accent)
                    .accessibilityHint("Sorts higher confidence dishes to the top of each results list.")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.black))
            .tracking(1.1)
            .foregroundStyle(.secondary)
    }
}

private enum ResultScope: CaseIterable {
    case bestMatches
    case allSaferOptions

    var title: String {
        switch self {
        case .bestMatches: "Best matches for you"
        case .allSaferOptions: "All safer options"
        }
    }
}

private struct ResultCard: View {
    let item: AnalyzedMenuItem

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.item.name)
                            .font(.title3.weight(.bold))
                        if !item.item.description.isEmpty {
                            Text(item.item.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    ConfidenceBadge(tier: item.confidenceTier)
                }

                HStack(spacing: 8) {
                    if item.preferenceMatch.isMatch {
                        Text("Matches your profile")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppPalette.accent.opacity(0.14), in: Capsule())
                    }
                    if item.missingInfo {
                        Text("Needs confirmation")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppPalette.amber.opacity(0.18), in: Capsule())
                    }
                }

                Text(item.explanation)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.evidence.prefix(4)) { evidence in
                            Text(evidence.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppPalette.mist.opacity(0.65), in: Capsule())
                        }
                    }
                }

                if item.missingInfo {
                    Label("Ask staff to confirm preparation details.", systemImage: "questionmark.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.accent)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.item.name), \(item.confidenceTier.title)")
        .accessibilityValue(item.explanation)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
    }
}
