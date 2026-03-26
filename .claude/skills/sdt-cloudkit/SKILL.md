# SDT CloudKit Skill

Use this skill whenever working with CloudKit, RemoteConfigService, or iCloud sync in this project.

---

## Current Status

**CloudKit is DISABLED** until the Apple Developer Portal is set up.

- `RemoteConfigService.cloudKitEnabled = false` — flip to `true` when ready
- `AppRemoteConfig.defaults.minimumVersion = "0.0.0"` — safe default, never triggers force update
- User will notify when Developer Account is created

---

## CloudKit Usage in This Project

Two separate CloudKit roles:

| Role | Database | Status |
|------|----------|--------|
| **Remote Config** | Public DB | Disabled (no dev account yet) |
| **SwiftData sync** | Private DB (auto via SwiftData) | Inactive (no dev account yet) |

---

## Remote Config (Public Database)

### File
`Skill Decay Tracker/Services/RemoteConfigService.swift`

### How it works
1. App launches → `RemoteConfigService.fetch()` called in `.task {}`
2. Checks `cloudKitEnabled` flag → if false, falls back silently
3. If enabled: queries `RemoteConfig` record from CloudKit public DB
4. Falls back: CloudKit → UserDefaults cache → `AppRemoteConfig.defaults`

### Enable CloudKit (when Developer Account is ready)
1. Set `cloudKitEnabled = true` in `RemoteConfigService`
2. Open https://icloud.developer.apple.com → your container
3. Schema → Record Types → Create `RemoteConfig` with these fields:

| Field | Type |
|-------|------|
| `minimumVersion` | String |
| `isMaintenanceMode` | Int64 (0/1) |
| `maintenanceMessage` | String |
| `isAIEnabled` | Int64 (0/1) |
| `maxFreeSkills` | Int64 |
| `maxFreeChallengesPerDay` | Int64 |

4. Public Database → Records → Add one `RemoteConfig` record with initial values
5. To update config later: edit the record in CloudKit dashboard — changes apply on next app launch (no App Store release needed)

### AppRemoteConfig defaults (safe fallback values)
```swift
minimumVersion:          "0.0.0"   // ← NEVER triggers ForceUpdateView
isMaintenanceMode:       false
maintenanceMessage:      ""
isAIEnabled:             true
maxFreeSkills:           3
maxFreeChallengesPerDay: 5
```

> ⚠️ Do NOT change `minimumVersion` default back to "1.0.0" — this caused ForceUpdateView
> to trigger on every launch because the app version was below it.

### ForceUpdateView trigger
`needsForceUpdate` in `RemoteConfigService`:
```swift
var needsForceUpdate: Bool {
    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    return current.compare(config.minimumVersion, options: .numeric) == .orderedAscending
}
```
Only set `minimumVersion` in CloudKit to a real version (e.g. `"1.2.0"`) when you want to force users to update.

---

## SwiftData + CloudKit Sync (Private Database)

### How it's configured
SwiftData auto-syncs to CloudKit private DB when:
- App has `iCloud` + `CloudKit` entitlements
- `ModelContainer` is initialized with `cloudKitContainerIdentifier`

### Current state
Entitlements may be present in the project but sync is inactive without a registered container.
When Developer Account is ready:
1. Register container in Apple Developer Portal
2. Add `NSUbiquitousContainerIsDocumentScopePublic` = YES to entitlements if needed
3. Test sync between two devices/simulators with same iCloud account

---

## Common CloudKit Pitfalls in This Project

| Problem | Cause | Fix |
|---------|-------|-----|
| `EXC_BREAKPOINT` on `CKContainer.default()` | Container not registered in Developer Portal | Keep `cloudKitEnabled = false` until registered |
| `ForceUpdateView` on every launch | `defaults.minimumVersion` > app version | Defaults must be `"0.0.0"` |
| `ubiquityIdentityToken` guard passes but still crashes | iCloud sign-in ≠ CloudKit container registration | Use `cloudKitEnabled` flag, not iCloud sign-in check |

---

## Key Files

| File | Purpose |
|------|---------|
| `Services/RemoteConfigService.swift` | Fetch + cache remote config |
| `Views/RemoteConfig/ForceUpdateView.swift` | Shown when `needsForceUpdate == true` |
| `App/SkillDecayTrackerApp.swift` | Calls `remoteConfig.fetch()` on launch, checks flags |
