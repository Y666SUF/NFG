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

                HStack(spacing: NFGSpacing.sm) {
                    TextField("Message players…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .font(.system(size: 14, weight: .medium))
                        .nfgInputBackground(focused: inputFocused)
                        .focused($inputFocused)

                    Button {
                        let text = draft
                        draft = ""
                        Task { await sync.sendAppChat(text) }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                Circle().fill(NFGTheme.logoGradient)
                            )
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color(red: 236/255, green: 72/255, blue: 153/255).opacity(0.5), radius: 8, y: 3)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                }
                .padding(NFGSpacing.md)
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
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(msg.isMine ? NFGTheme.accent2 : NFGTheme.muted)
                    if !msg.resolvedAppLabel.isEmpty && !msg.isMine {
                        Text(msg.resolvedAppLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(NFGTheme.muted.opacity(0.85))
                    }
                    SuperFanBadgeView(badge: msg.badge, compact: true)
                }
                Text(msg.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NFGTheme.text)
                    .padding(.horizontal, NFGSpacing.md)
                    .padding(.vertical, NFGSpacing.sm + 2)
                    .background(
                        RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                            .fill(msg.isMine
                                ? AnyShapeStyle(LinearGradient(colors: [NFGTheme.accent.opacity(0.32), NFGTheme.accent.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(NFGTheme.panelGradient))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                            .stroke(msg.isMine ? NFGTheme.accent.opacity(0.45) : NFGTheme.border, lineWidth: 1)
                    )
                    .shadow(color: msg.isMine ? NFGTheme.accent.opacity(0.12) : .clear, radius: 6, y: 2)
            }
            if !msg.isMine { Spacer(minLength: 48) }
        }
    }
}
