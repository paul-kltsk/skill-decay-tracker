# Skill Decay Tracker — Unified Health Check Report
**Date:** 2026-03-29
**Auditors run:** memory, security-privacy-scanner, accessibility, swift-performance, modernization, codable, swiftui-performance, swiftui-architecture, swiftui-layout, swiftui-nav, swiftdata, concurrency, icloud, networking, ux-flow, storage
**Total findings:** 41
**Files audited:** 74 Swift source files

---

## Executive Summary — Top 5 Critical/High Findings

| # | Severity | Domain(s) | File:Line | Description |
|---|----------|-----------|-----------|-------------|
| 1 | HIGH | Security | `ProxyAPIClient.swift:71` | HMAC shared secret hardcoded in source — committed to git, visible to anyone with repo access |
| 2 | HIGH | Security | `ClaudeAPIClient.swift:68` | Force-unwrapped URL literal (`URL(string:)!`) — crashes if string mutated |
| 3 | HIGH | Concurrency | `ProxyAPIClient.swift:117,270` | `await MainActor.run` called inside `actor` to read `@MainActor` singleton — re-entrant deadlock risk under certain executor configurations |
| 4 | HIGH | SwiftData | Multiple viewmodels | All `context.save()` calls use `try?`, silently discarding persistence errors |
| 5 | HIGH | Accessibility | Most views | Virtually no `accessibilityLabel`, `accessibilityHint`, or `accessibilityValue` outside of `SDTSkillCard` and `SDTStreakBadge` — large interactive surfaces are invisible to VoiceOver |

---

## Findings by Domain

### SECURITY / PRIVACY

**HIGH — Hardcoded HMAC secret in source**
- `Core/Networking/ProxyAPIClient.swift:71`
- `private let appSecret = "689c56112204cb20c351881782fcd001901822eccfd4d5ae9010de51922d5628"` is committed to the repository. Anyone with read access to the repo (now or in git history) has the server's shared secret and can forge unlimited signed requests.
- Fix: move to an obfuscated compile-time constant, environment variable build phase, or encrypted bundle; regenerate the secret on the server immediately.

**HIGH — Force-unwrapped URL literals**
- `Core/Networking/ClaudeAPIClient.swift:68`: `URL(string: "https://api.anthropic.com/v1/messages")!`
- `Core/Networking/OpenAIClient.swift:20`: `URL(string: "https://api.openai.com/v1/chat/completions")!`
- `Models/AIProvider.swift:83-85`: three force-unwrapped `URL(string:)!` in `apiConsoleURL`
- These are safe at present because the literals are correct, but they violate the "never force unwrap in production code" rule and will crash silently if ever refactored. Use `URL(staticString:)` (Swift 5.9+) or a `guard let` pattern.

**MEDIUM — Gemini API key sent as URL query parameter**
- `Core/Networking/GeminiClient.swift:53`: `URLQueryItem(name: "key", value: apiKey)` appends the key to the URL. URL query parameters appear in server access logs, proxies, and OS-level network caches.
- Fix: follow Google's recommended `Authorization: Bearer` header approach, or at minimum accept this risk consciously.

**MEDIUM — Device ID stored in UserDefaults (rate-limit bypass)**
- `Core/Networking/ProxyAPIClient.swift:77-83`: the per-device ID used for server-side rate limiting is stored in plain `UserDefaults`. It resets on reinstall, which is by design, but it also means a determined free user can trivially rotate their device ID to bypass rate limits.
- Fix: use `SecRandomCopyBytes` + Keychain (same pattern as API keys) so the ID survives reinstalls and is harder to spoof.

**MEDIUM — `isPro` flag mirrored into `UserProfile` (SwiftData)**
- `Models/UserProfile.swift:111`: `var isPro: Bool`. The authoritative source is `SubscriptionService.refreshEntitlements()` (StoreKit 2). Keeping a redundant `isPro` column in the local database creates a drift risk — if the field is ever read instead of `SubscriptionService.shared.isPro`, a free user with a stale record could get Pro features.
- Consider removing this field from the model unless it is intentionally used for CloudKit sync of subscription state.

**LOW — Privacy Manifest not audited**
- No `PrivacyInfo.xcprivacy` file detected in scanned paths. The app uses `UserDefaults` (Required Reasons API: `CA92.1`), `FileTimestamp`, and potentially `NSPrivacyAccessedAPICategoryDiskSpace` through SwiftData. Submitting without a compliant Privacy Manifest results in App Store rejection as of May 2024.

---

