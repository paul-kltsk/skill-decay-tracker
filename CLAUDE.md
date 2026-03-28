# Skill Decay Tracker

## Project Overview
iOS app that visualizes your knowledge portfolio as a living ecosystem. Each skill has a measurable "health" indicator that decays over time following a modified Ebbinghaus forgetting curve. AI generates personalized micro-challenges (2–3 min) using Claude API, adapting difficulty based on user responses. Spaced repetition intervals are calculated per-skill.

**Bundle ID:** `pavel.kulitski.Skill-Decay-Tracker`
**Minimum iOS:** 18.0
**Platform:** iPhone only (Phase 1)

## Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Swift 6 | Strict concurrency, full Sendable enforcement |
| UI | SwiftUI (iOS 18+) | @Observable macro, NO Combine for new code |
| Local Persistence | SwiftData | @Model classes with automatic CloudKit sync |
| Cloud Sync | CloudKit (via SwiftData) | Private database only. Team not connected yet — works locally, sync activates later |
| AI Provider | Claude API (Anthropic) | claude-sonnet-4-20250514 for generation, claude-haiku-4-5-20251001 for evaluation |
| Networking | URLSession + async/await | No third-party HTTP libraries |
| Payments | StoreKit 2 | Auto-renewable subscriptions |
| Widgets | WidgetKit | Small, Medium, Large, Lock Screen |
| Live Activities | ActivityKit | Dynamic Island during sessions — **planned, not yet implemented** |
| Charts | Swift Charts | Decay curves, progress visualization |
| Animations | SwiftUI + PhaseAnimator | Organic "growth and decay" metaphors |
| Testing | Swift Testing + XCUITest | #expect macro, @Test attribute |
| Architecture | MVVM + Repository Pattern | @Observable ViewModels, protocol-based repos |
| Analytics | Firebase Analytics + Crashlytics | Event tracking + crash reporting (via SPM firebase-ios-sdk) |
| CI/CD | Xcode Cloud | Auto TestFlight & App Store submission |

## Project Structure

