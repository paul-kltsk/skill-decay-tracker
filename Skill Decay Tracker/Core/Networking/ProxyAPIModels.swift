import Foundation

// MARK: - Structured Proxy Request Bodies
//
// Kept in a separate file from ProxyAPIClient (an actor) so that the Swift 6
// compiler does not mistakenly infer @MainActor isolation on the synthesised
// Encodable/Decodable conformances — a known strict-concurrency inference issue
// when value types share a file with actor declarations.

/// Request body for POST /api/generate — server builds prompt + handles cache.
struct ProxyGenerateRequest: Encodable, Sendable {
    let provider:        String
    let model:           String
    let skillName:       String
    let category:        String
    let difficulty:      Int
    let healthScore:     Double
    let language:        String
    let count:           Int
    let context:         String?   // user's goal/focus — injected into the AI prompt
    let recentQuestions: [String]?
}

/// Request body for POST /api/evaluate — server builds eval prompt.
struct ProxyEvaluateRequest: Encodable, Sendable {
    let provider:      String
    let model:         String
    let challengeType: String
    let question:      String
    let correctAnswer: String
    let explanation:   String
    let skillContext:  String
    let userAnswer:    String
    let language:      String
}

/// Request body for POST /api/breadth — server builds breadth-analysis prompt.
struct ProxyBreadthRequest: Encodable, Sendable {
    let provider:  String
    let model:     String
    let skillName: String
    let context:   String
    let category:  String
    let language:  String
}

/// Response wrapper for all proxy endpoints — `content` holds the raw AI text.
struct ProxyContentResponse: Decodable, Sendable {
    let content: String
}
