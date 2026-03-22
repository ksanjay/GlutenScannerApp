import SwiftUI
import GlutenFreeCore

struct ReviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @State var document: MenuDocument
    @State private var navigateToResults = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    AppCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Refine the scan")
                            Text("Review extracted dishes")
                                .font(.system(.title, design: .rounded, weight: .bold))
                            Text("Tighten OCR mistakes before scoring. Short edits here make the later safety ranking much more trustworthy.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .center, spacing: 12) {
                                Label("\(Int(document.extractionConfidence * 100))% OCR confidence", systemImage: "doc.text.viewfinder")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(AppPalette.mist.opacity(0.7), in: Capsule())
                                Spacer()
                                Button {
                                    Task {
                                        appModel.updateCurrentDocument(document)
                                        await appModel.analyzeCurrentDocument()
                                        navigateToResults = appModel.currentSession != nil
                                    }
                                } label: {
                                    Label(appModel.isAnalyzing ? "Analyzing..." : "Analyze menu", systemImage: appModel.isAnalyzing ? "hourglass" : "sparkles")
                                        .font(.footnote.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppPalette.accent)
                                .disabled(appModel.isAnalyzing)
                                .accessibilityHint("Scores dishes and opens ranked results.")
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }

                    ForEach(Array(document.sections.enumerated()), id: \.offset) { sectionIndex, section in
                        AppCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text(section.title)
                                        .font(.title3.weight(.bold))
                                    Spacer()
                                    Text("\(section.items.count) items")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIndex, item in
                                    EditableMenuItemCard(item: binding(for: sectionIndex, itemIndex), onDuplicate: {
                                        duplicateItem(sectionIndex: sectionIndex, itemIndex: itemIndex)
                                    })
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .disabled(appModel.isAnalyzing)

            if appModel.isAnalyzing {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                AppCard {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppPalette.accent)
                        Text("Preparing your safer picks")
                            .font(.headline.weight(.bold))
                        Text(appModel.analysisStatus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 280)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Analyzing menu")
                .accessibilityValue(appModel.analysisStatus)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResults) {
            if let currentSession = appModel.currentSession {
                ResultsView(session: currentSession)
            }
        }
        .onChange(of: document) { _, newValue in
            appModel.updateCurrentDocument(newValue)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appModel.isAnalyzing)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.black))
            .tracking(1.1)
            .foregroundStyle(.secondary)
    }

    private func binding(for sectionIndex: Int, _ itemIndex: Int) -> Binding<MenuItem> {
        Binding(
            get: { document.sections[sectionIndex].items[itemIndex] },
            set: { document.sections[sectionIndex].items[itemIndex] = $0 }
        )
    }

    private func duplicateItem(sectionIndex: Int, itemIndex: Int) {
        let item = document.sections[sectionIndex].items[itemIndex]
        document.sections[sectionIndex].items.insert(item, at: itemIndex + 1)
    }
}

private struct EditableMenuItemCard: View {
    @Binding var item: MenuItem
    let onDuplicate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dish")
                .font(.caption.weight(.black))
                .tracking(1)
                .foregroundStyle(.secondary)
            TextField("Dish name", text: $item.name)
                .font(.headline)
                .textFieldStyle(.plain)
            TextField("Description", text: $item.description, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
            HStack {
                TextField("Price", text: Binding(
                    get: { item.price ?? "" },
                    set: { item.price = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.numbersAndPunctuation)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppPalette.mist.opacity(0.55), in: Capsule())
                .frame(maxWidth: 110)
                Spacer()
                Button("Duplicate row", action: onDuplicate)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.8), in: Capsule())
                    .accessibilityLabel("Duplicate dish row")
            }
            .font(.subheadline)
            Text(item.rawText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(AppPalette.mist.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
