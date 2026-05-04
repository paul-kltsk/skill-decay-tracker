import Foundation

// MARK: - AppConstants

/// Centralised app-wide constants.
///
/// All external URLs live here so they can be updated in one place.
/// Views reference these via `AppConstants.URLs.privacyPolicy` etc.
enum AppConstants {

    // MARK: URLs

    enum URLs {
        /// Privacy Policy (GitHub Pages).
        static let privacyPolicy = URL(string: "https://paul-kltsk.github.io/skill-decay-tracker/privacy.html")!

        /// Terms of Service (GitHub Pages).
        static let termsOfService = URL(string: "https://paul-kltsk.github.io/skill-decay-tracker/terms.html")!

        /// Support page (GitHub Pages).
        static let support = URL(string: "https://paul-kltsk.github.io/skill-decay-tracker/support.html")!

        /// App Store product page.
        static let appStore = URL(string: "https://apps.apple.com/app/id6761617003")!

        /// Apple subscription management deep-link.
        static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
    }

    // MARK: Contact

    enum Contact {
        static let supportEmail = "pavel.kulitski@icloud.com"
    }
}