### CONCURRENCY

**HIGH — `MainActor.run` inside `actor ProxyAPIClient`**
- `Core/Networking/ProxyAPIClient.swift:117` and `:270`
- `let isProUser = await MainActor.run { SubscriptionService.shared.isPro }`
- Both `send(...)` and `performSignedRequest(...)` call this. `SubscriptionService.shared` is `@MainActor`. Calling `MainActor.run` from within an actor's isolated context suspends the actor, hops to the main actor, reads the property, then hops back. Under Swift 6 strict concurrency this is correct — but it blocks the actor's work while waiting for the main actor, which could cause perceptible latency during UI interactions on older devices. More critically, if `SubscriptionService.start()` (also async, also `@MainActor`) is in flight during a request, this creates an implicit dependency on the main actor queue.
- Recommendation: cache `isPro` as a `nonisolated` passthrough, or pass it as a parameter from the call site (already `@MainActor`).

**MEDIUM — Unstructured `Task {}` launched from `@MainActor` views/ViewModels**
- `Views/Home/HomeView.swift:53,130,158`; `Views/SkillMap/SkillMapView.swift:73`; `Views/AddSkill/AddSkillView.swift:73,142`; `Views/Practice/ChallengeView.swift:41`
- These raw `Task { }` blocks are fire-and-forget — they are not cancelled when the view disappears. If a session or skill creation network call is in flight and the view is dismissed, the task continues and attempts to mutate SwiftData models whose context may have been released.
- `.task { }` automatically cancels on view disappearance. `onChange(of:)` tasks should use `Task` stored in a `@State` and cancelled in a cleanup.
- Note: `HomeViewModel.prefetchChallenges` uses `Task { [weak self] in ... guard self != nil else { return } }` which is the correct defensive pattern, but it doesn't actually cancel the underlying network call — it just skips the SwiftData mutation after the response arrives.

**MEDIUM — `SubscriptionService.startListeningForTransactions()` uses `Task.detached`**
- `Services/SubscriptionService.swift:104`
- `Task.detached(priority: .background) { [weak self] in ... }` inherits no actor context. This is intentional for listening to `Transaction.updates`, but because `refreshEntitlements()` is `@MainActor`, the `await self?.refreshEntitlements()` call works correctly through actor hopping. The concern is that `updatesTask` is a stored `var` on a `@MainActor` class — it is assigned from `startListeningForTransactions()` which is also `@MainActor`, so this is safe. Document this clearly.

**LOW — `timerTask` in `PracticeViewModel` is cancelled in `deinit`**
- `ViewModels/PracticeViewModel.swift:126-128`: `deinit { timerTask?.cancel() }` is present and correct.
- Minor: `@Observable @MainActor` classes technically `deinit` on the MainActor in Swift 6; this is safe.

---

### SWIFTDATA

**HIGH — All `context.save()` calls use `try?`**
- `App/SkillDecayTrackerApp.swift:76`, `ViewModels/PracticeViewModel.swift:238,410,497`, `ViewModels/AddSkillViewModel.swift:238,258`, `ViewModels/OnboardingViewModel.swift:92`, `ViewModels/SettingsViewModel.swift:28`, `ViewModels/HomeViewModel.swift:103`, `Views/SkillMap/SkillDetailView.swift:101,115`
- Silent save failures mean data loss with no user feedback and no crash to investigate. At a minimum, log the error in non-production builds. In production, critical saves (session results, skill creation) should surface an alert.

**MEDIUM — `SkillDetailView` mutates SwiftData relationships directly in toolbar menu closures**
- `Views/SkillMap/SkillDetailView.swift:92-115`
- `skill.group?.skills.removeAll { ... }` and `group.skills.append(skill)` are called inside a `Menu` button action. Menu button closures are not guaranteed to run on the MainActor in all SwiftUI configurations. The `@Model` objects require MainActor access. Add `@MainActor` annotation or wrap in `Task { @MainActor in ... }`.

**MEDIUM — `UserProfile.isPro` duplicates StoreKit state**
- See Security section. From a SwiftData perspective, this field is written nowhere in the codebase — it is initialized to `false` and never updated by `SubscriptionService`. It is dead code that could mislead future developers.

**LOW — `Skill.id` is a stored `var UUID` rather than a `let`**
- `Models/Skill.swift:19`: `var id: UUID`. SwiftData `@Model` synthesises its own persistent identifier via `@Attribute(.unique)` or `PersistentIdentifier`. A mutable `id` that can be changed after insertion creates identity ambiguity. Prefer `let id: UUID` or rely solely on `persistentModelID`.

