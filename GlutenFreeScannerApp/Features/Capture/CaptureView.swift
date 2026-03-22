import SwiftUI
import GlutenFreeCore
#if canImport(VisionKit)
import VisionKit
#endif

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var recognizedText = ""
    @State private var navigateToReview = false

    var body: some View {
        VStack(spacing: 0) {
            scannerSurface

            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Frame the menu")
                        .font(.title3.weight(.bold))
                    Text("Move slowly across section headers and dish descriptions. The review step will let you correct OCR before scoring.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !recognizedText.isEmpty {
                        Text(recognizedText)
                            .font(.footnote)
                            .lineLimit(5)
                            .padding(12)
                            .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    HStack {
                        Button("Use captured text") {
                            let source = recognizedText.isEmpty ? SampleData.demoMenuText : recognizedText
                            appModel.ingestRecognizedText(source, sourceName: "Live Scan")
                            navigateToReview = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppPalette.accent)

                        Button("Try sample menu") {
                            appModel.startSampleScan()
                            navigateToReview = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(20)
        }
        .background(AppPalette.canvas.ignoresSafeArea())
        .navigationTitle("Scan Menu")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToReview) {
            if let currentDocument = appModel.currentDocument {
                ReviewView(document: currentDocument)
            }
        }
    }

    @ViewBuilder
    private var scannerSurface: some View {
        #if canImport(VisionKit)
        LiveTextScanner(recognizedText: $recognizedText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .padding(28)
            }
        #else
        AppCard {
            Text("Live camera scanning is available when opened in Xcode on an iPhone 15+.")
        }
        .padding(20)
        #endif
    }
}

#if canImport(VisionKit)
private struct LiveTextScanner: UIViewControllerRepresentable {
    @Binding var recognizedText: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(recognizedText: $recognizedText)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var recognizedText: String

        init(recognizedText: Binding<String>) {
            _recognizedText = recognizedText
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                recognizedText = [recognizedText, text.transcript]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            let transcripts = allItems.compactMap { item -> String? in
                guard case .text(let text) = item else { return nil }
                return text.transcript
            }
            recognizedText = transcripts.joined(separator: "\n")
        }
    }
}
#endif
