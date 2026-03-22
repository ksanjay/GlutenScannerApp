import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView(selection: Binding(
            get: { appModel.currentStep.tabSelection },
            set: { appModel.currentStep = $0.step }
        )) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(TabSelection.home)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(TabSelection.history)

            NavigationStack {
                PreferencesView()
            }
            .tabItem {
                Label("Preferences", systemImage: "slider.horizontal.3")
            }
            .tag(TabSelection.preferences)
        }
        .preferredColorScheme(.light)
        .background(AppPalette.canvas.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let errorMessage = appModel.errorMessage {
                ToastBanner(message: errorMessage)
                    .padding(.top, 8)
            }
        }
    }
}

private enum TabSelection: Hashable {
    case home
    case history
    case preferences

    var step: AppStep {
        switch self {
        case .home: .home
        case .history: .history
        case .preferences: .preferences
        }
    }
}

private extension AppStep {
    var tabSelection: TabSelection {
        switch self {
        case .home, .review, .results: .home
        case .history: .history
        case .preferences: .preferences
        }
    }
}
