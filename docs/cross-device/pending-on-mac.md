---
cross_device_status: pending
from_device: pc
target_device: mac
created_at: 2026-06-30T22:00:00Z
title: iOS TestFlight — smooth crash multiplier (matches PC fix)
related_paths:
 - ios/NFGCrash/Services/SyncClient.swift
 - ios/NFGCrash/Models/GameModels.swift
 - ios/NFGCrash/Views/GameView.swift
 - server/game.js
---

# Mac companion task: iOS TestFlight — smooth crash multiplier

## Context
PC Windows overlay is **fixed and verified**. Server + web use one formula:

`multiplier = floor((1 + rate × elapsedSeconds) × 100) / 100` from `runStartedAt` (epoch ms).

iOS Swift source was updated on PC but needs **sync-pull, verify, archive, TestFlight**.

## Do on this device
1. `./scripts/sync-pull.sh`
2. Verify iOS changes (implement anything missing):
   - `GameModels.swift`: `runStartedAt`, `opts.multiplierPerSecond`, `lastResult.emptyRound`
   - `SyncClient.swift`: `@Published displayMultiplier`, 60fps timer, `projectedRunningMult` from wall-clock (no ceiling cap)
   - `GameView.swift`: chart + background use `sync.displayMultiplier`, not raw `gameState.multiplier`
   - Empty round subline: "No players this round — would have crashed at X×"
3. Grep for any remaining `gameState.multiplier` in chart/UI — replace with `displayMultiplier`
4. Bump build number → Archive → TestFlight
5. Smoke test on device against https://y666suf.com

## Verify
- Running round: smooth climb, no freeze/jump
- Empty round: shows planned crash value, not 1×

## When done
- Set `cross_device_status: done`
- `./scripts/sync-push.sh`
