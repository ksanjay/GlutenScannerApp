import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedDocument = false
    @State private var navigateToCapture = false
    @State private var navigateToReview = false
    @State private var navigateToResults = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                primaryActionCard
                importActions
                tasteSnapshot
                if let currentDocument = appModel.currentDocument, appModel.currentStep == .review {
                    NavigationLink {
                        ReviewView(document: currentDocument)
                    } label: {
                        AppCard {
                            Label("Continue menu review", systemImage: "square.and.pencil")
                                .font(.headline)
                            Text("We kept your extraction in place so you can refine item text before analysis.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let currentSession = appModel.currentSession, appModel.currentStep == .results {
                    NavigationLink {
                        ResultsView(session: currentSession)
                    } label: {
                        AppCard {
                            Label("Open latest results", systemImage: "sparkles.rectangle.stack")
                                .font(.headline)
                            Text("Jump back into your safest matches and preference filters.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                recentScans
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Gluten-Friendly")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToReview) {
            if let currentDocument = appModel.currentDocument {
                ReviewView(document: currentDocument)
            }
        }
        .navigationDestination(isPresented: $navigateToCapture) {
            CaptureView()
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let currentSession = appModel.currentSession {
                ResultsView(session: currentSession)
            }
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto, let data = try? await selectedPhoto.loadTransferable(type: Data.self) else { return }
            await appModel.importPhoto(data, named: "Menu Photo")
            self.selectedPhoto = nil
            navigateToReview = appModel.currentDocument != nil
        }
        .fileImporter(
            isPresented: $selectedDocument,
            allowedContentTypes: [.pdf, .image]
        ) { result in
            guard case .success(let url) = result else { return }
            Task {
                await appModel.importDocument(at: url)
                navigateToReview = appModel.currentDocument != nil
            }
        }
        .overlay {
            if appModel.isProcessing {
                ProgressView("Reading menu…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var heroCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("GLUTEN-AWARE DINING")
                    .font(.caption.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(AppPalette.accent)
                Text("Find the safest menu picks faster.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Scan, upload, review, and rank dishes with a conservative gluten-safety lens before you order.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                caution
            }
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(AppPalette.accent.opacity(0.12))
                        .frame(width: 94, height: 94)
                    Circle()
                        .fill(AppPalette.sage.opacity(0.16))
                        .frame(width: 58, height: 58)
                        .offset(x: -26, y: 34)
                }
                .padding(.top, -8)
            }
        }
    }

    private var caution: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(AppPalette.accent)
            Text("Probabilistic guidance only. Always confirm ingredients and cross-contamination risk with staff.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
        }
        .padding(14)
        .background(AppPalette.mist.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var primaryActionCard: some View {
        Button {
            navigateToCapture = true
        } label: {
            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("Start here")
                    Text("Scan a live menu")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Text("Point your camera at the menu and move straight into review mode with extracted dishes already grouped.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 24, weight: .bold))
                        Text("Scan Menu")
                            .font(.headline.weight(.bold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [AppPalette.accent, Color(red: 0.93, green: 0.57, blue: 0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan menu")
        .accessibilityHint("Opens the live camera scanner to capture a restaurant menu.")
    }

    private var importActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Or import a menu")
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    compactActionCard(title: "Photo Library", subtitle: "Import image", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import menu photo")
                .accessibilityHint("Choose a menu image from your photo library.")

                Button {
                    selectedDocument = true
                } label: {
                    compactActionCard(title: "Upload PDF", subtitle: "Read document", systemImage: "doc.text.image")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Upload menu PDF")
                .accessibilityHint("Import a menu document for text extraction.")
            }
        }
    }

    private var tasteSnapshot: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Your taste snapshot")
                Text("Preference matches help rank dishes, but they never override gluten-safety scoring.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(preferenceHighlights, id: \.self) { value in
                            PreferenceChip(title: value)
                        }
                    }
                }
            }
        }
    }

    private var preferenceHighlights: [String] {
        let likedCuisines = Array(appModel.profile.likedCuisines.prefix(2))
        let likedIngredients = Array(appModel.profile.likedIngredients.prefix(2))
        let highlights = likedCuisines + likedIngredients
        return highlights.isEmpty ? ["No preferences yet"] : highlights
    }

    private func compactActionCard(title: String, subtitle: String, systemImage: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppPalette.accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        }
    }

    private var recentScans: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Recent scans")
                if appModel.sessions.isEmpty {
                    Text("Your first analyzed menu will appear here for fast recall.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.sessions.prefix(3)) { session in
                        Button {
                            appModel.reopen(session)
                            navigateToResults = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.menuDocument.title)
                                        .font(.headline)
                                    Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                ConfidenceBadge(tier: session.analyzedItems.first?.confidenceTier ?? .mightBeGood)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
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
