#!/usr/bin/env swift
// Logic checks for SnakeJumpEngine — run: swift ios/scripts/test-jump-engine.swift
// (from repo root, or adjust path to SnakeJumpEngine.swift)

import Foundation

// Minimal inline copies of logic under test (keeps script standalone without Xcode target).

struct JumpPlatformStub {
    var kind: String
    var x: Double
    var y: Double
    var width: Double
}

func clampFingerScreenX(screenX: Double, viewWidth: Double, playerRadius: Double = 22) -> Double {
    let w = max(280, viewWidth)
    let halfW = max(60, w * 0.5 - playerRadius)
    let maxScreenX = halfW + w * 0.5
    let minScreenX = w * 0.5 - halfW
    return min(maxScreenX, max(minScreenX, screenX))
}

func screenX(fromWorldX worldX: Double, viewWidth: Double) -> Double {
    worldX + max(viewWidth, 280) * 0.5
}

func worldX(fromScreenX screenX: Double, viewWidth: Double) -> Double {
    screenX - max(viewWidth, 280) * 0.5
}

var failures = 0

func check(_ name: String, _ condition: Bool) {
    if condition {
        print("  ✓ \(name)")
    } else {
        print("  ✗ \(name)")
        failures += 1
    }
}

print("SnakeJump engine logic checks")

let viewW: Double = 360

check("center maps to world 0", abs(worldX(fromScreenX: 180, viewWidth: viewW)) < 0.01)
check("left edge clamped", clampFingerScreenX(screenX: 0, viewWidth: viewW) > 20)
check("right edge clamped", clampFingerScreenX(screenX: 999, viewWidth: viewW) < viewW - 20)
check("mid finger unchanged", abs(clampFingerScreenX(screenX: 200, viewWidth: viewW) - 200) < 0.01)

let left = clampFingerScreenX(screenX: 30, viewWidth: viewW)
let right = clampFingerScreenX(screenX: 330, viewWidth: viewW)
check("left/right symmetric", abs((left - 180) + (right - 180)) < 2)

// Simulated landing band
func wouldLand(playerX: Double, playerY: Double, plat: JumpPlatformStub, velocityY: Double) -> Bool {
    guard velocityY <= 0 else { return false }
    let footY = playerY - 22
    let half = plat.width * 0.5
    let onX = playerX >= plat.x - half + 6 && playerX <= plat.x + half - 6
    let distY = abs(footY - plat.y)
    return onX && distY < 20
}

let plat = JumpPlatformStub(kind: "solid", x: 0, y: 100, width: 120)
check("lands when over platform", wouldLand(playerX: 0, playerY: 122, plat: plat, velocityY: -50))
check("no land when off platform X", !wouldLand(playerX: 80, playerY: 122, plat: plat, velocityY: -50))
check("no land while rising", !wouldLand(playerX: 0, playerY: 122, plat: plat, velocityY: 200))

// Camera follow
var cam = 0.0
let playerY = 500.0
let viewH = 600.0
let targetCam = playerY - viewH * 0.55
let blend = min(1.0, 1 / 60 * 14.0)
cam += (targetCam - cam) * blend
check("camera moves toward target", cam > 0 && cam < targetCam)

print("")
if failures == 0 {
    print("All \(6 + 3 + 1) checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