```
Skill Decay Tracker/                   ← Xcode source folder (folder-based project, no .pbxproj file refs)
├── App/
│   └── SkillDecayTrackerApp.swift     — @main, ModelContainer, RootTabView, first-launch seed
├── Core/
│   ├── Design/
│   │   ├── SDTDesignSystem.swift      — SkillCategory enum, Color(hex:), sdtHealth(for:)
│   │   ├── SDTColors.swift            — Semantic + Health gradient + Category accent tokens
│   │   ├── SDTTypography.swift        — SF Pro Rounded headers, SF Mono for code
│   │   └── SDTSpacing.swift           — xxs(2) through xxxl(48) spacing scale + CornerRadius + minTapTarget
│   ├── Extensions/
│   │   ├── Date+Extensions.swift      — daysSinceNow, relativeString, isToday, calendarDays(from:)
│   │   └── View+Extensions.swift      — sdtFont(), sdtCard(), minTapTarget(), if(), shakeEffect()
│   └── Networking/
│       ├── ClaudeAPIClient.swift      — Direct Claude API (personal key path)
│       ├── OpenAIClient.swift         — Direct OpenAI API (personal key path)
│       ├── GeminiClient.swift         — Direct Gemini API (personal key path)
│       ├── ProxyAPIClient.swift       — Proxy path: generate / evaluate / breadth via sdtapi.mooo.com
│       ├── ProviderKeychain.swift     — Keychain read/write for API keys (all 3 providers)
│       └── APIError.swift             — Shared error types
├── Models/
│   ├── Skill.swift                    — @Model: id, name, category, context, healthScore, decayRate, group, overrideDifficulty
│   ├── SkillGroup.swift               — @Model: id, name, emoji; nullify delete rule → skills become ungrouped
│   ├── Challenge.swift                — @Model: type, question, options, correctAnswer, explanation, isUsed, nextReviewDate
│   ├── ChallengeResult.swift          — @Model: isCorrect, responseTime, confidenceRating; ConfidenceRating enum
│   ├── UserProfile.swift              — @Model: displayName, xp, level, preferences (theme, aiProvider, etc.)
│   └── AIProvider.swift               — Enum: claude / openai / gemini; generationModelID, evalModelID, keyPrefix
├── Services/
│   ├── DecayEngine.swift              — Pure enum namespace: Ebbinghaus formula, spaced-repetition scheduling
│   ├── AIService.swift                — actor: challenge generation + answer evaluation (routes to proxy or direct)
│   ├── AnalyticsService.swift         — Pure enum namespace: Firebase Analytics event wrappers
│   ├── RemoteConfigService.swift      — @Observable: CloudKit remote config (currently cloudKitEnabled = false → uses defaults)
│   ├── NotificationService.swift      — Rich notifications with challenge preview
│   └── SubscriptionService.swift      — StoreKit 2 management; @Observable singleton
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── SkillMapViewModel.swift
│   ├── PracticeViewModel.swift
│   ├── AnalyticsViewModel.swift
│   ├── AddSkillViewModel.swift
│   ├── SettingsViewModel.swift
│   └── OnboardingViewModel.swift
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingContainerView.swift — Root container: 5-page flow with dot-progress indicator
│   │   ├── WelcomeView.swift
│   │   ├── HowItWorksView.swift
│   │   ├── AddFirstSkillsView.swift
│   │   ├── AISetupOnboardingView.swift  — Provider + key setup page
│   │   └── ReadyView.swift              — Final "you're ready" page
│   ├── Paywall/
│   │   └── PaywallView.swift
│   ├── Home/
│   │   ├── HomeView.swift             — Daily briefing + skill cards + activity feed
│   │   └── DailyBriefingCard.swift
│   ├── SkillMap/
│   │   ├── SkillMapView.swift         — Constellation + Grid toggle
│   │   ├── ConstellationView.swift    — Interactive canvas with star nodes
│   │   ├── SkillGridView.swift        — 2-column sortable grid
│   │   ├── SkillDetailView.swift      — Full detail: health ring, decay curve, stats, history
│   │   └── ManageGroupsView.swift     — Create / rename / delete skill groups
│   ├── Practice/
│   │   ├── SessionLauncherView.swift  — Daily Review / Quick Practice / Deep Dive
│   │   ├── ChallengeView.swift        — Core challenge presentation & answer input
│   │   ├── ChallengeFeedbackView.swift — Correct/wrong animations + explanation
│   │   └── SessionCompleteView.swift  — Summary card + share
│   ├── Analytics/
│   │   ├── AnalyticsView.swift        — Portfolio health, trends, per-skill comparison
│   │   ├── TimeIntelligenceView.swift — Best practice time heatmap, predictions
│   │   └── AchievementsView.swift     — Badges + level system
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── AIModelsView.swift         — Provider selection + personal key input
│   │   ├── NotificationSettingsView.swift
│   │   ├── PracticePreferencesView.swift
│   │   └── AppearanceView.swift
│   ├── AddSkill/
│   │   ├── AddSkillView.swift         — Multi-step creation flow (breadth analysis → name → category → goal)
│   │   └── SkillSuggestionsView.swift — Curated skill database
│   ├── RemoteConfig/
│   │   ├── ForceUpdateView.swift      — Shown when app version < minimumVersion
│   │   └── MaintenanceView.swift      — Shown when isMaintenanceMode = true
│   └── Components/
│       ├── SDTSkillCard.swift         — Skill display with health ring + decay indicator
│       ├── SDTHealthRing.swift        — Circular progress with gradient fill
│       ├── SDTDecayCurve.swift        — Swift Charts mini line graph
│       ├── SDTChallengeCard.swift     — Challenge with type icon + timer bar
│       ├── SDTStreakBadge.swift       — Fire + count with scale animation
│       ├── SDTProgressBar.swift       — Thin animated progress
│       ├── SDTButton.swift            — Primary/Secondary/Tertiary with haptics
│       ├── SDTChip.swift              — Tag/filter chip
│       └── SDTEmptyState.swift        — Illustrated empty states with CTA
├── Widgets/
│   ├── SkillSpotlightWidget.swift     — Small: single most-urgent skill
│   ├── DailyOverviewWidget.swift      — Medium: top 3 skills + streak
│   ├── SkillMapMiniWidget.swift       — Large: grid of colored dots
│   └── LockScreenWidget.swift         — Circular + Inline
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

> **LiveActivity / Dynamic Island** — folder and `PracticeActivity.swift` not yet created. Planned for a future sprint.

## Coding Standards

### Swift Style
- Swift 6 strict concurrency — all types must be Sendable where needed
- Prefer `@Observable` over `ObservableObject` — NEVER use `ObservableObject` or `@Published`
- Use `async/await` for ALL async operations — no completion handlers, no Combine for new code
- Use `@Bindable` for bindings to @Observable objects — NOT `@ObservedObject`
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes) except for ViewModels and @Model

### SwiftUI Patterns
- Extract views when body exceeds ~50 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` with type-safe `NavigationPath` — NEVER use `NavigationView`
- Use `.task {}` for async work — NEVER use `.onAppear` with Task {}
- Use `sensoryFeedback()` for haptics — NOT UIKit haptic generators
- All interactive elements: minimum 44×44pt tap target
- Support Dynamic Type everywhere
- Always test with VoiceOver

