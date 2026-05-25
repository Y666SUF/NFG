# Emergent UI Polish — Changelog

Branch: `emergent/ui-polish-2026`
Scope: iOS SwiftUI companion app (`ios/NFGCrash/`). No changes to server, game logic, IAP IDs, AdMob IDs, networking, presence, chat APIs, entitlements, or legal copy.

## Goal

Make NFG Crash feel like one designed crash-game app instead of a debug UI, with:
- Cohesive crash-game aesthetic (neon dark, rocket, multiplier, explosion).
- Polished spacing, typography, depth, and motion.
- Reusable theme tokens + shared SwiftUI components, so future screens stay consistent.

## Net effect on hard constraints

- Builds in Xcode (scheme NFGCrash, Release, iPhone device/simulator) — only SwiftUI/UIKit primitives, no new dependencies, no Info.plist or entitlements changes.
- TikTok link flow, WebSocket game state, betting, cashout, wallet, StoreKit IAP, rewarded ads, app chat, presence heartbeat, join announcements, privacy/TOS screens — **unchanged in behavior**, only restyled.
- No secrets touched. No new packages.

---

## Files touched

### `ios/NFGCrash/Theme/NFGTheme.swift` — extended
- Added semantic tokens: `chipBackground`, `chipBorder`, `betDockBackground`, `cardBorder`, `cardBorderStrong`, `mutedText`, `mutedSoft`, `inputBackground`, `glow`.
- Added gradients: `accentGradient` (cyan→mint), `crashGradient` (coral→magenta), `goldGradient`, `panelGradient`, `hairlineBorder`, `backgroundGlow`.
- Added spacing scale `NFGSpacing` (8pt grid: xxs/xs/sm/md/lg/xl/xxl).
- Added corner-radius scale `NFGRadius` (sm/md/lg/xl/chip).
- Added typography helpers `NFGFont` (`multiplier`, `label`, `eyebrow`, `numeric`).
- Original palette and `SuperFanBadgeView` preserved.

### `ios/NFGCrash/Theme/Components.swift` — **new file** (registered in `project.pbxproj`)
Shared component library:
- `NFGCardModifier` + `.nfgCard()` — premium card chrome (gradient fill, hairline border, soft shadow).
- `NFGPrimaryButtonStyle` — gradient pill with sheen, press scale, glow.
- `NFGSecondaryButtonStyle` — tinted panel pill.
- `NFGSectionHeader` — tracked all-caps eyebrow with optional icon.
- `NFGChip` — capsule pill, filled or outlined.
- `NFGMultiplierText` — phase-aware monospaced multiplier with glow.
- `NFGPhaseBadge` — phase indicator (Idle / Betting / Flying / Crashed).
- `NFGPulseDot` — LIVE-style expanding-ring pulse.
- `NFGSceneBackground` — atmospheric backdrop (purple top glow + dynamic cyan bottom glow that builds with multiplier + crash flash).
- `.nfgInputBackground(focused:)` — TextField recessed background with accent focus stroke.

### `ios/NFGCrash.xcodeproj/project.pbxproj`
- 4-section insertion to register `Theme/Components.swift` (PBXBuildFile, PBXFileReference, Theme group, Sources phase). No other project settings changed.

### `ios/NFGCrash/Views/GameView.swift`
- Replaced bespoke background with `NFGSceneBackground` (running glow that grows with multiplier; crash flash on ended phase).
- Header now uses `NFGCrashBrandLogo` + `NFGPhaseBadge` + `NFGMultiplierText` with spring animation on multiplier change.
- Tax Pot banner re-styled as a gold gradient ribbon with sparkles icon, monospaced numeric.
- Entries panel: `nfgCard` + `NFGSectionHeader` + balance chip. Bet rows now have status dot, mono amount, arrow, mono multiplier. Empty state gets rocket icon. Queued group gets eyebrow label.
- Top profiles "view full leaderboard" link gets trophy icon and accent styling.
- Bet dock fully rebuilt: dedicated "Amount" / "Cash out ×" labelled fields, focused-state ring, `NFGPrimaryButtonStyle` PLACE BET with paperplane icon, gold flame all-in shortcut, login warning hint when not linked. Sticky dock sits on top of a soft background fade.
- Layout heights tuned for small iPhones (chart 34%, entries 26%).

### `ios/NFGCrash/Views/CrashChartView.swift`
- New rounded card chrome with hairline border.
- Subtle dashed grid lines and parallax motion lines during the running phase.
- Phase-aware gradients: cyan→mint fill/stroke while running, coral→magenta on crash.
- Animated rocket-head glyph at the line tip (paperplane disc with wobble), replaced by 💥 on crash.
- Large translucent in-chart multiplier overlay during running/ended phases (`.numericText` transition).
- Friendly "waiting for round" indicator instead of a dead line during betting.

### `ios/NFGCrash/Views/TikTokLiveBadge.swift`
- LIVE dot upgraded to `NFGPulseDot` (expanding ring pulse).
- Background pill gets a faint red→panel gradient when live, hairline stroke otherwise.
- Vertical separator between "LIVE" and the in-app user count.
- Soft red shadow when live.

### `ios/NFGCrash/Views/NFGCrashBrandLogo.swift`
- New sticker-style fallback (purple→pink rounded badge with chibi paperplane + NFG / CRASH two-line wordmark) so the brand still reads if `AppLogo`/`AppIcon` assets are missing.
- Existing asset-based path unchanged when `AppLogo` is present.