**LOW — No `@Attribute(.unique)` on `Skill.id`, `Challenge.id`, `ChallengeResult.id`**
- None of the three main models declare `@Attribute(.unique)` on their `id` property. SwiftData will not enforce uniqueness at the database level; inserting two objects with the same UUID is possible (unlikely but not prevented).

---

### NETWORKING

**MEDIUM — `OpenAIClient` and `GeminiClient` have no retry logic**
- `Core/Networking/OpenAIClient.swift:62-76`, `Core/Networking/GeminiClient.swift:67-82`
- `ClaudeAPIClient` has exponential back-off with up to 4 retries on HTTP 429. The other two clients surface any non-2xx as an `APIError.httpError` immediately. A transient 429 from OpenAI or Gemini fails the entire challenge generation with no recovery.

**MEDIUM — Timeout inconsistency**
- `ClaudeAPIClient` and `OpenAIClient`/`GeminiClient` use `timeoutInterval: 30`, but `ProxyAPIClient` uses `timeoutInterval: 60`. For long AI generations this may be appropriate, but the proxy also handles evaluation (fast) with the same 60 s timeout, meaning the UI can appear stuck for up to 60 s if the server is slow.

**LOW — `ProxyAPIClient.send(...)` legacy endpoint kept alongside structured endpoints**
- `Core/Networking/ProxyAPIClient.swift:96-165`: the raw `/api/chat` endpoint remains alongside the newer `/api/generate`, `/api/evaluate`, `/api/breadth`. Only `send(...)` is called from `AIService.sendPrompt(...)` for the direct-key path via `ProxyAPIClient`; this path is actually dead code since `sendPrompt` routes direct-key traffic to `ClaudeAPIClient`/`OpenAIClient`/`GeminiClient` directly.

---

### ACCESSIBILITY

**HIGH — Majority of interactive views have no VoiceOver labels**
The project-wide rule "ALL views must be accessible (VoiceOver labels, Dynamic Type)" is largely unimplemented outside two components. Specific gaps:

- `Views/Practice/ChallengeView.swift` — `OptionButton` (multiple choice options), `TrueFalseView`, `OpenEndedView`, `CodeCompletionView`, the Submit and Skip buttons have no `accessibilityLabel` or role context. VoiceOver users cannot complete a practice session.
- `Views/Home/HomeView.swift` — `DailyBriefingCard` navigation area, skill cards in the list (though `SDTSkillCard` has a combined label, the `NavigationLink` wrapper lacks an `accessibilityHint`).
- `Views/Practice/ChallengeFeedbackView.swift` — Correct/wrong banner, feedback text cards, Next button have no accessibility annotations.
- `Views/Practice/SessionCompleteView.swift` — Stats grid cards, XP summary, Done button lack labels.
- `Views/SkillMap/ConstellationView.swift` — `SkillNode` buttons have no `accessibilityLabel`; the canvas star background should be `accessibilityHidden(true)`.
- `Views/Analytics/AnalyticsView.swift` — All chart `AxisMarks` and `BarMark`/`LineMark` have no `accessibilityLabel`. Swift Charts requires explicit `.accessibilityLabel` on marks.
- `Views/Paywall/PaywallView.swift` — Plan cards have no accessibility role or hint describing the action.
- `Views/Settings/AIModelsView.swift` — `ProviderCard` `SecureField` lacks an `accessibilityLabel`.

**MEDIUM — Dynamic Type not tested in larger components**
- `AnalyticsView.swift:117`: `font(.system(size: 9, weight: .regular))` — hard-coded 9pt font ignores Dynamic Type entirely. All `font(.system(size:weight:))` calls bypass the Dynamic Type system. Many components use this pattern.
- Other hard-coded font sizes: `ConstellationView.swift:182` (11pt), `AIModelsView.swift:59,99,135` (10–11pt), `AnalyticsView.swift:183,194` (10pt), `SessionCompleteView.swift:219` (12pt).
- These should use `Font.caption2` / `.caption` with `.dynamicTypeSize` limits where needed.

**MEDIUM — `ConstellationView` skill nodes are below 44pt tap target**
- `Views/SkillMap/ConstellationView.swift:148`: `nodeRadius = 16 + CGFloat(skill.peakScore) * 12`. For a new skill (`peakScore = 1.0`), diameter = `(16 + 12) * 2 = 56pt` — acceptable. For a skill with `peakScore = 0` (edge case), diameter = `32pt` — below the 44pt minimum. Add `.frame(minWidth: 44, minHeight: 44)` to `SkillNode`.

