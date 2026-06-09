import SwiftUI

struct LinkTikTokView: View {
    @EnvironmentObject private var sync: SyncClient
    @State private var linkCode = ""
    @State private var tiktokCommand = ""
    @State private var secondsLeft = 0
    @State private var statusMessage = "Generate a code, then comment it on the live stream from your TikTok app."
    @State private var statusIsError = false
    @State private var isLoading = false
    @State private var isPolling = false
    @State private var pollTask: Task<Void, Never>?
    @State private var showLegal = false

    var body: some View {
        ZStack {
            NFGSceneBackground(phase: .idle)

            ScrollView {
                VStack(alignment: .leading, spacing: NFGSpacing.xl) {
                    header
                    stepsCard
                    if !linkCode.isEmpty {
                        codeCard
                    }
                    actionButtons
                    securityNote

                    Button {
                        showLegal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 11, weight: .bold))
                            Text("Legal & compliance")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(NFGTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .padding(NFGSpacing.xl)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLegal) {
            LegalComplianceView()
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NFGSpacing.md) {
            NFGCrashBrandLogo(height: 56)
            VStack(alignment: .leading, spacing: NFGSpacing.sm) {
                Text("Verify TikTok account")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("You can’t type someone else’s username. TikTok proves it’s you by sending a comment from your account while the stream is live.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: NFGSpacing.md) {
            NFGSectionHeader(title: "How to link", icon: "list.number")
            stepRow(1, "Go live on TikTok (or join while you’re live).")
            stepRow(2, "Tap **Get link code** below.")
            stepRow(3, "On **your** @y666.suf **live**, comment **only** the command below (copy/paste).")
            stepRow(4, "This app detects the link automatically — no typing your name.")
        }
        .nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md)
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: NFGSpacing.md) {
            Text("\(n)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [NFGTheme.accent.opacity(0.4), NFGTheme.accent.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(Circle().stroke(NFGTheme.accent.opacity(0.5), lineWidth: 1))
                .foregroundStyle(NFGTheme.accent)
            Text(LocalizedStringKey(text))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NFGTheme.text)
        }
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: NFGSpacing.md) {
            NFGSectionHeader(title: "Your link command", icon: "terminal.fill")
            Text(tiktokCommand)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
                .shadow(color: NFGTheme.accent2.opacity(0.35), radius: 6)
                .textSelection(.enabled)
                .padding(.horizontal, NFGSpacing.md)
                .padding(.vertical, NFGSpacing.sm + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: NFGRadius.md)
                        .fill(Color.black.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NFGRadius.md)
                        .stroke(NFGTheme.accent2.opacity(0.3), lineWidth: 1)
                )

            if secondsLeft > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                    Text("Expires in \(secondsLeft)s")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(NFGTheme.gold)
            }

            Button("Copy command") {
                UIPasteboard.general.string = tiktokCommand
                setStatus("Copied — paste into TikTok live chat.", isError: false)
            }
            .buttonStyle(NFGSecondaryButtonStyle(tint: NFGTheme.accent2, compact: true))
        }
        .nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md, borderColor: NFGTheme.accent.opacity(0.35))
    }

    private var actionButtons: some View {
        VStack(spacing: NFGSpacing.md) {
            Button {
                Task { await startLink() }
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    Text(linkCode.isEmpty ? "GET LINK CODE" : "NEW CODE")
                        .tracking(1.2)
                }
            }
            .buttonStyle(NFGPrimaryButtonStyle(isDisabled: isLoading))
            .disabled(isLoading)

            statusBanner

            if isPolling {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(NFGTheme.accent)
                        Text("Waiting for TikTok live comment…")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NFGTheme.muted)
                    }
                    Text("Comment exactly \(tiktokCommand) on your @y666.suf live from your TikTok account.")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.gold)
                }
            }
        }
    }

    private var statusBanner: some View {
        Text(statusMessage)
            .font(.subheadline)
            .foregroundStyle(statusIsError ? Color.red.opacity(0.95) : NFGTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(statusIsError ? Color.red.opacity(0.12) : NFGTheme.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var securityNote: some View {
        Text("Why this is safe: only TikTok Live can confirm your username. The app never trusts a name typed on the phone. Impersonators cannot bet as you without your TikTok account.")
            .font(.caption)
            .foregroundStyle(NFGTheme.muted)
    }

    @MainActor
    private func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    @MainActor
    private func startLink() async {
        pollTask?.cancel()
        isPolling = false
        isLoading = true
        setStatus("Connecting…", isError: false)

        defer { isLoading = false }

        guard let api = try? GameAPI(baseURLString: PlayerSession.serverBaseURL) else {
            setStatus("Could not connect. Try again in a moment.", isError: true)
            return
        }

        do {
            let resp = try await api.startTikTokLink(deviceId: AuthStore.deviceId)
            linkCode = resp.code
            tiktokCommand = resp.tiktokCommand
            secondsLeft = resp.expiresInSeconds
            setStatus(resp.resolvedInstructions, isError: false)
            isPolling = true
            pollTask = Task {
                await pollUntilLinked(api: api, code: resp.code)
            }
        } catch {
            setStatus(friendlyNetworkError(error), isError: true)
        }
    }

    private func friendlyNetworkError(_ error: Error) -> String {
        if let apiErr = error as? GameAPIError, let msg = apiErr.errorDescription {
            return msg
        }
        if (error as? URLError)?.code == .timedOut {
            return GameAPIError.timedOut.errorDescription ?? "Timed out"
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                return "Can't connect right now. Try again in a moment."
            case NSURLErrorTimedOut, NSURLErrorDataNotAllowed:
                return "Connection timed out. Try again."
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Check Wi‑Fi or mobile data."
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private func pollUntilLinked(api: GameAPI, code: String) async {
        while !Task.isCancelled {
            do {
                let status = try await api.linkStatus(code: code)
                if status.status == "linked",
                   let token = status.token,
                   let userId = status.userId {
                    await MainActor.run {
                        AuthStore.saveSession(
                            token: token,
                            userId: userId,
                            displayName: status.displayName ?? userId
                        )
                        isPolling = false
                        setStatus("Linked as @\(userId)", isError: false)
                        sync.connect()
                    }
                    return
                }
                if status.status == "pending" {
                    await MainActor.run {
                        secondsLeft = status.secondsLeft ?? secondsLeft
                        if secondsLeft > 0, secondsLeft % 10 == 0 || secondsLeft < 30 {
                            setStatus(
                                "Still waiting… comment \(tiktokCommand) on your live. \(secondsLeft)s left.",
                                isError: false
                            )
                        }
                    }
                } else if status.status == "expired_or_unknown" {
                    await MainActor.run {
                        isPolling = false
                        setStatus("Code expired. Generate a new code.", isError: true)
                    }
                    return
                }
            } catch {
                await MainActor.run {
                    setStatus(friendlyNetworkError(error), isError: true)
                    isPolling = false
                }
                return
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}
