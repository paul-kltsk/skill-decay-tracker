import SwiftUI
import StoreKit

// MARK: - PaywallView

/// Full-screen paywall sheet shown when a user hits a Pro-gated feature.
///
/// Reads live product data from ``SubscriptionService`` — no hardcoded prices.
/// Pass `trigger` to highlight which feature the user was trying to use.
struct PaywallView: View {

    @Environment(SubscriptionService.self) private var sub
    @Environment(\.dismiss) private var dismiss

    /// The feature that triggered this paywall (used in the subtitle).
    var trigger: ProFeature = .generic

    @State private var selectedProduct: Product? = nil
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    featureList
                        .padding(.top, SDTSpacing.xl)
                    planCards
                        .padding(.top, SDTSpacing.xl)
                    purchaseButton
                        .padding(.top, SDTSpacing.xl)
                    restoreAndLegal
                        .padding(.top, SDTSpacing.lg)
                    Spacer().frame(height: SDTSpacing.xxxl)
                }
                .padding(.horizontal, SDTSpacing.xl)
            }
            .background(Color.sdtBackground)
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.sdtSecondary)
                    }
                }
            }
        }
        .onAppear {
            // Pre-select annual plan as the recommended option.
            if selectedProduct == nil {
                selectedProduct = sub.annualProduct ?? sub.products.first
            }
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            AnalyticsService.paywallShown(trigger: trigger.analyticsName)
        }
        .alert("Purchase Error", isPresented: .constant(sub.purchaseError != nil)) {
            Button("OK") {}
        } message: {
            Text(sub.purchaseError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: SDTSpacing.md) {
            Spacer().frame(height: SDTSpacing.xxl)

            ZStack {
                // Glow rings
                Circle()
                    .fill(Color.sdtPrimary.opacity(0.08))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(Color.sdtPrimary.opacity(0.14))
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.sdtPrimary)
                    .frame(width: 60, height: 60)
                    .background(Color.sdtSurface)
                    .clipShape(Circle())
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.65), value: appeared)

            VStack(spacing: SDTSpacing.xs) {
                HStack(spacing: SDTSpacing.xs) {
                    Text("Skill Decay Tracker")
                        .sdtFont(.titleMedium)
                    ProBadgeLabel()
                }

                Text(trigger.subtitle)
                    .sdtFont(.bodyMedium, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
        }
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: SDTSpacing.sm) {
            ForEach(Array(ProFeature.bullets.enumerated()), id: \.offset) { i, bullet in
                HStack(spacing: SDTSpacing.md) {
                    Image(systemName: bullet.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.sdtPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.sdtPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bullet.title)
                            .sdtFont(.captionSemibold)
                        Text(bullet.detail)
                            .sdtFont(.caption, color: .sdtSecondary)
                    }
                    Spacer()
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.15 + Double(i) * 0.07), value: appeared)
            }
        }
        .padding(SDTSpacing.lg)
        .background(Color.sdtSurface)
        .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: SDTSpacing.sm) {
            if sub.isLoadingProducts {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(SDTSpacing.xxl)
            } else if sub.products.isEmpty {
                Text("Could not load plans. Check your connection.")
                    .sdtFont(.caption, color: .sdtSecondary)
                    .multilineTextAlignment(.center)
            } else {
                ForEach(sub.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        savingsPercent: product.id == SubscriptionService.annualID
                            ? sub.annualSavingsPercent : nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProduct = product
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
                }
            }
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await sub.purchase(product) }
        } label: {
            ZStack {
                if sub.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(purchaseButtonTitle)
                        .sdtFont(.bodySemibold, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SDTSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.button)
                    .fill(Color.sdtPrimary)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedProduct == nil || sub.isPurchasing)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
    }

    private var purchaseButtonTitle: String {
        guard let p = selectedProduct else { return "Choose a Plan" }
        if p.id == SubscriptionService.lifetimeID {
            return "Get Pro for \(p.displayPrice)"
        }
        return "Start Pro — \(p.displayPrice)"
    }

    // MARK: - Restore & Legal

    private var restoreAndLegal: some View {
        VStack(spacing: SDTSpacing.sm) {
            Button {
                Task { await sub.restore() }
            } label: {
                Text(sub.isPurchasing ? "Restoring…" : "Restore Purchases")
                    .sdtFont(.caption, color: .sdtSecondary)
            }
            .disabled(sub.isPurchasing)

            Text("Subscriptions renew automatically. Cancel anytime in Settings.")
                .sdtFont(.caption, color: .sdtSecondary)
                .multilineTextAlignment(.center)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
    }
}

