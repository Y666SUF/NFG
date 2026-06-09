import SwiftUI

struct BlocksGameView: View {
    let busy: Bool
    let serverLevel: Int
    let sessionPoints: Int
    let linesTarget: Int
    let rewardPreview: Int
    let sessionActive: Bool
    var onStart: () async -> Void
    var onLevelClear: () async -> Void
    var onGameOver: () async -> Void

    @State private var board = BlocksEngine.BoardState.fresh(level: 1)
    @State private var dragging: BlocksEngine.Piece?
    @State private var dragOffset: CGSize = .zero
    @State private var hoverCell: (row: Int, col: Int)?
    @State private var message = ""

    private let cellGap: CGFloat = 3

    var body: some View {
        VStack(spacing: 12) {
            hud
            gridView
            trayView
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                ArcadePrimaryButton(
                    title: sessionActive ? "Restart" : "Start",
                    icon: "play.fill",
                    tint: .cyan,
                    disabled: busy
                ) {
                    Task { await startGame() }
                }
            }
        }
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            if sessionActive {
                board = BlocksEngine.BoardState.fresh(level: serverLevel)
                board.linesTarget = linesTarget
            }
        }
        .onChange(of: serverLevel) { _, lv in
            board.level = max(1, lv)
            board.linesTarget = BlocksEngine.linesTarget(for: board.level)
        }
    }

    private var hud: some View {
        HStack(spacing: 12) {
            Label("Lv \(board.level)", systemImage: "number")
            Label("\(board.linesThisLevel)/\(board.linesTarget) lines", systemImage: "line.3.horizontal")
            Label("\(sessionPoints.formatted()) pts", systemImage: "star.fill")
            if sessionActive {
                Text("~\(rewardPreview.formatted())/lvl")
                    .foregroundStyle(NFGTheme.gold)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(NFGTheme.text)
    }

    private var gridView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - cellGap * CGFloat(BlocksEngine.gridSize + 1)) / CGFloat(BlocksEngine.gridSize)
            ZStack(alignment: .topLeading) {
                ForEach(0..<BlocksEngine.gridSize, id: \.self) { row in
                    ForEach(0..<BlocksEngine.gridSize, id: \.self) { col in
                        let x = cellGap + CGFloat(col) * (cell + cellGap)
                        let y = cellGap + CGFloat(row) * (cell + cellGap)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cellColor(row: row, col: col))
                            .frame(width: cell, height: cell)
                            .position(x: x + cell * 0.5, y: y + cell * 0.5)
                    }
                }
                if let dragging, let hover = hoverCell, BlocksEngine.canPlace(dragging, row: hover.row, col: hover.col, grid: board.grid) {
                    pieceOverlay(piece: dragging, cell: cell, row: hover.row, col: hover.col, alpha: 0.55)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard let dragging else { return }
                        dragOffset = value.translation
                        hoverCell = cellAt(point: value.location, cellSize: cell)
                    }
                    .onEnded { value in
                        guard let dragging else { return }
                        defer {
                            self.dragging = nil
                            dragOffset = .zero
                            hoverCell = nil
                        }
                        guard sessionActive, !busy else { return }
                        if let hover = cellAt(point: value.location, cellSize: cell),
                           let result = BlocksEngine.placePiece(&board, piece: dragging, row: hover.row, col: hover.col) {
                            if result.clearedLines > 0 {
                                message = "+\(result.clearedLines) line\(result.clearedLines == 1 ? "" : "s")!"
                            }
                            Task { await afterPlacement(result) }
                        }
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
    }

    private var trayView: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { idx in
                if let piece = board.tray[idx] {
                    pieceTrayTile(piece: piece)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(NFGTheme.border.opacity(0.4), lineWidth: 1)
                        .frame(width: 72, height: 72)
                }
            }
        }
    }

    private func pieceTrayTile(piece: BlocksEngine.Piece) -> some View {
        let selected = dragging?.id == piece.id
        return ZStack {
            miniPiece(piece: piece, dot: 10)
                .padding(8)
        }
        .frame(width: 72, height: 72)
        .background(selected ? NFGTheme.accent.opacity(0.2) : NFGTheme.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? NFGTheme.accent : NFGTheme.border.opacity(0.35)))
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in
                    guard sessionActive, !busy else { return }
                    dragging = piece
                }
                .onEnded { _ in
                    if dragging?.id == piece.id, hoverCell == nil {
                        dragging = nil
                    }
                }
        )
    }

    @ViewBuilder
    private func miniPiece(piece: BlocksEngine.Piece, dot: CGFloat) -> some View {
        let cells = BlocksEngine.pieceCells(piece)
        let maxR = cells.map(\.0).max() ?? 0
        let maxC = cells.map(\.1).max() ?? 0
        let color = Color(hex: BlocksEngine.colorHex(index: piece.colorIndex)) ?? NFGTheme.accent
        VStack(spacing: 2) {
            ForEach(0...maxR, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0...maxC, id: \.self) { c in
                        let on = cells.contains(where: { $0.0 == r && $0.1 == c })
                        RoundedRectangle(cornerRadius: 2)
                            .fill(on ? color : Color.clear)
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pieceOverlay(piece: BlocksEngine.Piece, cell: CGFloat, row: Int, col: Int, alpha: Double) -> some View {
        let color = Color(hex: BlocksEngine.colorHex(index: piece.colorIndex)) ?? NFGTheme.accent
        ForEach(Array(BlocksEngine.pieceCells(piece).enumerated()), id: \.offset) { _, cellPos in
            let r = row + cellPos.0
            let c = col + cellPos.1
            let x = cellGap + CGFloat(c) * (cell + cellGap) + cell * 0.5
            let y = cellGap + CGFloat(r) * (cell + cellGap) + cell * 0.5
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(alpha))
                .frame(width: cell, height: cell)
                .position(x: x, y: y)
        }
    }

    private func cellColor(row: Int, col: Int) -> Color {
        if let idx = board.grid[row][col], let hex = Color(hex: BlocksEngine.colorHex(index: idx)) {
            return hex
        }
        if let hover = hoverCell, hover.row == row, hover.col == col,
           let dragging, BlocksEngine.canPlace(dragging, row: row, col: col, grid: board.grid) {
            return NFGTheme.accent.opacity(0.18)
        }
        return NFGTheme.background.opacity(0.85)
    }

    private func cellAt(point: CGPoint, cellSize: CGFloat) -> (row: Int, col: Int)? {
        let stride = cellSize + cellGap
        let col = Int((point.x - cellGap) / stride)
        let row = Int((point.y - cellGap) / stride)
        guard row >= 0, col >= 0, row < BlocksEngine.gridSize, col < BlocksEngine.gridSize else { return nil }
        return (row, col)
    }

    private func startGame() async {
        message = ""
        await onStart()
        board = BlocksEngine.BoardState.fresh(level: serverLevel)
        board.linesTarget = linesTarget
        dragging = nil
    }

    private func afterPlacement(_ result: BlocksEngine.PlaceResult) async {
        if board.linesThisLevel >= board.linesTarget {
            await onLevelClear()
            board.linesThisLevel = 0
            board.level = max(board.level, serverLevel)
            board.linesTarget = linesTarget
            message = "Level cleared!"
        }
        if result.gameOver || board.gameOver {
            await onGameOver()
            board = BlocksEngine.BoardState.fresh(level: serverLevel)
            message = "Board full — session ended."
        }
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
