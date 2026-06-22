import SwiftUI

struct BlocksGameView: View {
    let busy: Bool
    let serverLevel: Int
    let sessionPoints: Int
    let offlinePendingPoints: Int
    let linesTarget: Int
    let rewardPreview: Int
    let sessionActive: Bool
    var embeddedInStage: Bool = false
    var onStart: () async -> Void
    var onLevelClear: () async -> Void
    var onGameOver: () async -> Void

    @State private var board = BlocksEngine.BoardState.fresh(level: 1)
    @State private var dragging: BlocksEngine.Piece?
    @State private var hoverCell: (row: Int, col: Int)?
    @State private var gridFrame: CGRect = .zero
    @State private var message = ""
    @State private var flashCells: Set<String> = []
    @State private var starting = false

    private let cellGap: CGFloat = 4
    /// Finger offset so the grid ghost sits above the thumb instead of under it.
    private let dragLift: CGFloat = 96

    private var displayPoints: Int { sessionPoints + offlinePendingPoints }

    var body: some View {
        ZStack {
            VStack(spacing: embeddedInStage ? 10 : 14) {
                if !embeddedInStage { hud }
                playfield
                trayView
                if !embeddedInStage { hintRow }
            }
            .padding(embeddedInStage ? 10 : 14)
            .coordinateSpace(name: "blocksPlay")
        }
        .background {
            if embeddedInStage {
                Color.clear
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NFGTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(NFGTheme.border.opacity(0.35), lineWidth: 1)
                    )
            }
        }
        .onAppear { restoreBoardIfNeeded() }
        .onChange(of: serverLevel) { _, lv in
            board.level = max(1, lv)
            board.linesTarget = BlocksEngine.linesTarget(for: board.level)
        }
        .onChange(of: board) { _, state in
            BlocksLocalStore.save(state, user: ArcadeOfflinePointsQueue.userKey())
        }
    }

    private var hud: some View {
        HStack(spacing: 10) {
            ArcadeSkillGameIcon(gameId: "nfg_blocks", size: 28)
            hudChip("Lv \(board.level)", icon: "square.grid.3x3.fill")
            hudChip("\(board.linesThisLevel)/\(board.linesTarget)", icon: "line.3.horizontal")
            hudChip("\(displayPoints.formatted()) pts", icon: "star.fill", tint: NFGTheme.gold)
            if sessionActive {
                Text("+\(rewardPreview.formatted())")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NFGTheme.accent2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(NFGTheme.accent2.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .font(.system(size: 11, weight: .semibold))
    }

    private func hudChip(_ text: String, icon: String, tint: Color = NFGTheme.text) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var playfield: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - cellGap * CGFloat(BlocksEngine.gridSize + 1)) / CGFloat(BlocksEngine.gridSize)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.12, blue: 0.18),
                                Color(red: 0.03, green: 0.06, blue: 0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: side, height: side)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.75, blue: 0.95).opacity(0.35),
                                        Color(red: 0.5, green: 0.35, blue: 0.95).opacity(0.2),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )

                ForEach(0..<BlocksEngine.gridSize, id: \.self) { row in
                    ForEach(0..<BlocksEngine.gridSize, id: \.self) { col in
                        let x = cellGap + CGFloat(col) * (cell + cellGap)
                        let y = cellGap + CGFloat(row) * (cell + cellGap)
                        blockCell(row: row, col: col, cell: cell)
                            .position(x: x + cell * 0.5, y: y + cell * 0.5)
                    }
                }

                if let dragging, let hover = hoverCell {
                    let valid = BlocksEngine.canPlace(dragging, row: hover.row, col: hover.col, grid: board.grid)
                    pieceOverlay(
                        piece: dragging,
                        cell: cell,
                        row: hover.row,
                        col: hover.col,
                        valid: valid
                    )
                }
            }
            .frame(width: side, height: side)
            .background(
                GeometryReader { inner in
                    Color.clear
                        .onAppear { gridFrame = inner.frame(in: .named("blocksPlay")) }
                        .onChange(of: inner.size) { _, _ in
                            gridFrame = inner.frame(in: .named("blocksPlay"))
                        }
                }
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("blocksPlay"))
                    .onChanged { value in
                        guard dragging != nil else { return }
                        updateDrag(at: value.location, cellSize: cell)
                    }
                    .onEnded { value in
                        finishDrag(at: placementPoint(for: value.location), cellSize: cell)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 340)
    }

    private var trayView: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { idx in
                if let piece = board.tray[idx] {
                    traySlot(piece: piece, index: idx)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NFGTheme.border.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .frame(width: 84, height: 84)
                }
            }
        }
        .padding(.top, 2)
    }

    private var hintRow: some View {
        VStack(spacing: 4) {
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent2)
                    .multilineTextAlignment(.center)
            }
            Text(sessionActive ? "Drag onto the grid — piece previews above your finger" : "Pick up a block to start")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
            if offlinePendingPoints > 0 {
                Text("\(offlinePendingPoints.formatted()) pts saved offline — will sync when online")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NFGTheme.gold.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func traySlot(piece: BlocksEngine.Piece, index: Int) -> some View {
        let selected = dragging?.id == piece.id
        return ZStack {
            miniPiece(piece: piece, dot: 11)
                .opacity(selected ? 0.22 : 1)
                .scaleEffect(selected ? 0.88 : 1)
        }
        .frame(width: 84, height: 84)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? NFGTheme.accent.opacity(0.18) : Color.black.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? NFGTheme.accent : NFGTheme.border.opacity(0.3), lineWidth: selected ? 2 : 1)
        )
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("blocksPlay"))
                .onChanged { value in
                    guard !busy, !starting else { return }
                    if dragging == nil {
                        dragging = piece
                        Task { await ensureSessionStarted() }
                    }
                    let cell = gridFrame == .zero ? 0 : cellSize(in: gridFrame)
                    if cell > 0 {
                        updateDrag(at: value.location, cellSize: cell)
                    }
                }
                .onEnded { value in
                    let cell = cellSize(in: gridFrame)
                    finishDrag(at: placementPoint(for: value.location), cellSize: cell)
                }
        )
    }

    @ViewBuilder
    private func blockCell(row: Int, col: Int, cell: CGFloat) -> some View {
        let key = "\(row),\(col)"
        let filled = board.grid[row][col] != nil
        let flashing = flashCells.contains(key)
        let hint = ghostOccupies(row: row, col: col)

        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(cellBackground(row: row, col: col, hint: hint))
                .frame(width: cell, height: cell)

            if filled, let idx = board.grid[row][col] {
                filledBlock(colorIndex: idx, size: cell)
            }
        }
        .scaleEffect(flashing ? 1.06 : 1)
        .opacity(flashing ? 0.35 : 1)
        .animation(.easeOut(duration: 0.22), value: flashing)
    }

    private func filledBlock(colorIndex: Int, size: CGFloat) -> some View {
        let base = BlocksColor.hex(index: colorIndex)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [base.opacity(0.95), base.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size - 2, height: size - 2)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    .padding(2)
            )
            .shadow(color: base.opacity(0.45), radius: 3, y: 2)
    }

    @ViewBuilder
    private func pieceOverlay(
        piece: BlocksEngine.Piece,
        cell: CGFloat,
        row: Int,
        col: Int,
        valid: Bool
    ) -> some View {
        let color = BlocksColor.hex(index: piece.colorIndex)
        let fillAlpha = valid ? 0.88 : 0.42
        let strokeColor = valid ? Color.white.opacity(0.92) : Color.red.opacity(0.95)
        ForEach(Array(BlocksEngine.pieceCells(piece).enumerated()), id: \.offset) { _, cellPos in
            let r = row + cellPos.0
            let c = col + cellPos.1
            let x = cellGap + CGFloat(c) * (cell + cellGap) + cell * 0.5
            let y = cellGap + CGFloat(r) * (cell + cellGap) + cell * 0.5
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(valid ? color.opacity(fillAlpha) : Color.red.opacity(fillAlpha))
                .frame(width: cell - 2, height: cell - 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(strokeColor, lineWidth: valid ? 2 : 2.5)
                        .padding(1)
                )
                .shadow(color: valid ? color.opacity(0.55) : Color.red.opacity(0.45), radius: 6, y: 2)
                .position(x: x, y: y)
        }
    }

    @ViewBuilder
    private func miniPiece(piece: BlocksEngine.Piece, dot: CGFloat) -> some View {
        let cells = BlocksEngine.pieceCells(piece)
        let maxR = cells.map(\.0).max() ?? 0
        let maxC = cells.map(\.1).max() ?? 0
        let color = BlocksColor.hex(index: piece.colorIndex)
        VStack(spacing: 3) {
            ForEach(0...maxR, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0...maxC, id: \.self) { c in
                        let on = cells.contains(where: { $0.0 == r && $0.1 == c })
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(on ? color : Color.clear)
                            .frame(width: dot, height: dot)
                            .shadow(color: on ? color.opacity(0.35) : .clear, radius: 2, y: 1)
                    }
                }
            }
        }
    }

    private func ghostOccupies(row: Int, col: Int) -> Bool {
        guard let dragging, let hover = hoverCell,
              BlocksEngine.canPlace(dragging, row: hover.row, col: hover.col, grid: board.grid) else {
            return false
        }
        return BlocksEngine.pieceCells(dragging).contains { dr, dc in
            hover.row + dr == row && hover.col + dc == col
        }
    }

    private func cellBackground(row: Int, col: Int, hint: Bool) -> Color {
        if hint { return NFGTheme.accent.opacity(0.22) }
        if board.grid[row][col] != nil { return .clear }
        return Color.white.opacity(0.04)
    }

    private func placementPoint(for finger: CGPoint) -> CGPoint {
        liftedPoint(finger)
    }

    private func updateDrag(at finger: CGPoint, cellSize: CGFloat) {
        let aim = placementPoint(for: finger)
        hoverCell = cellAt(point: aim, cellSize: cellSize)
    }

    private func liftedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y - dragLift)
    }

    private func cellSize(in frame: CGRect) -> CGFloat {
        let side = min(frame.width, frame.height)
        return (side - cellGap * CGFloat(BlocksEngine.gridSize + 1)) / CGFloat(BlocksEngine.gridSize)
    }

    private func cellAt(point: CGPoint, cellSize: CGFloat) -> (row: Int, col: Int)? {
        guard gridFrame != .zero else { return nil }
        let local = CGPoint(x: point.x - gridFrame.minX, y: point.y - gridFrame.minY)
        let stride = cellSize + cellGap
        let col = Int((local.x - cellGap) / stride)
        let row = Int((local.y - cellGap) / stride)
        guard row >= 0, col >= 0, row < BlocksEngine.gridSize, col < BlocksEngine.gridSize else { return nil }
        return (row, col)
    }

    private func restoreBoardIfNeeded() {
        if sessionActive,
           let saved = BlocksLocalStore.load(user: ArcadeOfflinePointsQueue.userKey(), level: serverLevel) {
            board = saved
            board.linesTarget = linesTarget
        } else if sessionActive {
            board = BlocksEngine.BoardState.fresh(level: serverLevel)
            board.linesTarget = linesTarget
        }
    }

    private func ensureSessionStarted() async {
        guard !sessionActive, !starting else { return }
        starting = true
        defer { starting = false }
        await onStart()
        board = BlocksEngine.BoardState.fresh(level: serverLevel)
        board.linesTarget = linesTarget
    }

    private func finishDrag(at point: CGPoint, cellSize: CGFloat) {
        defer {
            dragging = nil
            hoverCell = nil
        }
        guard let dragging, sessionActive, !busy else { return }
        guard let hover = cellAt(point: point, cellSize: cellSize),
              let result = BlocksEngine.placePiece(&board, piece: dragging, row: hover.row, col: hover.col) else {
            return
        }
        if result.clearedLines > 0 {
            message = "+\(result.clearedLines) line\(result.clearedLines == 1 ? "" : "s")!"
            triggerLineFlash(cleared: result.clearedLines)
        }
        Task { await afterPlacement(result) }
    }

    private func triggerLineFlash(cleared: Int) {
        var keys = Set<String>()
        for r in 0..<BlocksEngine.gridSize {
            for c in 0..<BlocksEngine.gridSize {
                keys.insert("\(r),\(c)")
            }
        }
        flashCells = keys
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            flashCells.removeAll()
        }
    }

    private func afterPlacement(_ result: BlocksEngine.PlaceResult) async {
        if board.linesThisLevel >= board.linesTarget {
            await onLevelClear()
            board.linesThisLevel = 0
            board.level = max(board.level, serverLevel)
            board.linesTarget = linesTarget
            message = "Level cleared! +\(rewardPreview.formatted()) pts"
        }
        if result.gameOver || board.gameOver {
            await onGameOver()
            BlocksLocalStore.clear(user: ArcadeOfflinePointsQueue.userKey())
            board = BlocksEngine.BoardState.fresh(level: serverLevel)
            message = "Board full — session ended."
        }
    }
}

private enum BlocksColor {
    static func hex(index: Int) -> Color {
        Color(hex: BlocksEngine.colorHex(index: index)) ?? NFGTheme.accent
    }
}

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = UInt64(s, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
