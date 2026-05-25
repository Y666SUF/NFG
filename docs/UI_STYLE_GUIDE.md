# NFG Crash — UI Style Guide

Design system used by the SwiftUI iOS companion app for the NFG Crash TikTok LIVE
crash multiplier game. Extend, don't replace, when adding new screens.

Reference files:
- `ios/NFGCrash/Theme/NFGTheme.swift` — palette, gradients, spacing, radii, fonts
- `ios/NFGCrash/Theme/Components.swift` — shared component recipes

## Palette

| Token            | Hex / Description                       | Usage                                        |
|------------------|------------------------------------------|----------------------------------------------|
| `background`     | #070B12 near-black                       | App canvas                                   |
| `panel`          | #0F1B2A navy                             | Cards, surfaces                              |
| `panel2`         | #0B1623 deeper navy                      | Inputs, recessed surfaces                    |
| `text`           | #EEF7FF                                  | Primary copy                                 |
| `muted`          | #9FB3C9                                  | Secondary copy, eyebrows                     |
| `accent`         | #4FD1FF cyan                             | Primary CTA, multiplier (running), brand     |
| `accent2`        | #7EE7C4 mint                             | Wallet, winners, success                     |
| `danger`         | #FF6B6B coral red                        | Crash, lost, jet lock                        |
| `gold`           | #FBBF24                                  | Super Fan, tax pot, rewarded ad              |
| `border`         | rgba(white, .14)                         | Default 1px outlines                         |
| `chipBackground` | rgba(white, .06)                         | Chip / pill backdrops                        |
| `cardBorder`     | rgba(white, .10)                         | Inner card outline                           |
| `betDockBackground` | #09101A                               | Sticky bet dock                              |
| `inputBackground` | #0D1724                                 | TextField recessed background                |

## Gradients

- `logoGradient`: purple → pink. Brand-only.
- `accentGradient`: cyan → mint. Primary CTA, multiplier ribbon.
- `crashGradient`: coral → magenta. Crashed state.
- `goldGradient`: gold → amber. Rewarded ad / SUPER FAN highlight.
- `panelGradient`: navy → deeper navy. Default card fill.
- `hairlineBorder`: white(18%) → white(4%). Default card edge.

## Spacing scale (8pt grid)

`NFGSpacing.xxs=2`, `xs=4`, `sm=8`, `md=12`, `lg=16`, `xl=20`, `xxl=28`

Default padding inside cards: `md` (12pt). Default gap between sibling cards: `lg` (16pt).

## Radii

`NFGRadius.sm=8`, `md=12`, `lg=16`, `xl=20`, `chip=999`.

- Chip / capsule pills → `chip`.
- Bet rows, chart card → `md`.
- Card containers → `lg`.
- Modal sheets, round-result popup → `xl`.

## Typography

- Headlines / wordmark: SF Rounded, .black weight (`NFGFont.label`).
- Multiplier readouts and numeric data: SF Monospaced (`NFGFont.multiplier`, `NFGFont.numeric`).
- Eyebrow micro-labels (section headers, chip text): SF Rounded, .heavy, tracking ~1.2-1.4 (`NFGFont.eyebrow`).
- Body copy: SF default, .medium / .semibold for emphasis.
- Minimum body size: 11pt. Minimum tap target: 44pt.

## Components

### Card — `.nfgCard()`
Default gradient navy fill, 1px hairline gradient border, soft drop shadow. Pass `borderColor:` for accent edges (gold for free-points card, accent2 for balance card, accent for code card).

```swift
content.nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md, borderColor: NFGTheme.gold.opacity(0.35))
```

### Primary CTA — `NFGPrimaryButtonStyle`
Gradient pill with subtle top sheen, press scales to 97% and dims glow. Defaults to cyan→mint; pass `tintGradient: NFGTheme.goldGradient, glowColor: NFGTheme.gold` for gold variant. Disabled state collapses to panel.

### Secondary CTA — `NFGSecondaryButtonStyle`
Panel fill, tinted border, tinted text. Use for `!bal`, "Copy command", inline actions.

### Chip — `NFGChip`
Capsule, used for `Lv 12`, `SUPER FAN`, balance pill on the entries header.

### Section header — `NFGSectionHeader`
All-caps eyebrow + optional icon, optional trailing slot.

### Phase badge — `NFGPhaseBadge`
Pill that reflects the current game phase (Idle / Betting / Flying / Crashed) with icon.

### Multiplier text — `NFGMultiplierText`
Monospaced multiplier readout with phase-aware glow and `numericText` content transition.

### Pulse dot — `NFGPulseDot`
LIVE dot with expanding-ring pulse (used in TikTok LIVE badge).

### Scene background — `NFGSceneBackground`
Atmospheric backdrop (top purple glow + dynamic bottom cyan glow that builds with multiplier + crash flash). Drop into the root `ZStack` of full screens.

### Input field — `.nfgInputBackground(focused:)`
Recessed background with accent stroke when focused. Use on `TextField`s in the bet dock and chat.

## Motion

- All button presses scale to ~0.97 with `.spring(response: 0.22, dampingFraction: 0.7)`.
- LIVE dot pulses at 1.2s repeat.
- Chart rocket head wobbles ~8% scale while running (`rocketWobble` ease in/out 1.4s).
- Counter changes (multiplier, in-app users, balance, inventory) use `.contentTransition(.numericText(value:))`.
- Modal popups: opacity + scale 0.94 → 1.0 on appear.

## Layout rules

- Top-of-screen logo height: 52pt.
- Sticky bet dock background: solid `betDockBackground`, accent 22% stroke, soft upward shadow so it lifts off the entries panel.
- Game screen middle pane split: chart ~34% of available height, entries ~26%. Bet dock anchored bottom.
- Safe-area bottom is respected via `KeyboardAvoidingView` / `keyboardLiftAmount`.

## Don'ts

- Don't add purple → white gradients (we have logoGradient on dark only).
- Don't use centered, equal-spaced cards by default — use a clear focal element per screen.
- Don't introduce new font families (SF system covers everything: rounded + monospaced).
- Don't reach for Lottie unless we already use it — `react-native-reanimated`-equivalent here is plain SwiftUI animation, which is enough.
- Don't lose the `monospaced` design on multiplier / bet / timer / balance text.
