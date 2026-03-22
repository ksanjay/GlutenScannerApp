import Foundation
import SwiftUI
import UniformTypeIdentifiers
import GlutenFreeCore

@MainActor
final class AppModel: ObservableObject {
    @Published var profile = SampleData.onboardingProfile
    @Published var sessions: [AnalysisSession] = []
    @Published var currentDocument: MenuDocument?
    @Published var currentSession: AnalysisSession?
    @Published var currentStep: AppStep = .home
    @Published var isProcessing = false
    @Published var isAnalyzing = false
    @Published var analysisStatus = "Scoring dishes..."
    @Published var errorMessage: String?

    let parser = MenuParser()
    let analysisEngine = GlutenAnalysisEngine()
    let importService = MenuImportService()
    let store = LocalSessionStore()

    init() {
        loadPersistedState()
    }

    func startSampleScan() {
        let document = parser.parse(rawText: SampleData.demoMenuText, sourceName: "Preview Menu")
        currentDocument = document
        currentStep = .review
    }

    func ingestRecognizedText(_ text: String, sourceName: String) {
        let document = parser.parse(rawText: text, sourceName: sourceName)
        currentDocument = document
        currentStep = .review
    }

    func importPhoto(_ imageData: Data, named sourceName: String) async {
        await runProcessing { [self] in
            let text = try await self.importService.extractText(fromImageData: imageData)
            let document = self.parser.parse(rawText: text, sourceName: sourceName)
            self.currentDocument = document
            self.currentStep = .review
        }
    }

    func importDocument(at url: URL) async {
        await runProcessing { [self] in
            let imported = try await self.importService.extractText(fromDocumentURL: url)
            let document = self.parser.parse(rawText: imported.text, sourceName: imported.sourceName)
            self.currentDocument = document
            self.currentStep = .review
        }
    }

    func updateCurrentDocument(_ document: MenuDocument) {
        currentDocument = document
    }

    func analyzeCurrentDocument() async {
        guard let currentDocument else { return }
        isAnalyzing = true
        analysisStatus = "Checking ingredients and risk signals..."
        try? await Task.sleep(for: .milliseconds(350))
        analysisStatus = "Ranking dishes for your profile..."
        let session = analysisEngine.analyze(document: currentDocument, profile: profile)
        currentSession = session
        sessions.insert(session, at: 0)
        store.save(profile: profile, sessions: sessions)
        currentStep = .results
        isAnalyzing = false
    }

    func reopen(_ session: AnalysisSession) {
        currentDocument = session.menuDocument
        currentSession = session
        currentStep = .results
    }

    func updateProfile(_ profile: UserPreferenceProfile) {
        self.profile = profile
        if let currentDocument {
            var updatedSession = analysisEngine.analyze(document: currentDocument, profile: profile)
            if let existingSession = currentSession {
                updatedSession = AnalysisSession(
                    id: existingSession.id,
                    createdAt: existingSession.createdAt,
                    menuDocument: updatedSession.menuDocument,
                    analyzedItems: updatedSession.analyzedItems
                )
            }
            currentSession = updatedSession
            if let index = sessions.firstIndex(where: { $0.id == updatedSession.id }) {
                sessions[index] = updatedSession
            }
        }
        store.save(profile: profile, sessions: sessions)
    }

    func resetFlow() {
        currentDocument = nil
        currentSession = nil
        currentStep = .home
        isAnalyzing = false
        errorMessage = nil
    }

    private func loadPersistedState() {
        let persisted = store.load()
        self.profile = persisted.profile
        self.sessions = persisted.sessions
    }

    private func runProcessing(_ operation: @escaping () async throws -> Void) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
}

enum AppStep {
    case home
    case review
    case results
    case preferences
    case history
}