### Naming Conventions
- Design system components: `SDT` prefix (e.g., `SDTHealthRing`, `SDTButton`)
- ViewModels: `[Feature]ViewModel` (e.g., `HomeViewModel`)
- Services: `[Domain]Service` (e.g., `DecayEngine`, `AIService`)
- Extensions: `[Type]+[Domain].swift` (e.g., `Date+Extensions.swift`)

### SwiftData Rules
- All @Model classes are final
- Use `@Relationship` with explicit delete rules
- Cascade delete from Skill → Challenge → ChallengeResult
- No optionals on @Model properties where a default makes sense
- Use `#Predicate` for type-safe queries — never raw strings

## Design System

### Color Tokens (implement as SwiftUI Color extensions)
**Semantic:** sdtBackground (#FAFBFC / #0D0D12), sdtSurface (#FFFFFF / #1A1A24), sdtPrimary (#1B2A4A / #E8ECF4), sdtSecondary (#6B7B98 / #8B95A8)

**Health Gradient:**
- 0.9–1.0: Emerald #059669 (Thriving)
- 0.7–0.89: Teal #0D9488 (Healthy)
- 0.5–0.69: Amber #D97706 (Fading)
- 0.3–0.49: Orange #EA580C (Wilting)
- 0.0–0.29: Rose #E11D48 (Critical)

**Category Accents:**
- Programming: Indigo #6366F1 | SF Symbol: `chevron.left.forwardslash.chevron.right`
- Language: Violet #8B5CF6 | SF Symbol: `character.book.closed`
- Tool: Sky #0EA5E9 | SF Symbol: `wrench.and.screwdriver`
- Concept: Fuchsia #D946EF | SF Symbol: `lightbulb`
- Custom: Slate #64748B | SF Symbol: `star`

### Typography
- Titles & numerics: **SF Pro Rounded** (.bold / .heavy)
- Body text: **SF Pro** (.regular / .semibold)
- Code content: **SF Mono** (.medium)
- Health scores: SF Pro Rounded, 48pt, .heavy

### Spacing Scale
xxs=2, xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48
Corner radii: Cards=16, Buttons=12, Chips=8

### Animation Principles
- Healthy skill pulse: PhaseAnimator, opacity 0.6→0.9, 2s cycle
- Decay shimmer: gradient mask animation, 5s cycle, desaturation wave
- Score change: spring(duration: 0.6, bounce: 0.2)
- Challenge reveal: slide up + staggered options (0.1s delay each)
- Correct: confetti + haptic .success + green ring fill
- Wrong: shake (offset x: -10,10,-5,5,0) + haptic .warning + red flash
- Navigation: matchedGeometryEffect + .navigationTransition(.zoom)
- Buttons: sensoryFeedback(.impact(flexibility: .soft))
- Long-press skill card: scale 0.96 + shadow lift

## Decay Algorithm

```
healthScore(t) = peakScore × e^(−decayRate × daysSinceLastPractice)
```

- `decayRate` starts at 0.1, adjusts per-skill based on accuracy + response time
- Successful challenge → decrease decayRate (more durable) + push nextReviewDate
- Failed challenge → increase decayRate + sooner review
- Fast correct = strong retention; slow correct = fragile retention
- Core ML model trains on personal data over time for better prediction

## AI Integration

- **3 providers supported**: Claude (Anthropic), OpenAI (ChatGPT), Gemini (Google) — selected in Settings → AI Models
- Challenge generation model: `claude-sonnet-4-20250514` / `gpt-4o-mini` / `gemini-2.0-flash`
- Answer evaluation model: `claude-haiku-4-5-20251001` / `gpt-4o-mini` / `gemini-2.0-flash`
- Response format: structured JSON parsed with Codable (`ChallengeDTO`, `EvaluationDTO`)
- `open_ended` challenges have no `correct_answer` — `ChallengeDTO.correctAnswer` is `String?`
- API keys stored in Keychain (via `ProviderKeychain`), never hardcoded
- Context/goal field from Skill is injected into generation prompt as sub-topic focus

### AI Request Routing

Two paths depending on whether the user has a personal API key:

```
Personal key present → AIService → ClaudeAPIClient / OpenAIClient / GeminiClient → Provider direct
No personal key     → AIService → ProxyAPIClient → sdtapi.mooo.com → Provider via server
```

**Proxy structured endpoints** (server builds prompt, handles cache, injects system prompt):
- `POST /api/generate` — challenge generation with 8h TTL cache + healthScore + dedup
- `POST /api/evaluate` — answer evaluation
- `POST /api/breadth`  — skill breadth analysis

**Direct endpoint** (legacy, kept for personal-key users):
- `POST /api/chat` — raw prompt forwarding (unchanged)

## Proxy Server

**URL:** `https://sdtapi.mooo.com`
**Source:** `~/Desktop/sdt-proxy/src/`
**Server:** Hetzner CAX11, IP `178.104.87.2`, Ubuntu 24.04, PM2 + Caddy

### Deploy
```bash
scp -r ~/Desktop/sdt-proxy/src root@178.104.87.2:/root/sdt-proxy/
ssh root@178.104.87.2 "pm2 restart sdt-proxy"
curl https://sdtapi.mooo.com/health
```

### Server files
```
/root/sdt-proxy/src/
├── index.ts     — routes
├── auth.ts      — HMAC-SHA256 validation
├── rateLimit.ts — per-device daily limits (Free: 30, Pro: 300)
├── providers.ts — Claude/OpenAI/Gemini with systemPrompt support
├── prompts.ts   — server-side prompt builders
└── cache.ts     — 8h TTL cache for /api/generate
```

Use `/sdt-server` skill for full server reference — SSH, endpoints, env vars, scaling.

## Remote Config

Implemented via **CloudKit public database**.

- `RemoteConfigService` (@Observable) — fetches on launch, falls back to `AppRemoteConfig.defaults` silently
- **Currently disabled**: `private let cloudKitEnabled = false` — uses defaults until CloudKit container is registered
- To enable: flip `cloudKitEnabled = true` in `RemoteConfigService.swift` after registering the container
- Fields: `minimumVersion`, `isMaintenanceMode`, `maintenanceMessage`, `isAIEnabled`, `maxFreeSkills`, `maxFreeChallengesPerDay`
- Manage at: icloud.developer.apple.com → CloudKit Database → Public → RemoteConfig record
- `minimumVersion` default is `"0.0.0"` — do NOT change to a real version string or ForceUpdateView appears every launch

## Monetization

| Tier | Features | Price |
|------|----------|-------|
| Free | 3 skills, 5 AI challenges/day, 1 widget | — |
| Pro | Unlimited skills, unlimited AI, full analytics, all widgets, Dynamic Island, iCloud sync, export | $5.99/month or $59.99/year |
| Lifetime | All Pro features forever | $99.99 |

StoreKit 2: use Transaction.updates for real-time status, Product.SubscriptionInfo for status checks, offer 3-day free trial.

## Common Commands

```bash
# Build
xcodebuild -scheme "Skill Decay Tracker" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build

# Test
xcodebuild test -scheme "Skill Decay Tracker" -destination "platform=iOS Simulator,name=iPhone 16 Pro"

# Lint (if SwiftLint added)
swiftlint lint --config .swiftlint.yml
```

## Axiom Skills

Always check relevant Axiom skills **before** starting any task. Use the router skills first; they select the right specialized skill.

### Router Skills (invoke first for their domain)

| Domain | Skill | When to use |
|--------|-------|-------------|
| SwiftUI / Views | `axiom-ios-ui` | Any UI, layout, navigation, animation question |
| SwiftData / Models | `axiom-ios-data` | @Model, queries, migrations, relationships |
| Swift 6 Concurrency | `axiom-ios-concurrency` | async/await, actors, Sendable, data races |
| Networking / API | `axiom-ios-networking` | URLSession, Claude API, ProxyAPIClient |
| Testing | `axiom-ios-testing` | Swift Testing, XCUITest |
| Build failures | `axiom-ios-build` | Any build/compile error |
| Performance | `axiom-ios-performance` | Slow UI, memory, battery |
| System integrations | `axiom-ios-integration` | Widgets, Live Activities, Notifications, Background fetch |

### Specialized Skills (used directly or via router)

| Skill | When to use |
|-------|-------------|
| `axiom-swiftdata` | @Model patterns, SwiftData-specific patterns |
| `axiom-swiftdata-migration` | Schema version changes |
| `axiom-swift-concurrency` | actors, Task, async sequences |
| `axiom-in-app-purchases` | StoreKit 2 implementation (SubscriptionService) |
| `axiom-storekit-ref` | StoreKit 2 API reference |
| `axiom-extensions-widgets` | WidgetKit (4 widgets) + ActivityKit (Dynamic Island) |
| `axiom-push-notifications` | NotificationService, rich notifications |
| `axiom-keychain` | ProviderKeychain, API key storage |
| `axiom-swiftui-architecture` | @Observable MVVM, ViewModels, @Bindable |
| `axiom-swiftui-performance` | ConstellationView, large lists, redraws |
| `axiom-swiftui-nav` | NavigationStack, NavigationPath, deep links |
| `axiom-swiftui-layout` | Layout issues, GeometryReader, adaptive UI |
| `axiom-cloud-sync` | CloudKit via SwiftData sync |
| `axiom-ios-ai` | Claude API integration (AIService, ClaudeAPIClient) |
| `axiom-background-processing` | Pre-generation background fetch |
| `axiom-swift-testing` | #expect, @Test, @Suite macros |
| `axiom-codable` | JSON response parsing, structured AI output |
| `axiom-ios-accessibility` | VoiceOver, Dynamic Type, 44pt tap targets |
| `axiom-app-store-submission` | App Store prep, metadata, screenshots |
| `axiom-shipping` | Pre-release checklist |
| `axiom-energy` | Battery drain (background tasks, animations) |
| `axiom-storage` | File system, caching, data lifecycle |

### Reference Skills (API lookup)

`axiom-swiftui-26-ref` · `axiom-swiftui-animation-ref` (PhaseAnimator) · `axiom-cloudkit-ref` · `axiom-keychain-ref` · `axiom-push-notifications-ref` · `axiom-extensions-widgets-ref` · `axiom-background-processing-ref` · `axiom-swift-concurrency-ref` · `axiom-swiftui-nav-ref` · `axiom-swiftui-layout-ref` · `axiom-hig` · `axiom-sf-symbols-ref`

### Local Project Skills

| Skill | When to use |
|-------|-------------|
| `sdt-server` | Any work with the proxy server — SSH, deploy, endpoints, env vars |
| `sdt-challenge-flow` | Any work on AIService, ProxyAPIClient, challenge generation, evaluation, breadth analysis |

### Not Applicable to This Project

RealityKit · SceneKit · SpriteKit · Camera · Vision · MapKit · CoreLocation · AVFoundation · PhotosLibrary · tvOS · Core Data · GRDB · NowPlaying

---

## Important Rules
- NEVER use `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject` — we are iOS 18+ only
- NEVER use `NavigationView` — always `NavigationStack`
- NEVER use `onChange(of:perform:)` — use `onChange(of:) { oldValue, newValue in }`
- NEVER use `.onAppear { Task { } }` — use `.task { }`
- NEVER use Combine for new code
- NEVER use `foregroundColor()` — use `foregroundStyle()`
- NEVER use `cornerRadius()` — use `.clipShape(RoundedRectangle(cornerRadius:))`
- NEVER hardcode strings — use String Catalogs (Localizable.xcstrings)
- NEVER force unwrap optionals in production code
- ALL public API must have /// documentation comments
- ALL colors must support both light and dark mode
- ALL views must be accessible (VoiceOver labels, Dynamic Type)
- Run tests before every commit
