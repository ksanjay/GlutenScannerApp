import SwiftUI
import GlutenFreeCore

struct HistoryView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if appModel.sessions.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No saved scans yet")
                                .font(.title3.weight(.bold))
                            Text("Analyze a menu once and it will stay here for quick restaurant-to-restaurant comparison.")
                                .foregroundStyle(.secondary)
                            Text("Your latest results will appear here automatically after the first review flow.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(appModel.sessions) { session in
                        NavigationLink {
                            ResultsView(session: session)
                        } label: {
                            AppCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(session.menuDocument.title)
                                            .font(.headline)
                                        Spacer()
                                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(session.analyzedItems.filter { $0.confidenceTier == .definitelyGood }.count) top-tier items")
                                        .font(.subheadline)
                                    Text(session.menuDocument.sourceName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("History")
    }
}
