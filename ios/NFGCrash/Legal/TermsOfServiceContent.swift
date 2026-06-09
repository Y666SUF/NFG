import Foundation

enum TermsOfServiceContent {
    static let lastUpdated = "19 May 2026"
    static let contactEmail = "support@y666suf.com"
    static let websiteHost = PrivacyPolicyContent.websiteHost

    struct Section: Identifiable {
        let id: String
        let title: String
        let body: String
    }

    static let sections: [Section] = [
        Section(
            id: "accept",
            title: "Agreement",
            body: """
            By downloading or using NFG Crash (“the App”), you agree to these Terms of Service. If you do not agree, do not use the App.

            The App is a companion for the NFG Crash TikTok LIVE entertainment game. Virtual points have no cash value and cannot be withdrawn or exchanged for money.
            """
        ),
        Section(
            id: "eligibility",
            title: "Eligibility",
            body: """
            You must be at least 17 years old to use the App because it includes simulated betting-style mechanics tied to a live stream game.

            You are responsible for complying with local laws where you use the App.
            """
        ),
        Section(
            id: "account",
            title: "Account & TikTok linking",
            body: """
            Access to betting and wallet features requires verifying ownership of a TikTok account by posting a command on the host’s live stream. You may not impersonate another person or use accounts you do not control.

            We may suspend or revoke access for abuse, fraud, or violations of these terms.
            """
        ),
        Section(
            id: "virtual",
            title: "Virtual points & entertainment",
            body: """
            Points, badges, cosmetics, and arcade rewards are virtual entertainment credits. They are not legal tender, securities, or gambling winnings. There is no cash-out.

            Leaderboards and in-app competition are for fun among viewers of the live stream.
            """
        ),
        Section(
            id: "purchases",
            title: "In-App Purchases & ads",
            body: """
            Optional point packs are sold only through Apple In-App Purchase. Prices are shown in the App before you confirm a purchase. All sales are final per Apple’s policies except where required by law.

            Optional rewarded video ads may grant bonus points. Ad availability is not guaranteed. See our Privacy Policy for how ad partners may process data.
            """
        ),
        Section(
            id: "conduct",
            title: "Acceptable use",
            body: """
            You agree not to:

            • Cheat, exploit bugs, automate play, or interfere with servers.
            • Harass other users or post prohibited display names or chat content.
            • Reverse engineer the App or attempt unauthorized access to systems.

            We may modify, limit, or discontinue features at any time.
            """
        ),
        Section(
            id: "disclaimer",
            title: "Disclaimer",
            body: """
            The App and live game service are provided “as is” without warranties of any kind. We do not guarantee uninterrupted service, specific outcomes, or error-free operation.

            To the fullest extent permitted by law, we are not liable for indirect or consequential damages arising from use of the App.
            """
        ),
        Section(
            id: "changes",
            title: "Changes",
            body: """
            We may update these terms. Material changes will be reflected by updating the “Last updated” date. Continued use after changes means you accept the revised terms.

            Questions: \(contactEmail)
            """
        ),
    ]
}
