---
name: sdt-challenge-flow
description: Complete map of challenge generation, evaluation, and breadth analysis flows — all code paths, routing logic, error handling, token costs. Use whenever working on AIService, ProxyAPIClient, challenge generation, answer evaluation, or anything AI-related in this project.
license: MIT
metadata:
  author: Pavel Kulitski
  version: "1.0"
---

# Challenge Flow — Complete Reference

## Key Files

| File | Role |
|---|---|
| `Services/AIService.swift` | Orchestrates all AI flows — generation, evaluation, breadth analysis |
| `Core/Networking/ProxyAPIClient.swift` | Proxy path: `generate()`, `evaluate()`, `analyzeBreadth()`, `performSignedRequest()` |
| `Core/Networking/ClaudeAPIClient.swift` | Direct path: rate limiting, retry, keychain |
| `~/Desktop/sdt-proxy/src/prompts.ts` | Server-side prompt builders |
| `~/Desktop/sdt-proxy/src/cache.ts` | 8h TTL cache (server-side) |
| `~/Desktop/sdt-proxy/src/index.ts` | Routes: `/api/generate`, `/api/evaluate`, `/api/breadth` |

## Routing Logic (applies to all three flows)

```
ProviderKeychain.has(for: provider)
    YES → Direct: build prompt locally → ClaudeAPIClient / OpenAIClient / GeminiClient
    NO  → Proxy:  send structured data → ProxyAPIClient → sdtapi.mooo.com → AI provider
```

The proxy path is the **default** for all users without a personal API key.

---

## Flow 1: Challenge Generation

### Entry point
```swift
AIService.generateChallenges(
    skillName:       String,
    category:        String,
    difficulty:      Int,      // 1–5
    skillContext:    String,
    healthScore:     Double = 0.5,   // 0–1, affects prompt tone
    recentQuestions: [String] = [],  // bypasses cache when non-empty
    count:           Int = 3
)
```

### Proxy path detail
1. Detects language via `NLLanguageRecognizer` on `skillName + skillContext`
2. Calls `ProxyAPIClient.generate(...)` → `POST /api/generate`
3. Server checks **cache** (key: SHA256 of `skillName+difficulty+language+count`, TTL 8h)
   - Cache **HIT** → returns cached JSON, `tokens: {input:0, output:0}`, 0 cost
   - Cache **MISS** → `prompts.ts` builds prompt with:
     - System prompt: "JSON-only API" instruction
     - `healthScore` → retention hint (thriving / fading / forgotten)
     - Type distribution: 2 multiple_choice + 1 open_ended (for count=3)
     - `recentQuestions` → avoid list (max 10 items)
     - Language label from BCP-47
   - Calls AI provider, stores result in cache
4. Response `content` is raw JSON string → `parseChallengeDTOs()` → `mapToChallenge()`

### Cache bypass
Set `recentQuestions` to non-empty array → cache is skipped entirely, fresh generation forced.

### Token budget
```swift
generationTokenBudget(count) = Int(Double(200 + 300 * count) * 1.3)
// 3 questions → 2,210 tokens
// 5 questions → 3,250 tokens
```

---

## Flow 2: Answer Evaluation

### Entry point
```swift
AIService.evaluateAnswer(
    context:      ChallengeEvalContext,  // Sendable snapshot — extract on @MainActor
    userAnswer:   String,
    responseTime: TimeInterval = 0
)
```

### Fast path (NO API call)
Types `.multipleChoice` and `.trueFalse` → evaluated **locally**:
- `caseInsensitiveCompare(userAnswer, correctAnswer)`
- `ConfidenceRating` inferred from `responseTime / timeLimitSeconds`
  - < 33% of limit → `.high`
  - < 66% of limit → `.medium`
  - ≥ 66% of limit → `.low`

### AI path (open_ended, fill_in_blank)
- Direct: `evaluationPrompt()` locally → `sendPrompt(maxTokens: 256)`
- Proxy: `ProxyAPIClient.evaluate(...)` → `POST /api/evaluate`
  - Server builds prompt with system prompt + language detection
  - Returns `{ is_correct, feedback, confidence_hint }`
  - `confidence_hint`: "low" | "medium" | "high" (or falls back to time-based)

### After evaluation
`EvaluationResult` → `DecayEngine`:
- Correct → `decayRate -= 0.01` (+ speed bonus), `nextReviewDate` pushed out
- Incorrect → `decayRate += 0.02`, `nextReviewDate = tomorrow`, `streakDays = 0`

---

## Flow 3: Skill Breadth Analysis

### Entry point
```swift
AIService.analyzeSkillBreadth(name: String, context: String, category: SkillCategory)
```

### Routing
- Direct: `breadthPrompt()` → `sendPrompt(maxTokens: 256)`
- Proxy: `ProxyAPIClient.analyzeBreadth(...)` → `POST /api/breadth`

### Logic
- Topic specific enough → `{ subSkills: [] }` → create skill directly
- Topic too broad → `{ subSkills: [{name, category}, ...] }` (up to 4)
  - Triggers `SkillSuggestionsView` in AddSkill flow
  - User selects which sub-skills to create

### "Too broad" examples
Entire languages (Swift, Python, Spanish), vast domains (iOS Development, Machine Learning)

### "Specific enough" examples
"Swift ARC", "React Hooks", "Git Rebase", anything with context provided

---

## Error Handling

| Error | Trigger | UI behavior |
|---|---|---|
| `networkUnavailable` | No internet, 502/503/504 | Load from SwiftData cache, then template questions |
| `missingAPIKey` | 401, no keychain entry | Navigate to Settings API key field |
| `rateLimited(retryAfter:)` | 429 from server or provider | Banner: "Daily limit reached, resets in Nh" |
| `invalidJSON(raw:)` | Malformed AI response | Silent + template fallback + analytics log |
| `emptyResponse` | Empty content block | Silent + template fallback |

### Fallback chain (generation)
1. SwiftData cached challenges for this skill (pre-generated)
2. Template-based questions (offline mode, no AI)
3. Show error UI only if both fail

---

## Token Costs (Haiku ~$0.88/1M mixed)

| Operation | Input | Output | Cost | Notes |
|---|---|---|---|---|
| Generate 3 (cache miss) | ~530 | ~900 | ~$0.0013 | Server adds system prompt |
| Generate 3 (cache hit) | 0 | 0 | **$0** | 8h TTL |
| Evaluate MC/TF | 0 | 0 | **$0** | Local comparison |
| Evaluate open_ended | ~200 | ~80 | ~$0.0005 | |
| Breadth analysis | ~300 | ~100 | ~$0.0006 | |

At 70% cache hit rate → average generation cost ≈ $0.0004/request.

---

## ChallengeEvalContext Pattern

`Challenge` is a `@Model` object — NEVER cross actor boundaries with it.
Always extract on `@MainActor` before calling into `AIService`:

```swift
// ON @MainActor:
let ctx = ChallengeEvalContext(from: challenge)

// Cross actor boundary — only Sendable values:
let result = try await AIService.shared.evaluateAnswer(context: ctx, userAnswer: answer)
```

---

## AI Providers

Three providers supported, selected in Settings:

| Provider | Generation model | Evaluation model |
|---|---|---|
| Claude (default) | `claude-haiku-4-5-20251001` | `claude-haiku-4-5-20251001` |
| OpenAI | `provider.generationModelID` | `provider.evalModelID` |
| Gemini | `provider.generationModelID` | `provider.evalModelID` |

Proxy supports all three. System prompt injected for Claude + OpenAI; prepended for Gemini (no native system role).
