import SwiftUI
import GlutenFreeCore

@main
struct GlutenFriendlyScannerApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
        }
    }
}