### `ios/NFGCrash/Views/RoundResultPopupView.swift`
- Header re-laid out: round number eyebrow, 💥 + "Crashed at X.XX×" with red glow, "won/lost" badge chips.
- Outcome sections use `NFGSectionHeader`-style eyebrows with checkmark/x icons; rows have leading status dot, monospaced bet copy, hero payout / BUSTED tag.
- Continue button uses `NFGPrimaryButtonStyle`.
- Backdrop adds a soft red radial flash for crash energy. Card uses gradient panel + hairline border + double shadow.

### `ios/NFGCrash/Views/WalletView.swift`
- Header card → `nfgCard`, avatar bumped with brand gradient and outer ring, level/rank/SuperFan now use `NFGChip`.
- Balance card: gold/diamond eyebrow, 42pt black monospaced balance with mint shadow, "pts" in faded mint, infinity icon for All-time, ambient mint radial inside.
- Rewarded ad card: gold icon disc, eyebrow heading, `NFGPrimaryButtonStyle` with gold gradient.
- Inventory section uses `NFGSectionHeader`. Tiles get circular icon backplate, monospaced count with `numericText` transition, tinted card border per type.

### `ios/NFGCrash/Views/LeaderboardView.swift`
- `TopProfilesStrip` header gets gold trophy icon + tracked eyebrow.
- Empty slots in the top-5 strip get dashed placeholder.
- `TopProfileCard` redesigned: position-aware tint (gold/cyan/mint/muted), gradient fill with optional gold tint for #1, gold glow shadow on #1.
- `LeaderboardRowView`: position circle with tint per rank, "YOU" capsule chip with stroke, rounded font for names, monospaced balance.

### `ios/NFGCrash/Views/AppChatView.swift`
- Input field uses `.nfgInputBackground(focused:)` with accent focus ring.
- Send button: larger (46pt), brand gradient circle, soft pink shadow, dim opacity when disabled.
- Chat bubbles: gradient fill for own messages, panel gradient for incoming, hairline borders, soft accent shadow on own bubbles, rounded font for names.

### `ios/NFGCrash/Views/LinkTikTokView.swift`
- Background swapped to `NFGSceneBackground` (ambient purple glow).
- Header now includes the `NFGCrashBrandLogo` and a heavier rounded title.
- Steps card wrapped in `nfgCard` + `NFGSectionHeader`.
- Step number badge gets gradient ring.
- Code card: terminal section header, command displayed as bold monospaced block on a recessed dark surface with mint glow; timer gets timer icon.
- Action button uses `NFGPrimaryButtonStyle` with link icon.
- Copy command uses `NFGSecondaryButtonStyle`.
- Legal & compliance link gets shield icon.

### `ios/NFGCrash/Views/LegalComplianceView.swift`
- Group cards use `nfgCard`; titles converted to mint tracked eyebrows for consistency.
- Section copy intentionally unchanged.

### `ios/NFGCrash/Views/ContentView.swift`
- Toolbar icon buttons (wallet / chat / leaderboard) wrapped in cyan-stroked panel circles for clear neon affordance. Accessibility labels preserved.

---

## Out of scope (intentionally not touched)

- `Services/SyncClient.swift`, `Services/GameAPI.swift`, `Services/RewardedAdService.swift`, `Services/AdMobAppStartup.swift`, `Services/StoreKit*`, `Services/OfflineQueue.swift`, `Services/PlayerSession.swift`, `Services/AuthStore.swift`.
- `Config/*` (AdMob IDs, server URLs, StoreCatalog IDs, AppDistribution).
- `Models/GameModels.swift`.
- `Legal/PrivacyPolicyContent.swift`, `Views/PrivacyPolicyView.swift` (compliance copy untouched).
- `Info.plist`, `PrivacyInfo.xcprivacy`, entitlements, bundle ID.
- `NFGCrashApp.swift` (no app lifecycle changes needed).
- `server/`, `electron/`, `windows-bridge/`, `website/`, `hangman*` — not in scope.

---

## Build verification reminders for the Mac / Xcode side

1. Open `ios/NFGCrash.xcodeproj` in Xcode (this repo).
2. Confirm `Theme/Components.swift` appears under **NFGCrash → Theme** in the project navigator (already referenced in `project.pbxproj`).
3. Build `NFGCrash` for an iPhone simulator first, then a device. Should compile cleanly on iOS 17.0+.
4. Smoke test:
   - Open app → see brand logo + LIVE pulse on top bar.
   - Link via TikTok (or use already-linked test account) → game screen.
   - Place bet → chart line should rise smoothly with rocket disc at tip and glow growing with multiplier.
   - Force a crash → 💥 + red overlay flash + RoundResultPopup with hero "Crashed at X.XX×".
   - Wallet → balance card + inventory tiles look unified.
   - Leaderboard → top-5 strip has gold #1, position chips colored.
   - App chat → bubbles styled, send button glows pink.
5. If `AppLogo` asset is unchanged it will continue to render. If you ever swap it out, the sticker fallback wordmark will appear automatically.

## Sanity checks performed in this branch
- Swift code uses only SwiftUI / UIKit primitives available on iOS 17.0 (deployment target).
- No new Swift Package or CocoaPod added.
- `project.pbxproj` was edited only to register the new `Theme/Components.swift` (4 atomic insertions).
- `Models/GameModels.swift` types referenced (`OpenBet`, `GamePhase`, `RoundResultSummary`, `RoundOutcome`, `LeaderboardRow`, `AppChatMessage`, `ActiveAppUser`, `SuperFanBadgeDisplay`) are all read-only — only their existing public surface is consumed.