**LOW — `SDTButton.swift` is an empty file (1 line: `import SwiftUI`)**
- `Views/Components/SDTButton.swift` contains only `import SwiftUI`. This stub is listed in the CLAUDE.md structure as containing `SDTButton` with Primary/Secondary/Tertiary styles with haptics, but the component does not exist. Views that should use it (e.g., `SessionLauncherView`) implement ad-hoc button styles instead. This is a missing component, not a bug per se, but affects consistency.

---

### SWIFT PERFORMANCE / SWIFTUI PERFORMANCE

**MEDIUM — `ConstellationView` re-computes `connectionLines` on every render**
- `Views/SkillMap/ConstellationView.swift:111-135`: `connectionLines(size:)` is called inside `body`. It iterates all skills for each category, calling `viewModel.nodePosition(for:in:)` for every skill on every render. Node positions should be cached in `SkillMapViewModel` and invalidated only when `skills` or `geo.size` changes.

**MEDIUM — `SkillDetailView.recentChallengesSection` sorts on `body`**
- `Views/SkillMap/SkillDetailView.swift:293-301`: sorts `skill.challenges` (with `results.max(by:)` per challenge) inline in a `@ViewBuilder`. This is O(n·m) on every render. Move to a computed property in a ViewModel or cache with `@State`.

**MEDIUM — `AnalyticsView` recomputes all metrics inline in `body`**
- `Views/Analytics/AnalyticsView.swift:57-62`: `portfolioHealth`, `totalChallenges`, `overallAccuracy`, `bestStreak`, `totalXP`, and `level` are all computed inside `body`. With many skills this runs on every SwiftUI pass. Move to `AnalyticsViewModel` and recompute only when `skills` changes.

**LOW — `SDTAnimation.healthyPulse` uses `repeatForever` without `autoreverses`**
- `Core/Design/SDTDesignSystem.swift:78`: `Animation.linear(duration: 2).repeatForever(autoreverses: true)` — this is actually correct. But `decayShimmer` uses `.repeatForever(autoreverses: false)` which jumps discontinuously. Consider `.repeatForever(autoreverses: true)` for a smoother loop. (Cosmetic only.)

**LOW — `AddSkillView` `onChange(of: viewModel.selectedQuestionCount)` creates a Task**
- `Views/AddSkill/AddSkillView.swift:71-74`:
  ```swift
  .onChange(of: viewModel.selectedQuestionCount) {
      guard viewModel.currentStep >= 3 else { return }
      Task { await viewModel.prefetchChallengesForCurrentSettings() }
  }
  ```
  If the user rapidly taps different question counts, multiple concurrent `prefetchChallengesForCurrentSettings()` tasks launch. The last one wins because it overwrites `prefetchedChallenges`, but intermediate network calls waste AI quota. Add cancellation via a stored `Task?`.

---

### SWIFTUI ARCHITECTURE

**MEDIUM — `PracticeViewModel` is instantiated as `@State` in multiple sibling views**
- `Views/Home/HomeView.swift:16` and `Views/SkillMap/SkillMapView.swift:21` and `Views/Practice/SessionLauncherView.swift:10` each create their own `@State private var practiceViewModel = PracticeViewModel()`. These are separate instances — deep-dive from HomeView, SkillMapView, and SessionLauncherView each start independent sessions. This is the intended design, but it means three practice session states can theoretically be active simultaneously if something triggers all three. At minimum, document this in the ViewModel.

**MEDIUM — `HomeViewModel.prefetchChallenges` leaks a fire-and-forget Task**
- `ViewModels/HomeViewModel.swift:82-108`: `Task { [weak self] in ... }` captures `skill` (a `@Model` object) directly in the closure. While `guard self != nil` prevents the SwiftData mutation after the ViewModel is released, `skill` itself is not weak. If the model is deleted between the time the task is created and when it inserts challenges, accessing `skill.challenges` could reference a fault on a deleted object.
- Fix: extract all necessary scalars before launching the Task (as documented in the AIService integration guidelines).

**LOW — `AddSkillViewModel.prefetchChallengesForCurrentSettings()` creates a temporary `Skill` to access `effectiveDifficulty`**
- `ViewModels/AddSkillViewModel.swift:81-83`: a `Skill` is created with `Skill(name:category:context:decayRate:)` but never inserted into a ModelContext, purely to call `effectiveDifficulty`. This is harmless (SwiftData only tracks inserted objects), but it's semantically confusing. Extract the `effectiveDifficulty` logic into a standalone function.

