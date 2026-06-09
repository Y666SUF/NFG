import Foundation

enum BlocksEngine {
    static let gridSize = 8

    private static let shapes: [[[Int]]] = [
        [[0, 0]],
        [[0, 0], [0, 1]],
        [[0, 0], [0, 1], [0, 2]],
        [[0, 0], [0, 1], [0, 2], [0, 3]],
        [[0, 0], [0, 1], [1, 0], [1, 1]],
        [[0, 0], [0, 1], [1, 0]],
        [[0, 0], [0, 1], [1, 1]],
        [[0, 0], [1, 0], [1, 1]],
        [[0, 1], [1, 0], [1, 1]],
        [[0, 0], [0, 1], [0, 2], [1, 1]],
        [[0, 0], [1, 0], [1, 1], [1, 2]],
        [[0, 2], [1, 0], [1, 1], [1, 2]],
        [[0, 0], [0, 1], [1, 1], [1, 2]],
        [[0, 1], [0, 2], [1, 0], [1, 1]],
        [[0, 0], [0, 1], [0, 2], [1, 0], [1, 2]],
    ]

    static let colors = ["#22d3ee", "#a78bfa", "#4ade80", "#fb7185", "#fbbf24", "#38bdf8"]

    struct Piece: Identifiable, Equatable {
        var id: String
        var shapeId: Int
        var rotation: Int
        var colorIndex: Int
    }

    struct BoardState: Equatable {
        var grid: [[Int?]]
        var tray: [Piece?]
        var level: Int
        var linesThisLevel: Int
        var linesTarget: Int
        var totalLines: Int
        var score: Int
        var gameOver: Bool
        var rngSeed: UInt64

        static func fresh(level: Int = 1) -> BoardState {
            var state = BoardState(
                grid: Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize),
                tray: [nil, nil, nil],
                level: max(1, level),
                linesThisLevel: 0,
                linesTarget: BlocksEngine.linesTarget(for: level),
                totalLines: 0,
                score: 0,
                gameOver: false,
                rngSeed: 0x4e464742_6c6b73
            )
            refillTray(&state)
            return state
        }
    }

    struct PlaceResult: Equatable {
        var clearedLines: Int
        var gameOver: Bool
    }

    static func linesTarget(for level: Int) -> Int {
        max(4, 6 + (max(1, level) - 1) * 2)
    }

    static func colorHex(index: Int) -> String {
        colors[index % colors.count]
    }

    static func pieceCells(_ piece: Piece) -> [(Int, Int)] {
        cells(shapeId: piece.shapeId, rotation: piece.rotation)
    }

    static func canPlace(_ piece: Piece, row: Int, col: Int, grid: [[Int?]]) -> Bool {
        for (dr, dc) in pieceCells(piece) {
            let r = row + dr
            let c = col + dc
            if r < 0 || c < 0 || r >= gridSize || c >= gridSize { return false }
            if grid[r][c] != nil { return false }
        }
        return true
    }

    static func hasAnyMove(_ state: BoardState) -> Bool {
        for piece in state.tray.compactMap({ $0 }) {
            for r in 0..<gridSize {
                for c in 0..<gridSize where canPlace(piece, row: r, col: c, grid: state.grid) {
                    return true
                }
            }
        }
        return false
    }

    @discardableResult
    static func placePiece(_ state: inout BoardState, piece: Piece, row: Int, col: Int) -> PlaceResult? {
        guard canPlace(piece, row: row, col: col, grid: state.grid) else { return nil }
        for (dr, dc) in pieceCells(piece) {
            state.grid[row + dr][col + dc] = piece.colorIndex
        }
        if let idx = state.tray.firstIndex(where: { $0?.id == piece.id }) {
            state.tray[idx] = nil
        }
        let cleared = clearLines(&state)
        state.linesThisLevel += cleared
        state.totalLines += cleared
        state.score += cleared * 10 * state.level
        refillTray(&state)
        if !hasAnyMove(state) { state.gameOver = true }
        return PlaceResult(clearedLines: cleared, gameOver: state.gameOver)
    }

    private static func cells(shapeId: Int, rotation: Int) -> [(Int, Int)] {
        let base = shapes[max(0, min(shapes.count - 1, shapeId))]
        var out = base.map { ($0[0], $0[1]) }
        let turns = ((rotation % 4) + 4) % 4
        for _ in 0..<turns {
            out = out.map { (r, c) in (c, -r) }
            let minR = out.map(\.0).min() ?? 0
            let minC = out.map(\.1).min() ?? 0
            out = out.map { (r, c) in (r - minR, c - minC) }
        }
        return out
    }

    private static func clearLines(_ state: inout BoardState) -> Int {
        var rows = Set<Int>()
        var cols = Set<Int>()
        var clearedCells = Set<String>()
        for r in 0..<gridSize where state.grid[r].allSatisfy({ $0 != nil }) {
            rows.insert(r)
        }
        for c in 0..<gridSize {
            var full = true
            for r in 0..<gridSize where state.grid[r][c] == nil {
                full = false
                break
            }
            if full { cols.insert(c) }
        }
        for r in rows {
            for c in 0..<gridSize {
                clearedCells.insert("\(r),\(c)")
                state.grid[r][c] = nil
            }
        }
        for c in cols {
            for r in 0..<gridSize {
                clearedCells.insert("\(r),\(c)")
                state.grid[r][c] = nil
            }
        }
        return rows.count + cols.count
    }

    private static func refillTray(_ state: inout BoardState) {
        guard state.tray.allSatisfy({ $0 == nil }) else { return }
        for i in 0..<3 {
            var piece = randomPiece(seed: &state.rngSeed)
            state.tray[i] = piece
        }
    }

    private static func randomPiece(seed: inout UInt64) -> Piece {
        var rng = seed
        let shapeId = Int(nextRandom(&rng) % UInt64(shapes.count))
        let rotation = Int(nextRandom(&rng) % 4)
        let colorIndex = Int(nextRandom(&rng) % UInt64(colors.count))
        seed = rng
        return Piece(
            id: UUID().uuidString,
            shapeId: shapeId,
            rotation: rotation,
            colorIndex: colorIndex
        )
    }

    private static func nextRandom(_ rng: inout UInt64) -> UInt64 {
        rng = rng &* 6_364_136_223_846_793_005 &+ 1
        return rng >> 32
    }
}
