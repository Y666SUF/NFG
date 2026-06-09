import SwiftUI

/// Compact last-five crash multipliers for the main game screen.
struct RecentCrashesStrip: View {
    let crashes: [Double]
    var inline: Bool = false
    /// Fit all five pills on one row (no horizontal scroll).
    var showAllFive: Bool = false

    private var display: [Double] {
        Array(crashes.suffix(5).reversed())
    }

    private var fiveSlots: [Double?] {
        let latest = display
        var slots: [Double?] = latest.map { Optional($0) }
        while slots.count < 5 { slots.append(nil) }
        return Array(slots.prefix(5))
    }

    var body: some View {
        Group {
            if inline {
                inlineBody
            } else {
                stackedBody
            }
        }
        .padding(.horizontal, inline ? 8 : 10)
        .padding(.vertical, inline ? 5 : 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(NFGTheme.panel.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(NFGTheme.border.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LAST 5 CRASHES")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(NFGTheme.muted.opacity(0.85))
            crashPillsRow
        }
    }

    private var inlineBody: some View {
        HStack(spacing: showAllFive ? 5 : 8) {
            Text("LAST 5")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(NFGTheme.muted.opacity(0.85))
                .fixedSize()
            crashPillsRow
        }
        .frame(maxWidth: showAllFive ? .infinity : nil, alignment: .leading)
    }

    @ViewBuilder
    private var crashPillsRow: some View {
        if showAllFive {
            HStack(spacing: 3) {
                ForEach(Array(fiveSlots.enumerated()), id: \.offset) { idx, mult in
                    Group {
                        if let mult {
                            crashPill(mult, isLatest: idx == 0, compact: true)
                        } else {
                            emptyPill(compact: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        } else if display.isEmpty {
            Text("—")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(NFGTheme.muted.opacity(0.5))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(display.enumerated()), id: \.offset) { idx, mult in
                        crashPill(mult, isLatest: idx == 0, compact: false)
                    }
                }
            }
        }
    }

    private func emptyPill(compact: Bool) -> some View {
        Text("—")
            .font(.system(size: compact ? 9 : 11, weight: .medium, design: .monospaced))
            .foregroundStyle(NFGTheme.muted.opacity(0.35))
            .padding(.horizontal, compact ? 5 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                Capsule()
                    .fill(NFGTheme.panel.opacity(0.5))
            )
    }

    private func crashPill(_ mult: Double, isLatest: Bool, compact: Bool = false) -> some View {
        Text(formatMult(mult))
            .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(pillText(mult))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, compact ? 5 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                Capsule()
                    .fill(pillBackground(mult).opacity(isLatest ? 1 : 0.82))
                    .overlay(
                        Capsule()
                            .stroke(isLatest ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
    }

    private func formatMult(_ v: Double) -> String {
        if v >= 10 { return String(format: "%.1f×", v) }
        return String(format: "%.2f×", v)
    }

    private func pillText(_ v: Double) -> Color {
        if v < 1.35 { return NFGTheme.danger }
        if v < 2.5 { return NFGTheme.accent2 }
        if v < 8 { return NFGTheme.gold }
        return Color(red: 0.75, green: 0.55, blue: 1)
    }

    private func pillBackground(_ v: Double) -> Color {
        pillText(v).opacity(0.18)
    }
}