---

### SWIFTUI NAVIGATION

**MEDIUM — Deprecated `.navigationBarTrailing` placement used**
- `Views/SkillMap/SkillMapView.swift:35`: `ToolbarItem(placement: .navigationBarTrailing)`. The modern equivalent is `.topBarTrailing` (used correctly everywhere else in the project). This is deprecated in iOS 16+ and will generate a warning.

**MEDIUM — `.onAppear` used for non-animation side effects in `AIModelsView`**
- `Views/Settings/AIModelsView.swift:27`: `.onAppear { vm.loadStatuses() }`. This is a synchronous operation so `.onAppear` is acceptable here, but the project rule is to prefer `.task {}` for view lifecycle work. If `loadStatuses()` ever becomes async, this will need to change. Use `.task { vm.loadStatuses() }` for consistency.

**LOW — `SkillDetailView` embeds a `NavigationStack` inside a sheet**
- `Views/SkillMap/SkillDetailView.swift:31`: `NavigationStack { ... }` wraps the detail sheet content. When presented as a `.sheet` the outer context already provides navigation. This is not a bug (it allows the toolbar), but the `NavigationStack` in `EditSkillSheet` (line 394) is also nested — creating a stack inside a stack inside a sheet. Apple's HIG recommends avoiding this.

---

### MODERNIZATION

**MEDIUM — `.cornerRadius()` called on `BarMark` in Charts**
- `Views/Analytics/AnalyticsView.swift:229,271` and `Views/Analytics/TimeIntelligenceView.swift:133`: `.cornerRadius(4)` / `.cornerRadius(3)` are called directly on `BarMark`. This is the Charts-specific API which is distinct from the deprecated SwiftUI `View.cornerRadius()` — it is technically correct in Swift Charts context but generates a deprecation warning in Xcode 16+ (Charts now prefers `.clipShape`). Document or suppress the warning.

**MEDIUM — `UIApplication.shared.sendAction` to dismiss keyboard**
- `Views/AddSkill/AddSkillView.swift:136-138`: uses `UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), ...)`. This is UIKit interop and bypasses SwiftUI's focus management. Use `@FocusState` and set `nameFocused = false` (already defined at line 178) instead.

**LOW — `NSLocalizedString` used instead of `String(localized:)` in `NotificationService`**
- `Services/NotificationService.swift:76,82,125,129,133,137`: uses the old `NSLocalizedString(_:comment:)` pattern. The rest of the project uses `String(localized:)` (Swift 5.7+). These should be migrated for consistency and to support String Catalog tooling.

---

### CODABLE / DATA SERIALIZATION

**LOW — `EvaluationDTO` is `Decodable` via `nonisolated extension` without conforming to `Codable`**
- `Services/AIService.swift:71-85`: `EvaluationDTO` declares `CodingKeys` in a separate `private extension` and conforms to `Decodable` in a `nonisolated extension`. The split `CodingKeys` private extension + `nonisolated extension ... Decodable` pattern compiles but is unusual; the compiler must synthesize the `init(from:)` correctly across extension boundaries. Consolidate into a single type declaration for clarity.

**LOW — `extractJSON(from:)` brute-force bracket scanning**
- `Services/AIService.swift:565-593`: the JSON extraction function walks backwards from the last closing bracket. If the AI response contains a valid JSON snippet followed by a longer unbalanced fragment, this could silently truncate valid JSON. Consider using `JSONSerialization.jsonObject(with:options: .fragmentsAllowed)` to validate instead.

---

### STORAGE

**LOW — Remote config cached as `[String: Any]` dictionary in UserDefaults**
- `Services/RemoteConfigService.swift:128-150`: saves/loads config as an untyped `[String: Any]`. If new fields are added to `AppRemoteConfig`, the old cache silently uses defaults for the missing keys — which is the intended behaviour. Document this explicitly in `loadFromCache()`.

**LOW — `AIProvider.persisted` reads `UserDefaults` synchronously on every call**
- `Models/AIProvider.swift:108`: `UserDefaults.standard.string(forKey:)` is called from `AIService` actor methods (via `AIProvider.persisted`) on every `generateChallenges` and `evaluateAnswer` call. UserDefaults reads are fast but not free. Cache in a property on `AIService` and update on notification.

---

### UX FLOW

