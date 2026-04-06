import StoreKit
import SwiftUI

// MARK: - SubscriptionService

/// Single source of truth for purchase status and StoreKit 2 operations.
///
/// Inject via SwiftUI environment at the root:
/// ```swift
/// .environment(SubscriptionService.shared)
/// ```
/// Then read from any view:
/// ```swift
/// @Environment(SubscriptionService.self) private var sub
/// ```
@Observable
@MainActor
final class SubscriptionService {

    // MARK: - Product IDs
    // These must exactly match the Product IDs created in App Store Connect.

    static let monthlyID  = "com.pavelkulitski.sdt.pro.monthly"
    static let annualID   = "com.pavelkulitski.sdt.pro.annual"
    static let lifetimeID = "com.pavelkulitski.sdt.pro.lifetime"
    static let allIDs     = [monthlyID, annualID]

    // MARK: - Free Tier Limits

    /// Maximum number of skills a free user can have.
    static let freeSkillLimit = 3

    // MARK: - Singleton

    static let shared = SubscriptionService()
    private init() {}

    // MARK: - Observable State

    /// All three StoreKit products, sorted: monthly → annual → lifetime.
    private(set) var products: [Product] = []
    /// `true` when an active Pro entitlement exists.
    private(set) var isPro: Bool = false
    /// Product ID of the currently active entitlement, if any.
    private(set) var activeProductID: String? = nil
    /// `true` while `Product.products(for:)` is in flight.
    private(set) var isLoadingProducts = false
    /// Non-nil when a purchase or restore operation encounters an error.
    private(set) var purchaseError: String? = nil
    /// `true` while a purchase or restore call is in flight.
    private(set) var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    // MARK: - Startup

    /// Call once at app launch (`SkillDecayTrackerApp.body`).
    /// Loads products, refreshes entitlements, and starts the transaction listener.
    func start() async {
        async let productsLoad: Void = loadProducts()
        async let entitlements: Void = refreshEntitlements()
        _ = await (productsLoad, entitlements)
        startListeningForTransactions()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            let order = [Self.monthlyID, Self.annualID, Self.lifetimeID]
            products = loaded.sorted {
                (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
            }
        } catch {
            products = []
        }
    }

    // MARK: - Entitlements

    /// Checks active StoreKit 2 entitlements and updates `isPro` / `activeProductID`.
    func refreshEntitlements() async {
        var hasPro = false
        var foundID: String? = nil
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if Self.allIDs.contains(tx.productID), tx.revocationDate == nil {
                hasPro = true
                foundID = tx.productID
            }
        }
        isPro          = hasPro
        activeProductID = foundID
    }

    // MARK: - Transaction Listener

    private func startListeningForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let tx):
                    await tx.finish()
                    await self?.refreshEntitlements()
                case .unverified(let tx, _):
                    // Finish unverified transactions so they don't re-deliver on next launch.
                    // We do NOT grant entitlements for unverified (failed JWS signature) transactions.
                    await tx.finish()
                }
            }
        }
    }

    // MARK: - Purchase

    /// Initiates a StoreKit purchase flow.
    ///
    /// - Returns: `true` on successful verified purchase, `false` on cancel/pending.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        isPurchasing  = true
        defer { isPurchasing = false }

        AnalyticsService.purchaseStarted(productID: product.id)

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else {
                    purchaseError = "Purchase could not be verified."
                    return false
                }
                await tx.finish()
                await refreshEntitlements()
                AnalyticsService.purchaseCompleted(productID: product.id)
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Purchase is pending approval. If Ask to Buy is enabled, a family organizer must approve it in Settings."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            AnalyticsService.purchaseFailed(productID: product.id)
            return false
        }
    }

    // MARK: - Restore

    /// Syncs with the App Store and refreshes entitlements.
    func restore() async {
        purchaseError = nil
        isPurchasing  = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            AnalyticsService.restoreCompleted(wasPro: isPro)
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Error Dismissal

    /// Clears the last purchase error so the alert can be dismissed.
    func clearPurchaseError() {
        purchaseError = nil
    }

    // MARK: - Convenience Accessors

    var monthlyProduct:  Product? { products.first { $0.id == Self.monthlyID  } }
    var annualProduct:   Product? { products.first { $0.id == Self.annualID   } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }

    /// `true` when the user can add another skill without upgrading.
    func canAddSkill(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeSkillLimit
    }

    // MARK: - Free-tier Degradation Helpers

    /// The first `freeSkillLimit` skills by creation date — always accessible for free users.
    ///
    /// Sorting is done inside this method so callers can pass any ordering.
    func freeSkillIDs(from skills: [Skill]) -> Set<UUID> {
        let sorted = skills.sorted { $0.createdAt < $1.createdAt }
        return Set(sorted.prefix(Self.freeSkillLimit).map(\.id))
    }

    /// Returns `true` when `skill` is beyond the free limit and the user has no active Pro subscription.
    ///
    /// Locked skills are shown with a visual overlay and are non-interactive until Pro is restored.
    func isSkillLocked(_ skill: Skill, allSkills: [Skill]) -> Bool {
        !isPro && !freeSkillIDs(from: allSkills).contains(skill.id)
    }

    /// The question count to use for a session: the skill's stored value for Pro, capped at 5 for free users.
    ///
    /// When a subscription lapses, sessions are capped at 5.
    /// When Pro is restored, the original `skill.questionCount` is used automatically — no data migration needed.
    func effectiveQuestionCount(for skill: Skill) -> Int {
        isPro ? skill.questionCount : min(5, skill.questionCount)
    }

    /// Percentage saved by choosing annual over 12 × monthly. `nil` if products unavailable.
    var annualSavingsPercent: Int? {
        guard let m = monthlyProduct, let a = annualProduct else { return nil }
        let annualized = m.price * 12
        guard annualized > 0 else { return nil }
        let savings = (annualized - a.price) / annualized
        return Int((savings as NSDecimalNumber).doubleValue * 100)
    }
}
