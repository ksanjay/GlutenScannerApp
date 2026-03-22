import Foundation
#if canImport(UIKit)
import UIKit
import Vision
import PDFKit
#endif

struct ImportedText {
    let sourceName: String
    let text: String
}

enum MenuImportError: LocalizedError {
    case unsupportedFile
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "That file type is not supported yet. Try an image or PDF."
        case .noTextFound:
            return "We couldn’t read enough menu text. Try a clearer image or use the sample scan."
        }
    }
}

struct MenuImportService {
    func extractText(fromImageData data: Data) async throws -> String {
        #if canImport(UIKit)
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw MenuImportError.noTextFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: MenuImportError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        throw MenuImportError.unsupportedFile
        #endif
    }

    func extractText(fromDocumentURL url: URL) async throws -> ImportedText {
        #if canImport(UIKit)
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                throw MenuImportError.unsupportedFile
            }

            let text = (0..<pdf.pageCount)
                .compactMap { pdf.page(at: $0)?.string }
                .joined(separator: "\n")

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MenuImportError.noTextFound
            }
            return ImportedText(sourceName: url.lastPathComponent, text: text)
        }

        let data = try Data(contentsOf: url)
        let text = try await extractText(fromImageData: data)
        return ImportedText(sourceName: url.lastPathComponent, text: text)
        #else
        throw MenuImportError.unsupportedFile
        #endif
    }
}
