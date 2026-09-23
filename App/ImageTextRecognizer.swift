import UIKit
import Vision

/// On-device OCR: the photo never leaves the phone, only the recognized text goes to the model.
enum ImageTextRecognizer {
    enum RecognitionError: LocalizedError {
        case noText

        var errorDescription: String? {
            String(localized: "No text found in the photo.")
        }
    }

    static func text(in image: UIImage, languages: LanguageSettings) async throws -> String {
        guard let cgImage = image.cgImage else { throw RecognitionError.noText }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        // Hint the likely languages so the detector does not wander.
        request.recognitionLanguages = [languages.foreign.code, languages.native.code]

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try await Task.detached(priority: .userInitiated) { try handler.perform([request]) }.value

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = Self.joinLines(lines)
        guard !text.isEmpty else { throw RecognitionError.noText }
        return text
    }

    /// Vision returns one string per visual line; glue them back into paragraphs.
    private static func joinLines(_ lines: [String]) -> String {
        var result = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if result.isEmpty {
                result = trimmed
            } else if result.hasSuffix("-") {
                result.removeLast()
                result += trimmed
            } else if let last = result.last, ".!?:".contains(last) {
                result += "\n" + trimmed
            } else {
                result += " " + trimmed
            }
        }
        return result
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
