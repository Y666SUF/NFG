import Foundation

enum PrivacyPolicyContent {
    static let lastUpdated = "20 May 2026"
    static let contactEmail = "privacy@y666suf.com"
    static let websiteHost = "y666suf.com"

    struct Section: Identifiable {
        let id: String
        let title: String
        let body: String
    }

    static let sections: [Section] = [
        Section(
            id: "intro",
            title: "Introduction",
            body: """
            NFG Crash (“the App”) is a companion application for a TikTok LIVE “crash” style game operated by the stream host. This Privacy Policy explains how we collect, use, and protect information when you use the App.

            The App uses virtual points for entertainment and leaderboard competition. There is no cash-out, no withdrawals, and no real-money gambling within the App.
            """
        ),
        Section(
            id: "controller",
            title: "Who we are",
            body: """
            The data controller for the App is the operator of the NFG Crash live game service (the “Service”), contactable at \(contactEmail).

            The App connects to game servers operated for the Service, including hosts under \(websiteHost).
            """
        ),
        Section(
            id: "collect",
            title: "Information we collect",
            body: """
            We may collect or process the following categories of information:

            • Account / identity: TikTok username and display name after you verify ownership by commenting on the host’s live stream; a session token stored securely on your device.
            • Device: a random device identifier sent with API requests; iOS version and app version for support.
            • Gameplay: virtual point balance, bets, cash-out targets, chat messages you send in App chat, and related game state stored on the Service.
            • Advertising: if you watch optional rewarded ads, Google AdMob may collect device identifiers, ad interaction data, and (if you allow it on iOS) data used for personalized advertising.
            • Technical logs: IP address and request timestamps on our servers for security and reliability (e.g. via Cloudflare).
            """
        ),
        Section(
            id: "use",
            title: "How we use information",
            body: """
            We use information to:

            • Operate the game and sync your balance with the live stream
            • Verify your TikTok account and prevent impersonation
            • Show leaderboards and in-app chat
            • Deliver optional rewarded advertisements and grant in-game points after you complete an ad
            • Maintain security, prevent abuse, and improve stability

            We do not sell your personal information.
            """
        ),
        Section(
            id: "legal",
            title: "Legal bases (EEA/UK users)",
            body: """
            Where applicable law requires a legal basis, we rely on: performance of the service you request, legitimate interests in operating a safe live game companion, and your consent where required (for example, optional ad tracking via Apple’s App Tracking Transparency).
            """
        ),
        Section(
            id: "sharing",
            title: "Sharing with third parties",
            body: """
            We may share information with:

            • Our game servers and hosting providers (including Cloudflare) to route traffic to the Service
            • Google (AdMob) when you choose to view ads — governed by Google’s privacy policy: https://policies.google.com/privacy
            • TikTok when you interact with the live stream under TikTok’s own terms and privacy policy
            • Law enforcement if required by law

            App chat messages may be visible to other players using the App during the same live session.
            """
        ),
        Section(
            id: "retention",
            title: "Retention",
            body: """
            We keep account and gameplay data while your account is active and as needed to operate the Service. Server logs are retained for a limited period for security. You may stop using the App at any time; contact us to request deletion of server-side account data where applicable.
            """
        ),
        Section(
            id: "security",
            title: "Security",
            body: """
            We use HTTPS, authenticated sessions, and industry-standard practices appropriate to a live game service. No method of transmission over the Internet is 100% secure.
            """
        ),
        Section(
            id: "children",
            title: "Children",
            body: """
            The App is not directed at children under 13. We recommend users aged 17+ due to simulated betting mechanics. We do not knowingly collect personal information from children under 13.
            """
        ),
        Section(
            id: "rights",
            title: "Your rights",
            body: """
            Depending on where you live, you may have rights to access, correct, delete, or restrict processing of your personal data, or to object to certain processing. Contact \(contactEmail). You may also complain to your local data protection authority.

            On iOS you can limit ad tracking under Settings → Privacy & Security → Tracking.
            """
        ),
        Section(
            id: "intl",
            title: "International transfers",
            body: """
            Data may be processed in the United Kingdom and other countries where our servers or providers operate. We take steps reasonably necessary to protect your information when transferred.
            """
        ),
        Section(
            id: "changes",
            title: "Changes",
            body: """
            We may update this policy from time to time. The “Last updated” date at the top will change. Continued use of the App after changes means you accept the updated policy.
            """
        ),
        Section(
            id: "contact",
            title: "Contact",
            body: """
            Questions about this policy: \(contactEmail)
            """
        ),
    ]
}
