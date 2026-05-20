import SwiftUI

struct AppChatView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var showOnlineList = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if sync.appChatMessages.isEmpty {
                                Text("Say hi to other players in the app.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(NFGTheme.muted)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 32)
                            }
                            ForEach(sync.appChatMessages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: sync.appChatMessages.count) { _, _ in
                        if let last = sync.appChatMessages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = sync.appChatMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if let err = sync.appChatError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.danger)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                }

                HStack(spacing: 8) {
                    TextField("Message players…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(10)
                        .background(NFGTheme.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(NFGTheme.text)
                        .focused($inputFocused)

                    Button {
                        let text = draft
                        draft = ""
                        Task { await sync.sendAppChat(text) }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(NFGTheme.logoGradient)
                            .clipShape(Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(NFGTheme.panel.opacity(0.95))
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("App Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showOnlineList = true
                    } label: {
                        onlineToolbarLabel
                    }
                    .accessibilityLabel("\(sync.displayedActiveAppUsers) players in the app")
                    .accessibilityHint("Shows who is online in the app")
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showOnlineList) {
                ActiveAppUsersListView()
                    .environmentObject(sync)
            }
            .task {
                await sync.loadAppChatHistory()
                await sync.refreshActiveAppUsers()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    await sync.refreshActiveAppUsers()
                }
            }
        }
    }

    private var onlineToolbarLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("\(sync.displayedActiveAppUsers)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(NFGTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NFGTheme.panel)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(NFGTheme.accent.opacity(0.35)))
    }

    private func chatBubble(_ msg: AppChatMessage) -> some View {
        HStack {
            if msg.isMine { Spacer(minLength: 48) }
            VStack(alignment: msg.isMine ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(msg.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(msg.isMine ? NFGTheme.accent2 : NFGTheme.muted)
                    if !msg.resolvedAppLabel.isEmpty && !msg.isMine {
                        Text(msg.resolvedAppLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(NFGTheme.muted.opacity(0.85))
                    }
                    SuperFanBadgeView(badge: msg.badge, compact: true)
                }
                Text(msg.message)
                    .font(.system(size: 14))
                    .foregroundStyle(NFGTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(msg.isMine ? NFGTheme.accent.opacity(0.22) : NFGTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(msg.isMine ? NFGTheme.accent.opacity(0.4) : NFGTheme.border)
                    )
            }
            if !msg.isMine { Spacer(minLength: 48) }
        }
    }
}
