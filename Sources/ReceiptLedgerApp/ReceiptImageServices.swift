import Foundation
import UIKit
import Vision

enum ReceiptImageStore {
    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw ReceiptImageStoreError.encodingFailed
        }
        let directory = try receiptsDirectory()
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    static func load(path: String?) -> UIImage? {
        guard let path = path, !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private static func receiptsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("ReceiptLedger", isDirectory: true)
            .appendingPathComponent("Receipts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum ReceiptImageStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "The receipt image could not be stored locally. Try another photo."
    }
}

enum ReceiptTextRecognitionService {
    static func recognize(
        image: UIImage,
        completion: @escaping (Result<String, ReceiptRecognitionError>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(.imageUnavailable))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    finish(.failure(.recognitionFailed), completion: completion)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                guard !lines.isEmpty else {
                    finish(.failure(.noTextFound), completion: completion)
                    return
                }
                finish(.success(lines.joined(separator: "\n")), completion: completion)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                finish(.failure(.recognitionFailed), completion: completion)
            }
        }
    }

    private static func finish(
        _ result: Result<String, ReceiptRecognitionError>,
        completion: @escaping (Result<String, ReceiptRecognitionError>) -> Void
    ) {
        DispatchQueue.main.async { completion(result) }
    }
}

enum ReceiptRecognitionError: LocalizedError {
    case imageUnavailable
    case recognitionFailed
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            return "This receipt image is unavailable. Choose another photo or enter details manually."
        case .recognitionFailed:
            return "We could not read this receipt. Try again or enter details manually."
        case .noTextFound:
            return "No readable receipt text was found. Enter details manually or choose another photo."
        }
    }
}
