//
//  NLEmbeddingService.swift
//  MeditateAndNote
//
//  On-device embeddings via the NaturalLanguage framework (iOS 14+, so the
//  17.6 deployment target needs no feature-gating). Splits text into sentences,
//  embeds each with the sentence model, and averages the vectors into one
//  normalized document vector. Falls back gracefully when the model for a
//  language isn't bundled.
//

import Foundation
import NaturalLanguage
import OSLog

final class NLEmbeddingService: EmbeddingService {

    private let logger = Logger(subsystem: Config.bundleID, category: "NLEmbedding")

    /// Models suspected of being bundled on-device. English always ships;
    /// others are tried by dominant language with English as the fallback.
    private let supportedLanguages: [NLLanguage] = [
        .english, .french, .german, .italian, .spanish, .portuguese,
    ]

    var isAvailable: Bool {
        NLEmbedding.sentenceEmbedding(for: .english) != nil
    }

    func embed(_ text: String) async throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let embedding = try await embeddingModel(for: trimmed) else {
            throw EmbeddingError.modelUnavailable
        }

        let sentences = splitIntoSentences(trimmed)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var sum: [Double] = []
        var count = 0
        for sentence in sentences {
            guard let vector = embedding.vector(for: sentence) else { continue }
            if sum.isEmpty {
                sum = vector
            } else {
                for i in vector.indices { sum[i] += vector[i] }
            }
            count += 1
        }
        guard count > 0 else { return [] }

        let length = sqrt(sum.reduce(0) { $0 + $1 * $1 })
        return length > 0 ? sum.map { Float($0 / length) } : []
    }

    // MARK: - Helpers

    /// Picks a sentence embedding model for the dominant language of the text,
    /// with English as the universal fallback. Runs off the caller's executor;
    /// model lookup is pure, so this is just a typed alias seam for tests.
    private func embeddingModel(for text: String) async throws -> NLEmbedding? {
        let language = NLLanguageRecognizer.dominantLanguage(for: text) ?? .english
        let candidates = [language] + supportedLanguages.filter { $0 != language }
        for candidate in candidates {
            if let model = NLEmbedding.sentenceEmbedding(for: candidate) {
                return model
            }
        }
        logger.info("No sentence embedding model for '\(language.rawValue)'")
        return nil
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map {
            String(text[$0])
        }
    }
}