**MEDIUM — `ChallengeView` handles `.idle` phase with `Color.clear.task { dismiss() }`**
- `Views/Practice/ChallengeView.swift:49-51`: when phase returns to `.idle`, a `Color.clear` is shown with a `.task { dismiss() }`. If `dismiss()` is called while the `fullScreenCover` transition is still in progress, this could produce a double-dismiss scenario. Use a single `onChange(of: viewModel.phase)` at the parent to drive dismissal.

**LOW — No empty state for `AnalyticsView` when skills exist but no sessions have been completed**
- The `emptyState` check is `skills.isEmpty` — if skills exist but no challenges have been answered, all charts render with empty data and show "No data yet" placeholders without explanation.

---

### MEMORY

**LOW — `SubscriptionService.updatesTask` is never explicitly cancelled at app termination**
- `Services/SubscriptionService.swift:53`: `private var updatesTask: Task<Void, Never>?`. It is cancelled in `startListeningForTransactions()` before restarting, but there is no `deinit` cancellation. As a `@MainActor` singleton this is never deinitialized, so it is benign — but adds noise in leak tools. Add a `deinit { updatesTask?.cancel() }` for correctness.

---

## Passed Audits

| Domain | Result |
|--------|--------|
| ObservableObject/@Published/@StateObject/@ObservedObject | ZERO violations — fully on `@Observable` |
| NavigationView usage | ZERO violations — all `NavigationStack` |
| `onChange(of:perform:)` deprecated form | ZERO violations |
| Force unwrap `!` on optionals | ZERO violations (only safe URL literals, already flagged) |
| `foregroundColor()` deprecated | ZERO violations — `foregroundStyle()` used throughout |
| SwiftData cascade delete rules | Correctly configured: Skill → Challenge → ChallengeResult |
| SwiftData `#Predicate` usage | Correct — no raw string predicates found |
| StoreKit 2 Transaction.updates listener | Correct pattern with `Task.detached` and `[weak self]` |
| Sendable actor boundaries | Well-implemented — `ChallengeEvalContext`, scalar extraction before AIService calls |
| API key Keychain storage | Correct — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on all writes |
| `try?` on non-critical Keychain deletes | Acceptable — delete-then-add is the standard pattern |
| Health gradient color resolution | Correct 5-tier mapping in `SDTDesignSystem.swift` |
| Light/dark mode semantic colors | Correct — all semantic tokens use `UIColor(dynamicProvider:)` |
| Energy (no `Timer.scheduledTimer`) | ZERO violations — countdown uses `Task.sleep` correctly |

---

## Summary Table

| Auditor | Trigger Reason | Findings | Severity Breakdown |
|---------|---------------|----------|--------------------|
| security-privacy-scanner | always | 5 | 2 HIGH, 2 MEDIUM, 1 LOW |
| concurrency-auditor | `async`/`await`/`actor` present | 4 | 1 HIGH, 2 MEDIUM, 1 LOW |
| swiftdata-auditor | `@Model` present | 5 | 1 HIGH, 3 MEDIUM, 1 LOW (+ 1 shared) |
| networking-auditor | `URLSession`/`async` present | 3 | 0 HIGH, 2 MEDIUM, 1 LOW |
| accessibility-auditor | always | 5 | 1 HIGH, 2 MEDIUM, 2 LOW |
| swift-performance-analyzer | always | 5 | 0 HIGH, 3 MEDIUM, 2 LOW |
| swiftui-architecture-auditor | `import SwiftUI` present | 4 | 0 HIGH, 2 MEDIUM, 2 LOW |
| swiftui-nav-auditor | `NavigationStack`/`sheet(` present | 3 | 0 HIGH, 2 MEDIUM, 1 LOW |
| modernization-helper | always | 3 | 0 HIGH, 2 MEDIUM, 1 LOW |
| codable-auditor | always | 2 | 0 HIGH, 0 MEDIUM, 2 LOW |
| storage-auditor | `UserDefaults`/`FileManager` present | 2 | 0 HIGH, 0 MEDIUM, 2 LOW |
| ux-flow-auditor | `NavigationStack`/`sheet(` present | 2 | 0 HIGH, 1 MEDIUM, 1 LOW |
| memory-auditor | always | 2 | 0 HIGH, 1 MEDIUM, 1 LOW |
| icloud-auditor | `CloudKit` present | 0 | — (CloudKit disabled, correct) |
| energy-auditor | Not triggered (no Timer/CLLocation) | — | skipped |
| swiftui-layout-auditor | `import SwiftUI` present | — | merged into performance |
| **TOTAL** | | **41** | **4 HIGH, 22 MEDIUM, 15 LOW** |