// MARK: - PlanCard

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let savingsPercent: Int?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SDTSpacing.md) {
                // Radio button
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.sdtPrimary : Color.sdtSecondary.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle)
                        .sdtFont(.bodySemibold, color: .sdtPrimary)
                    Text(planSubtitle)
                        .sdtFont(.caption, color: .sdtSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .sdtFont(.bodySemibold)

                    if let pct = savingsPercent, pct > 0 {
                        Text("Save \(pct)%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.sdtCategoryProgramming)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(SDTSpacing.lg)
            .background(Color.sdtSurface)
            .clipShape(RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SDTSpacing.CornerRadius.card)
                    .strokeBorder(
                        isSelected ? Color.sdtPrimary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var planTitle: String {
        switch product.id {
        case SubscriptionService.monthlyID:  return "Pro Monthly"
        case SubscriptionService.annualID:   return "Pro Annual  ⭐ Best Value"
        case SubscriptionService.lifetimeID: return "Pro Lifetime"
        default: return product.displayName
        }
    }

    private var planSubtitle: String {
        switch product.id {
        case SubscriptionService.monthlyID:  return "Billed monthly, cancel anytime"
        case SubscriptionService.annualID:   return "Billed once per year"
        case SubscriptionService.lifetimeID: return "One-time purchase, no renewals"
        default: return ""
        }
    }
}

// MARK: - ProBadgeLabel

/// Small "PRO" pill used in headers and skill cards.
struct ProBadgeLabel: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.sdtPrimary)
            .clipShape(Capsule())
    }
}

// MARK: - ProFeature

/// The feature that triggered a paywall presentation.
///
/// Each case provides a contextual subtitle and a list of feature bullets.
enum ProFeature {
    case skillLimit
    case quickPractice
    case deepDive
    case skillGroups
    case analytics
    case generic

    var analyticsName: String {
        switch self {
        case .skillLimit:    "skill_limit"
        case .quickPractice: "quick_practice"
        case .deepDive:      "deep_dive"
        case .skillGroups:   "skill_groups"
        case .analytics:     "analytics"
        case .generic:       "generic"
        }
    }

    var subtitle: String {
        switch self {
        case .skillLimit:
            return "You've reached the 5-skill limit.\nUnlock unlimited skills with Pro."
        case .quickPractice:
            return "Quick Practice is a Pro feature.\nUpgrade to practice any skill, any time."
        case .deepDive:
            return "Deep Dive is a Pro feature.\nFocus on one skill until you master it."
        case .skillGroups:
            return "Skill Groups are a Pro feature.\nOrganise your portfolio your way."
        case .analytics:
            return "Full analytics are a Pro feature.\nSee your complete learning history."
        case .generic:
            return "Unlock unlimited skills, all practice\nmodes, groups, and full analytics."
        }
    }

    // Shared feature bullets shown on every paywall.
    static let bullets: [(icon: String, title: String, detail: String)] = [
        ("infinity",            "Unlimited Skills",          "Track as many skills as you need"),
        ("bolt.fill",           "Quick Practice",            "5-challenge sessions, any skill"),
        ("scope",               "Deep Dive Mode",            "Full focus on one skill at a time"),
        ("folder.fill",         "Skill Groups",              "Organise your learning portfolio"),
        ("chart.bar.fill",      "Full Analytics",            "All-time history and export"),
        ("arrow.triangle.2.circlepath", "Future Features",  "Widgets, iCloud sync, and more"),
    ]
}

// MARK: - Preview

#Preview {
    PaywallView(trigger: .skillLimit)
        .environment(SubscriptionService.shared)
}
