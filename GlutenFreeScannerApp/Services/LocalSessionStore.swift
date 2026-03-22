import Foundation
import GlutenFreeCore

struct PersistedState: Codable {
    var profile: UserPreferenceProfile
    var sessions: [AnalysisSession]
}

struct LocalSessionStore {
    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("gluten-friendly-state.json")
    }()

    func save(profile: UserPreferenceProfile, sessions: [AnalysisSession]) {
        let state = PersistedState(profile: profile, sessions: sessions)
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to save state: \(error)")
            #endif
        }
    }

    func load() -> PersistedState {
        guard
            let data = try? Data(contentsOf: fileURL),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            return PersistedState(profile: SampleData.onboardingProfile, sessions: [])
        }
        return state
    }
}
