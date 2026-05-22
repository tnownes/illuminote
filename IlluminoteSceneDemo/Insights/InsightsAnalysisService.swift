import Foundation
import NaturalLanguage
import SwiftData
import Accelerate

struct InsightAnalysisInput {
    let entryID: UUID
    let date: Date
    let experienceType: ExperienceType?
    let examenMode: ExamenMode
    let text: String
    let title: String
    let secondaryDetail: String?
    let focusDetail: String?
}

struct InsightEntrySuggestion: Identifiable, Hashable {
    var id: UUID { entryID }
    let entryID: UUID
    let evidenceSnippet: String
    let confidence: Double
}

struct InsightSuggestion: Identifiable, Hashable {
    let id: UUID
    let lens: InsightLens
    let kind: InsightNodeKind
    var title: String
    var normalizedTitle: String
    let source: InsightNodeSource
    let scope: ThemeClusterScope?
    let experienceType: ExperienceType?
    let score: Double
    let confidence: Double
    let keywordHighlights: [String]
    let entries: [InsightEntrySuggestion]
    let sourceThemeClusterID: UUID?
    let taxonomyIdentifier: String?
    var persistedNodeID: UUID?
    var isAccepted: Bool
}

struct InsightAIRerankPrompt {
    let system: String
    let user: String
}

struct InsightsAnalysisService {
    let similarityThreshold: Double
    let taxonomyMatchThreshold: Double
    let minThemeClusterSize: Int
    let maxSuggestions: Int

    init(
        similarityThreshold: Double = 0.72,
        taxonomyMatchThreshold: Double = 0.62,
        minThemeClusterSize: Int = 2,
        maxSuggestions: Int = 8
    ) {
        self.similarityThreshold = similarityThreshold
        self.taxonomyMatchThreshold = taxonomyMatchThreshold
        self.minThemeClusterSize = minThemeClusterSize
        self.maxSuggestions = maxSuggestions
    }

    // MARK: - Phase 2: Semantic Indexing & Threading

