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
            NFGTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                        Text("Legal & compliance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NFGTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLegal) {
            LegalComplianceView()
                .environmentObject(sync)
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verify TikTok account")
                .font(.title2.bold())
                .foregroundStyle(NFGTheme.text)
            Text("You cannot type someone else’s username. TikTok proves it’s you by sending a comment from your account while the stream is live.")
                .font(.subheadline)
                .foregroundStyle(NFGTheme.muted)
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(1, "Go live on TikTok (or join while you’re live).")
            stepRow(2, "Tap **Get link code** below.")
            stepRow(3, "On **your** @y666.suf **live**, comment **only** the command below (copy/paste).")
            stepRow(4, "This app detects the link automatically — no typing your name.")
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(NFGTheme.accent.opacity(0.2))
                .clipShape(Circle())
                .foregroundStyle(NFGTheme.accent)
            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(NFGTheme.text)
        }
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your link command")
                .font(.headline)
                .foregroundStyle(NFGTheme.text)
            Text(tiktokCommand)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(NFGTheme.accent2)
                .textSelection(.enabled)

            if secondsLeft > 0 {
                Text("Expires in \(secondsLeft)s")
                    .font(.caption)
                    .foregroundStyle(NFGTheme.gold)
            }

            Button("Copy command") {
                UIPasteboard.general.string = tiktokCommand
                setStatus("Copied — paste into TikTok live chat.", isError: false)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.accent.opacity(0.35)))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await startLink() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(linkCode.isEmpty ? "Get link code" : "New code")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(NFGTheme.accent)
            .disabled(isLoading)

            statusBanner

            if isPolling {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for TikTok live comment…")
                            .font(.caption)
                            .foregroundStyle(NFGTheme.muted)
                    }
                    Text("Comment exactly \(tiktokCommand) on your @y666.suf live from your TikTok account.")
                        .font(.caption2)
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
