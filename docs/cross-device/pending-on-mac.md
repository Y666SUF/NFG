---
cross_device_status: done
from_device: pc
target_device: mac
created_at: 2026-06-10T18:00:00Z
title: iOS smooth crash multiplier TestFlight build
related_paths:
 - ios/NFGCrash/Models/GameModels.swift
 - ios/NFGCrash/Services/SyncClient.swift
 - ios/NFGCrash/Views/GameView.swift
 - server/game.js
---

# Mac companion task: iOS smooth crash multiplier (TestFlight)

Ship iOS build with 60fps wall-clock multiplier projection matching the fixed PC overlay.

## Done on Mac

- `CrashGameState.runStartedAt`, `opts.multiplierPerSecond`, `RoundLastResult.emptyRound`
- `SyncClient.displayMultiplier` at 60fps via `Timer`; `projectedRunningMult(for:)` uses wall-clock (no server cap)
- Chart/UI uses `displayMultiplier` instead of raw server ticks
- Empty-round subline: "No players this round — would have crashed at X×"
- Server exposes `runStartedAt` + `emptyRound` in game state
- Build **166** archived and uploaded to TestFlight

## Smoke test (device → https://y666suf.com)

- [ ] Round with bets: multiplier climbs smoothly (no 1s freeze/jump)
- [ ] Skip a round (no bet): chart shows would-have crash, not 1×
- [ ] Manual cashout still works