    /// Generates a semantic vector using local NLEmbedding for the given text.
    func generateSemanticEmbedding(text: String) -> [Double]? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return nil }
        
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) {
            return sentenceEmbedding.vector(for: cleanText)
        } else if let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            return wordEmbedding.vector(for: cleanText)
        }
        return nil
    }

    /// Performs fast vDSP cosine similarity matching between two Double arrays.
    func cosineSimilarity(a: [Double], b: [Double]) -> Double {
        guard a.count == b.count, a.count > 0 else { return 0.0 }
        var dotProduct: Double = 0
        vDSP_dotprD(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        
        var magA: Double = 0
        vDSP_svesqD(a, 1, &magA, vDSP_Length(a.count))
        magA = sqrt(magA)
        
        var magB: Double = 0
        vDSP_svesqD(b, 1, &magB, vDSP_Length(b.count))
        magB = sqrt(magB)
        
        guard magA > 0, magB > 0 else { return 0.0 }
        return dotProduct / (magA * magB)
    }

    private static let realTimeTagger: NLTagger = {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        return tagger
    }()
    
    /// Extracts real-time concepts via NLTagger for dynamic typing context.
    func extractConcepts(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let tagger = Self.realTimeTagger
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        let range = text.startIndex..<text.endIndex
        
        var concepts = Set<String>()
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if tag == .noun {
                concepts.insert(String(text[tokenRange]).lowercased())
            }
            return true
        }
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if tag == .personalName || tag == .organizationName || tag == .placeName {
                concepts.insert(String(text[tokenRange]).lowercased())
            }
            return true
        }
        return Array(concepts)
    }

    func makeInputs(from entries: [ExamenSession]) -> [InsightAnalysisInput] {
        entries.map {
            let title = $0.resolvedPrimaryDetail
                ?? $0.resolvedSecondaryDetail
                ?? $0.personalStatement.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue
                ?? "Reflection"

            return InsightAnalysisInput(
                entryID: $0.id,
                date: $0.date,
                experienceType: $0.experienceType,
                examenMode: $0.examenMode,
                text: $0.themeAnalysisText(),
                title: title,
                secondaryDetail: $0.resolvedSecondaryDetail,
                focusDetail: $0.resolvedFocusDetail
            )
        }
    }

    func analyzeExperiences(entries: [InsightAnalysisInput]) -> [InsightSuggestion] {
        guard !entries.isEmpty else { return [] }

        let repeatedAnchors = Dictionary(grouping: entries.compactMap { input -> String? in
            guard let detail = normalizedExperienceAnchor(from: input) else { return nil }
            return "\(input.experienceType?.canonical.rawValue ?? ExperienceType.other.rawValue)|\(detail)"
        }, by: { $0 }).mapValues(\.count)

        struct ExperienceGroup {
            let key: String
            let title: String
            let normalizedTitle: String
            let experienceType: ExperienceType
            let entries: [InsightAnalysisInput]
        }

        let groupsByKey = Dictionary(grouping: entries) { input -> String in
            let type = input.experienceType?.canonical ?? .other
            if let anchor = normalizedExperienceAnchor(from: input) {
                let composite = "\(type.rawValue)|\(anchor)"
                if repeatedAnchors[composite, default: 0] >= 2 {
                    return composite
                }
            }
            return "\(type.rawValue)|type"
        }

        let groups: [ExperienceGroup] = groupsByKey.compactMap { key, inputs in
            guard let first = inputs.first else { return nil }
            let type = first.experienceType?.canonical ?? .other
            let normalizedAnchor = normalizedExperienceAnchor(from: first)

            let title: String
            if let normalizedAnchor, repeatedAnchors["\(type.rawValue)|\(normalizedAnchor)", default: 0] >= 2 {
                title = first.secondaryDetail?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue
                    ?? first.focusDetail?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue
                    ?? type.displayName
            } else {
                title = "\(type.displayName) Moments"
            }

            return ExperienceGroup(
                key: key,
                title: title,
                normalizedTitle: InsightNode.normalize(title),
                experienceType: type,
                entries: inputs.sorted(by: { $0.date > $1.date })
            )
        }

        return groups
            .sorted {
                if $0.entries.count == $1.entries.count {
                    return $0.title < $1.title
                }
                return $0.entries.count > $1.entries.count
            }
            .prefix(maxSuggestions)
            .map { group in
                let entrySuggestions = group.entries.map { input in
                    InsightEntrySuggestion(
                        entryID: input.entryID,
                        evidenceSnippet: evidenceSnippet(
                            from: input.text,
                            preferredTokens: Array(extractTokens(from: input.title).prefix(3))
                        ),
                        confidence: min(0.68 + (Double(group.entries.count - 1) * 0.08), 0.94)
                    )
                }

                let confidence = min(0.64 + (Double(group.entries.count - 1) * 0.08), 0.92)
                let score = min(0.58 + (Double(group.entries.count) * 0.1), 0.96)

                return InsightSuggestion(
                    id: UUID(),
                    lens: .experiences,
                    kind: .experience,
                    title: group.title,
                    normalizedTitle: group.normalizedTitle,
                    source: .deterministic,
                    scope: nil,
                    experienceType: group.experienceType,
                    score: score,
                    confidence: confidence,
                    keywordHighlights: Array(extractTokens(from: group.title).prefix(3)),
                    entries: entrySuggestions,
                    sourceThemeClusterID: nil,
                    taxonomyIdentifier: group.key,
                    persistedNodeID: nil,
                    isAccepted: false
                )
            }
    }

    func analyzeThemes(
        entries: [InsightAnalysisInput],
        taxonomyTitles: [(id: String, title: String, description: String)],
        scope: ThemeClusterScope,
        selectedExperience: ExperienceType?
    ) -> [InsightSuggestion] {
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        let docs = entries.compactMap { buildDocument(input: $0, embedding: embedding) }
        guard docs.count >= minThemeClusterSize else { return [] }

        let taxonomyCandidates = taxonomyTitles.map { makeTaxonomyCandidate(from: $0, embedding: embedding) }
        let components = connectedComponents(for: docs)

        let suggestions = components.compactMap { component -> InsightSuggestion? in
            let componentDocs = component.map { docs[$0] }
            guard componentDocs.count >= minThemeClusterSize else { return nil }

            let sharedTokens = commonTokens(for: componentDocs)
            let keywords = Array(sharedTokens.prefix(3))
            let centroid = centroidVector(for: componentDocs)

            let taxonomyMatch = bestTaxonomyMatch(
                for: componentDocs,
                centroid: centroid,
                sharedTokens: Set(sharedTokens),
                taxonomy: taxonomyCandidates
            )

            let title: String
            if taxonomyMatch.score >= taxonomyMatchThreshold {
                title = taxonomyMatch.title
            } else {
                title = emergentLabel(from: sharedTokens, fallbackText: componentDocs.first?.text ?? "Theme")
            }

            let score = clusterScore(componentDocs: componentDocs, scope: scope, sharedTokens: sharedTokens)
            let confidence = clusterConfidence(componentDocs: componentDocs, sharedTokens: sharedTokens)

            let entries = componentDocs.map { doc in
                InsightEntrySuggestion(
                    entryID: doc.entryID,
                    evidenceSnippet: evidenceSnippet(from: doc.text, preferredTokens: keywords),
                    confidence: entryConfidence(for: doc, in: componentDocs, centroid: centroid)
                )
            }

            return InsightSuggestion(
                id: UUID(),
                lens: .themes,
                kind: .theme,
                title: title,
                normalizedTitle: InsightNode.normalize(title),
                source: .deterministic,
                scope: scope,
                experienceType: selectedExperience,
                score: score,
                confidence: confidence,
                keywordHighlights: keywords,
                entries: entries.sorted(by: { $0.confidence > $1.confidence }),
                sourceThemeClusterID: nil,
                taxonomyIdentifier: taxonomyMatch.identifier,
                persistedNodeID: nil,
                isAccepted: false
            )
        }

        return suggestions
            .sorted {
                if $0.score == $1.score {
                    return $0.confidence > $1.confidence
                }
                return $0.score > $1.score
            }
            .prefix(maxSuggestions)
            .map { $0 }
    }

    func analyzeValues(
        entries: [InsightAnalysisInput],
        profile: UserProfile?
    ) -> [InsightSuggestion] {
        analyzeTaxonomyLens(
            entries: entries,
            taxonomy: ProfessionalValueTaxonomy.shared,
            lens: .values,
            kind: .value,
            profile: profile,
            baseThreshold: 0.26
        )
    }

    func analyzeWhy(
        entries: [InsightAnalysisInput],
        profile: UserProfile?
    ) -> [InsightSuggestion] {
        analyzeTaxonomyLens(
            entries: entries,
            taxonomy: MotivationTaxonomy.shared,
            lens: .why,
            kind: .motivation,
            profile: profile,
            baseThreshold: 0.22
        )
    }

    @MainActor
    func refineWithOptionalAI(
        _ suggestions: [InsightSuggestion],
        lens: InsightLens,
        settings: AppSettings
    ) async -> [InsightSuggestion] {
        guard settings.effectiveAIEnabled else { return suggestions }
        guard !suggestions.isEmpty else { return suggestions }
        guard AIModelRuntimePolicy.isDeviceEligibleForAnyAI else { return suggestions }

        let prompt = buildAIRerankPrompt(for: suggestions, lens: lens)
        let requestedProfile = AIModelRuntimePolicy.requestedProfile

        await MLXManager.shared.loadModelIfNeeded(preferredProfile: requestedProfile)
        guard MLXManager.shared.isModelLoaded else { return suggestions }

        let override = MLXManager.GenerationOverride(
            maxTokens: 160,
            temperature: 0,
            topP: 0.15,
            topK: 16,
            minP: nil,
            repetitionPenalty: 1.01,
            repetitionContextSize: 64,
            presencePenalty: 0,
            presenceContextSize: 64,
            frequencyPenalty: 0,
            frequencyContextSize: 64,
            maxKVSize: 2048,
            kvBits: nil,
            prefillStepSize: 192
        )

        await MLXManager.shared.generate(
            systemPrompt: prompt.system,
            userPrompt: prompt.user,
            requestedProfile: requestedProfile,
            override: override
        )

        return applyAIRefinementResponse(MLXManager.shared.currentResponse, to: suggestions)
    }

    func buildAIRerankPrompt(for suggestions: [InsightSuggestion], lens: InsightLens) -> InsightAIRerankPrompt {
        let limited = suggestions.prefix(6).map { suggestion in
            [
                "id": suggestion.id.uuidString,
                "title": suggestion.title,
                "confidence": String(format: "%.3f", suggestion.confidence),
                "score": String(format: "%.3f", suggestion.score),
                "keywords": suggestion.keywordHighlights.joined(separator: ", "),
                "evidence": suggestion.entries.prefix(2).map(\.evidenceSnippet).joined(separator: " | ")
            ]
        }

        let payload = limited.map { item in
            """
            {"id":"\(item["id"] ?? "")","title":"\(escapeJSONString(item["title"] ?? ""))","confidence":\(item["confidence"] ?? "0"),"score":\(item["score"] ?? "0"),"keywords":"\(escapeJSONString(item["keywords"] ?? ""))","evidence":"\(escapeJSONString(item["evidence"] ?? ""))"}
            """
        }.joined(separator: ",\n")

        let system = """
        You are a strict local classifier for Illuminote. Do not write prose. Do not summarize notes. Do not author content.
        Return only compact JSON using this exact shape:
        {"rankings":[{"id":"UUID","confidence":0.0,"keep":true}]}
        Keep only candidates grounded in note evidence for the \(lens.title.lowercased()) lens.
        """

        let user = """
        Re-rank these candidates. You may only return JSON and must not include any explanation.
        {
          "lens": "\(lens.rawValue)",
          "candidates": [
            \(payload)
          ]
        }
        """

        return InsightAIRerankPrompt(system: system, user: user)
    }

    func applyAIRefinementResponse(
        _ response: String,
        to suggestions: [InsightSuggestion]
    ) -> [InsightSuggestion] {
        guard let jsonObject = extractJSONObject(from: response),
              let data = jsonObject.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(AIRankingEnvelope.self, from: data)
        else {
            return suggestions
        }

        let rankings: [UUID: AIRankingItem] = Dictionary(uniqueKeysWithValues: envelope.rankings.compactMap { item in
            guard let uuid = UUID(uuidString: item.id) else { return nil }
            return (uuid, item)
        })

        let refined = suggestions.compactMap { suggestion -> InsightSuggestion? in
            guard let ranking = rankings[suggestion.id] else { return suggestion }
            guard ranking.keep else { return nil }

            var next = suggestion
            next = InsightSuggestion(
                id: next.id,
                lens: next.lens,
                kind: next.kind,
                title: next.title,
                normalizedTitle: next.normalizedTitle,
                source: .aiAssisted,
                scope: next.scope,
                experienceType: next.experienceType,
                score: next.score,
                confidence: min(max((next.confidence + ranking.confidence) / 2, 0), 1),
                keywordHighlights: next.keywordHighlights,
                entries: next.entries,
                sourceThemeClusterID: next.sourceThemeClusterID,
                taxonomyIdentifier: next.taxonomyIdentifier,
                persistedNodeID: next.persistedNodeID,
                isAccepted: next.isAccepted
            )
            return next
        }

        return refined.sorted {
            if $0.confidence == $1.confidence {
                return $0.score > $1.score
            }
            return $0.confidence > $1.confidence
        }
    }

    @MainActor
    static func backfillInsights(in context: ModelContext) {
        do {
            let clusters = try context.fetch(FetchDescriptor<ThemeCluster>())
            let bundles = try context.fetch(FetchDescriptor<ThemeBundle>())
            guard !clusters.isEmpty || !bundles.isEmpty else { return }

            let sessions = try context.fetch(FetchDescriptor<ExamenSession>())
            let sessionByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            let existingNodes = try context.fetch(FetchDescriptor<InsightNode>())

            var nodesByClusterID = Dictionary(uniqueKeysWithValues: existingNodes.compactMap { node in
                node.sourceThemeClusterID.map { ($0, node) }
            })
            var nodesByKey = Dictionary(uniqueKeysWithValues: existingNodes.map {
                (backfillKey(kind: $0.kind, normalizedTitle: $0.normalizedTitle, experienceType: $0.experienceType), $0)
            })
            var existingLinkKeys = Set(existingNodes.flatMap { node in
                node.links.map { "\(node.id.uuidString)|\($0.entryID.uuidString)" }
            })
            var didMutate = false

            for cluster in clusters where cluster.isAccepted && !cluster.isHidden {
                let key = backfillKey(kind: .theme, normalizedTitle: cluster.normalizedLabel, experienceType: cluster.experienceType)
                let node = nodesByClusterID[cluster.id] ?? nodesByKey[key] ?? InsightNode(
                    kind: .theme,
                    title: cluster.label,
                    normalizedTitle: cluster.normalizedLabel,
                    status: .accepted,
                    confidence: cluster.confidence,
                    source: .deterministic,
                    experienceType: cluster.experienceType,
                    isPinned: false,
                    isHidden: false,
                    sourceThemeClusterID: cluster.id
                )

                if nodesByClusterID[cluster.id] == nil && nodesByKey[key] == nil {
                    context.insert(node)
                    didMutate = true
                }

                node.title = cluster.label
                node.normalizedTitle = cluster.normalizedLabel
                node.status = .accepted
                node.confidence = max(node.confidence, cluster.confidence)
                node.source = .deterministic
                node.experienceType = cluster.experienceType
                node.isHidden = false
                node.sourceThemeClusterID = cluster.id
                node.updatedAt = .now
                nodesByClusterID[cluster.id] = node
                nodesByKey[key] = node

                for clusterLink in cluster.links {
                    let linkKey = "\(node.id.uuidString)|\(clusterLink.entryID.uuidString)"
                    guard !existingLinkKeys.contains(linkKey) else { continue }
                    let link = InsightEntryLink(
                        entryID: clusterLink.entryID,
                        evidenceSnippet: clusterLink.evidenceSnippet,
                        confidence: clusterLink.confidence,
                        insightNode: node
                    )
                    context.insert(link)
                    existingLinkKeys.insert(linkKey)
                    didMutate = true
                }
            }

            for bundle in bundles where !bundle.entryIDs.isEmpty {
                let normalizedTitle = InsightNode.normalize(bundle.themeLabel)
                let key = backfillKey(kind: .theme, normalizedTitle: normalizedTitle, experienceType: nil)
                let node = bundle.sourceClusterID.flatMap { nodesByClusterID[$0] } ?? nodesByKey[key] ?? InsightNode(
                    kind: .theme,
                    title: bundle.themeLabel,
                    normalizedTitle: normalizedTitle,
                    status: .accepted,
                    confidence: 0.82,
                    source: .manual,
                    experienceType: nil,
                    isPinned: true,
                    isHidden: false,
                    sourceThemeClusterID: bundle.sourceClusterID
                )

                if bundle.sourceClusterID == nil && nodesByKey[key] == nil {
                    context.insert(node)
                    didMutate = true
                }

                node.status = .accepted
                node.source = bundle.sourceClusterID == nil ? .manual : node.source
                node.isPinned = true
                node.isHidden = false
                node.touch()
                if let sourceThemeClusterID = bundle.sourceClusterID {
                    node.sourceThemeClusterID = sourceThemeClusterID
                    nodesByClusterID[sourceThemeClusterID] = node
                }
                nodesByKey[key] = node

                for entryID in bundle.entryIDs {
                    let linkKey = "\(node.id.uuidString)|\(entryID.uuidString)"
                    guard !existingLinkKeys.contains(linkKey) else { continue }
                    let snippet = node.links.first(where: { $0.entryID == entryID })?.evidenceSnippet
                        ?? sessionByID[entryID].map { truncatedEvidenceSnippet(from: $0.themeAnalysisText()) }
                        ?? "Linked reflection"

                    let link = InsightEntryLink(
                        entryID: entryID,
                        evidenceSnippet: snippet,
                        confidence: 0.8,
                        insightNode: node
                    )
                    context.insert(link)
                    existingLinkKeys.insert(linkKey)
                    didMutate = true
                }
            }

            if didMutate {
                try context.save()
            }
        } catch {
            print("⚠️ Failed to backfill insight nodes: \(error)")
        }
    }

    private func analyzeTaxonomyLens(
        entries: [InsightAnalysisInput],
        taxonomy: [InsightTaxonomyTerm],
        lens: InsightLens,
        kind: InsightNodeKind,
        profile: UserProfile?,
        baseThreshold: Double
    ) -> [InsightSuggestion] {
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        let docs = entries.compactMap { buildDocument(input: $0, embedding: embedding) }
        guard !docs.isEmpty else { return [] }

        let track = profile?.preProfessionalTrack?.canonical
        let degreeIntent = profile?.degreeIntent ?? .md
        let filteredTerms = taxonomy.filter { $0.supports(track: track, degreeIntent: degreeIntent) }

        var suggestions: [InsightSuggestion] = []

        for term in filteredTerms {
            let candidate = makeTaxonomyCandidate(from: (term.id, term.title, term.keywords.joined(separator: " ")), embedding: embedding)
            let matches: [(Document, Double)] = docs.compactMap { doc in
                let lexical = jaccard(doc.tokenSet, candidate.tokenSet)
                let semantic = semanticScore(documentVector: doc.vector, candidateVector: candidate.vector)
                let modeBonus = term.emphasizes(mode: doc.examenMode) ? 0.12 : 0
                let experienceBonus = (lens == .why && doc.experienceType == .discernment) ? 0.06 : 0
                let combined = min(max((semantic * 0.62) + (lexical * 0.38) + modeBonus + experienceBonus, 0), 1)
                guard combined >= baseThreshold else { return nil }
                return (doc, combined)
            }

            guard !matches.isEmpty else { continue }

            let sortedMatches = matches.sorted { $0.1 > $1.1 }
            let matchedDocs = sortedMatches.map(\.0)
            let sharedTokens = commonTokens(for: matchedDocs)
            let averageConfidence = sortedMatches.map(\.1).reduce(0, +) / Double(sortedMatches.count)
            let breadth = min(1.0, Double(Set(matchedDocs.map(\.entryID)).count) / 3.0)
            let score = min(max((averageConfidence * 0.7) + (breadth * 0.3), 0), 1)

            let entrySuggestions = sortedMatches.map { doc, confidence in
                InsightEntrySuggestion(
                    entryID: doc.entryID,
                    evidenceSnippet: evidenceSnippet(from: doc.text, preferredTokens: Array(sharedTokens.prefix(3))),
                    confidence: confidence
                )
            }

            suggestions.append(
                InsightSuggestion(
                    id: UUID(),
                    lens: lens,
                    kind: kind,
                    title: term.title,
                    normalizedTitle: InsightNode.normalize(term.title),
                    source: .deterministic,
                    scope: nil,
                    experienceType: nil,
                    score: score,
                    confidence: averageConfidence,
                    keywordHighlights: Array(sharedTokens.prefix(3)),
                    entries: entrySuggestions,
                    sourceThemeClusterID: nil,
                    taxonomyIdentifier: term.id,
                    persistedNodeID: nil,
                    isAccepted: false
                )
            )
        }

        return suggestions
            .sorted {
                if $0.score == $1.score {
                    return $0.confidence > $1.confidence
                }
                return $0.score > $1.score
            }
            .prefix(maxSuggestions)
            .map { $0 }
    }

    private func normalizedExperienceAnchor(from input: InsightAnalysisInput) -> String? {
        let preferred = [
            input.secondaryDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
            input.focusDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty })

        guard let preferred else { return nil }
        return InsightNode.normalize(preferred)
    }

    private struct Document {
        let entryID: UUID
        let date: Date
        let experienceType: ExperienceType?
        let examenMode: ExamenMode
        let text: String
        let tokenSet: Set<String>
        let vector: [Double]?
    }

    private struct TaxonomyCandidate {
        let identifier: String
        let title: String
        let tokenSet: Set<String>
        let vector: [Double]?
    }

    private struct AIRankingEnvelope: Decodable {
        let rankings: [AIRankingItem]
    }

    private struct AIRankingItem: Decodable {
        let id: String
        let confidence: Double
        let keep: Bool
    }

    private func buildDocument(input: InsightAnalysisInput, embedding: NLEmbedding?) -> Document? {
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let tokens = extractTokens(from: text)
        guard !tokens.isEmpty else { return nil }
        return Document(
            entryID: input.entryID,
            date: input.date,
            experienceType: input.experienceType,
            examenMode: input.examenMode,
            text: text,
            tokenSet: Set(tokens),
            vector: embedding?.vector(for: text)
        )
    }

    private func makeTaxonomyCandidate(
        from input: (id: String, title: String, description: String),
        embedding: NLEmbedding?
    ) -> TaxonomyCandidate {
        let composite = "\(input.title). \(input.description)"
        return TaxonomyCandidate(
            identifier: input.id,
            title: input.title,
            tokenSet: Set(extractTokens(from: composite)),
            vector: embedding?.vector(for: composite)
        )
    }

    private func connectedComponents(for docs: [Document]) -> [[Int]] {
        guard docs.count >= 2 else { return [] }
        var adjacency = Array(repeating: [Int](), count: docs.count)

        for i in docs.indices {
            for j in docs.indices where j > i {
                let similarity = similarityBetween(docs[i], docs[j])
                if similarity >= similarityThreshold {
                    adjacency[i].append(j)
                    adjacency[j].append(i)
                }
            }
        }

        var visited = Set<Int>()
        var result: [[Int]] = []

        for start in docs.indices where !visited.contains(start) {
            var stack = [start]
            var component: [Int] = []
            visited.insert(start)

            while let node = stack.popLast() {
                component.append(node)
                for neighbor in adjacency[node] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    stack.append(neighbor)
                }
            }

            if component.count >= minThemeClusterSize {
                result.append(component)
            }
        }

        return result
    }

    private func similarityBetween(_ lhs: Document, _ rhs: Document) -> Double {
        if let left = lhs.vector, let right = rhs.vector {
            return cosine(left, right)
        }
        return jaccard(lhs.tokenSet, rhs.tokenSet)
    }

    private func commonTokens(for docs: [Document]) -> [String] {
        guard !docs.isEmpty else { return [] }
        let minimumFrequency = max(1, Int(ceil(Double(docs.count) * 0.4)))
        var counts: [String: Int] = [:]

        for doc in docs {
            for token in doc.tokenSet {
                counts[token, default: 0] += 1
            }
        }

        return counts
            .filter { $0.value >= minimumFrequency }
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .map(\.key)
    }

    private func bestTaxonomyMatch(
        for docs: [Document],
        centroid: [Double]?,
        sharedTokens: Set<String>,
        taxonomy: [TaxonomyCandidate]
    ) -> (identifier: String?, title: String, score: Double) {
        var winner = (identifier: Optional<String>.none, title: "", score: 0.0)

        for candidate in taxonomy {
            let lexical = jaccard(sharedTokens, candidate.tokenSet)
            let semantic = semanticScore(documentVector: centroid, candidateVector: candidate.vector)
            let combined = (semantic * 0.65) + (lexical * 0.35)
            if combined > winner.score {
                winner = (candidate.identifier, candidate.title, combined)
            }
        }

        return winner
    }

    private func emergentLabel(from tokens: [String], fallbackText: String) -> String {
        if tokens.count >= 2 {
            return "\(tokens[0].capitalized) & \(tokens[1].capitalized)"
        }
        if let first = tokens.first {
            return first.capitalized
        }

        let words = fallbackText
            .split(separator: " ")
            .prefix(2)
            .map(String.init)

        if words.isEmpty {
            return "Emergent Theme"
        }

        return words.joined(separator: " ").capitalized
    }

    private func centroidVector(for docs: [Document]) -> [Double]? {
        let vectors = docs.compactMap(\.vector)
        guard let first = vectors.first else { return nil }
        var sum = Array(repeating: 0.0, count: first.count)

        for vector in vectors where vector.count == first.count {
            for index in vector.indices {
                sum[index] += vector[index]
            }
        }

        return sum.map { $0 / Double(vectors.count) }
    }

    private func clusterScore(componentDocs: [Document], scope: ThemeClusterScope, sharedTokens: [String]) -> Double {
        let cohesion = averagePairwiseSimilarity(componentDocs)
        let lexicalStrength = min(1.0, Double(sharedTokens.count) / 5.0)

        let spread: Double
        if scope == .withinExperience {
            spread = 1.0
        } else {
            let uniqueExperienceCount = Set(componentDocs.compactMap(\.experienceType)).count
            spread = min(1.0, Double(uniqueExperienceCount) / Double(max(1, ExperienceType.allCases.count)))
        }

        let latestDate = componentDocs.map(\.date).max() ?? .now
        let daysAgo = max(0, Calendar.current.dateComponents([.day], from: latestDate, to: .now).day ?? 0)
        let recency = max(0, 1 - (Double(daysAgo) / 180.0))

        return min(max((cohesion * 0.4) + (lexicalStrength * 0.25) + (spread * 0.2) + (recency * 0.15), 0), 1)
    }

    private func clusterConfidence(componentDocs: [Document], sharedTokens: [String]) -> Double {
        let cohesion = averagePairwiseSimilarity(componentDocs)
        let lexical = min(1.0, Double(sharedTokens.count) / 4.0)
        return min(max((cohesion * 0.65) + (lexical * 0.35), 0), 1)
    }

    private func entryConfidence(for doc: Document, in componentDocs: [Document], centroid: [Double]?) -> Double {
        if let centroid, let vector = doc.vector {
            return min(max(cosine(vector, centroid), 0), 1)
        }

        let peers = componentDocs.filter { $0.entryID != doc.entryID }
        guard !peers.isEmpty else { return 0.5 }
        let mean = peers.map { similarityBetween(doc, $0) }.reduce(0, +) / Double(peers.count)
        return min(max(mean, 0), 1)
    }

    private func evidenceSnippet(from text: String, preferredTokens: [String]) -> String {
        let tokenSet = Set(preferredTokens.map { $0.lowercased() })
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text

        var fallback = ""
        var winner = ""

        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return true }
            if fallback.isEmpty {
                fallback = String(sentence)
            }
            let lowered = sentence.lowercased()
            if tokenSet.contains(where: { lowered.contains($0) }) {
                winner = String(sentence)
                return false
            }
            return true
        }

        let chosen = winner.isEmpty ? fallback : winner
        return Self.truncatedEvidenceSnippet(from: chosen)
    }

    private func extractTokens(from text: String) -> [String] {
        let lowered = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lowered

        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = lowered

        var tokens: [String] = []
        let range = lowered.startIndex..<lowered.endIndex
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let rawToken = String(lowered[tokenRange]).trimmingCharacters(in: .punctuationCharacters)
            guard rawToken.count >= 3 else { return true }

            let lexicalClass = tagger.tag(
                at: tokenRange.lowerBound,
                unit: .word,
                scheme: .lexicalClass
            ).0

            guard lexicalClass == .noun || lexicalClass == .verb || lexicalClass == .adjective else {
                return true
            }

            let lemma = tagger.tag(
                at: tokenRange.lowerBound,
                unit: .word,
                scheme: .lemma
            ).0?.rawValue ?? rawToken

            guard !Self.stopWords.contains(lemma) else { return true }

            tokens.append(lemma)
            return true
        }

        return tokens
    }

    private func averagePairwiseSimilarity(_ docs: [Document]) -> Double {
        guard docs.count >= 2 else { return 0.5 }
        var total = 0.0
        var pairCount = 0

        for i in docs.indices {
            for j in docs.indices where j > i {
                total += similarityBetween(docs[i], docs[j])
                pairCount += 1
            }
        }

        guard pairCount > 0 else { return 0.5 }
        return total / Double(pairCount)
    }

    private func semanticScore(documentVector: [Double]?, candidateVector: [Double]?) -> Double {
        guard let documentVector, let candidateVector else { return 0 }
        return cosine(documentVector, candidateVector)
    }

    private func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0

        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsNorm += lhs[index] * lhs[index]
            rhsNorm += rhs[index] * rhs[index]
        }

        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    private func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(union.count)
    }

    private func extractJSONObject(from response: String) -> String? {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}")
        else {
            return nil
        }
        return String(response[start...end])
    }

    private func escapeJSONString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func backfillKey(kind: InsightNodeKind, normalizedTitle: String, experienceType: ExperienceType?) -> String {
        "\(kind.rawValue)|\(experienceType?.rawValue ?? "all")|\(normalizedTitle)"
    }

    static func truncatedEvidenceSnippet(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 180 else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: 180)
        return "\(trimmed[..<endIndex])…"
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "against", "almost", "also", "always", "among", "because",
        "before", "being", "between", "both", "could", "during", "every", "from", "have",
        "having", "into", "just", "like", "made", "more", "much", "must", "need", "only",
        "other", "over", "really", "same", "should", "some", "such", "than", "that", "their",
        "them", "then", "there", "these", "they", "this", "those", "through", "today", "very",
        "what", "when", "where", "which", "while", "with", "would", "your", "ours", "ourselves",
        "myself", "itself", "herself", "himself", "themselves", "patient", "patients"
    ]
}

private extension Optional where Wrapped == String {
    var nonEmptyValue: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
