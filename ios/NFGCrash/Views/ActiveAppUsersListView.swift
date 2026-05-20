import SwiftUI

struct ActiveAppUsersListView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sync.activeAppUserList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(NFGTheme.muted)
                        Text("No one else detected in the app right now.")
                            .font(.system(size: 14))
                            .foregroundStyle(NFGTheme.muted)
                            .multilineTextAlignment(.center)
                        if !sync.presenceTrackingAvailable {
                            Text("Your game server may need the latest presence update.")
                                .font(.system(size: 12))
                                .foregroundStyle(NFGTheme.muted.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(sync.activeAppUserList) { user in
                                HStack(spacing: 12) {
                                    avatar(for: user)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(user.resolvedName)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(NFGTheme.text)
                                            SuperFanBadgeView(badge: user.badge, compact: true)
                                            if user.isMe {
                                                Text("You")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(NFGTheme.accent2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(NFGTheme.accent.opacity(0.25))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        if let handle = user.username, !handle.isEmpty, user.isGuest != true {
                                            Text("@\(handle)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(NFGTheme.muted)
                                        } else if user.isGuest == true {
                                            Text("Not linked to TikTok")
                                                .font(.system(size: 12))
                                                .foregroundStyle(NFGTheme.muted)
                                        }
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }
                                .listRowBackground(NFGTheme.panel)
                            }
                        } header: {
                            Text("\(sync.displayedActiveAppUsers) in app now")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NFGTheme.muted)
                                .textCase(nil)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("In the app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.dark)
            .refreshable {
                await sync.refreshActiveAppUsers()
            }
        }
    }

    @ViewBuilder
    private func avatar(for user: ActiveAppUser) -> some View {
        Text(String(user.resolvedName.prefix(1)).uppercased())
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(user.isMe ? NFGTheme.logoGradient : LinearGradient(
                colors: [NFGTheme.panel2, NFGTheme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .clipShape(Circle())
    }
}
