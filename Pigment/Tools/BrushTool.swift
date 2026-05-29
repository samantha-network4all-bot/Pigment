import AppKit

struct BrushTool: Tool {
    var id: String { "brush" }
    var cursor: NSCursor { NSCursor.crosshair }

    private static let patterns: [[(Int, Int)]] = [
        // 0: round 3×3
        [(-1,-1),(0,-1),(1,-1),(-1,0),(0,0),(1,0),(-1,1),(0,1),(1,1)],
        // 1: square 3×3
        [(-1,-1),(0,-1),(1,-1),(-1,0),(0,0),(1,0),(-1,1),(0,1),(1,1)],
        // 2: round 3×3 again
        [(-1,-1),(0,-1),(1,-1),(-1,0),(0,0),(1,0),(-1,1),(0,1),(1,1)],
        // 3: square 3×3 again
        [(-1,-1),(0,-1),(1,-1),(-1,0),(0,0),(1,0),(-1,1),(0,1),(1,1)],
        // 4: fwd-diag (\)
        [(0,0),(-1,-1),(1,1),(-2,-2),(2,2)],
        // 5: back-diag (/)
        [(0,0),(1,-1),(-1,1),(2,-2),(-2,2)],
        // 6: fwd-diag thick
        [(0,0),(-1,-1),(1,1),(-1,0),(0,-1),(0,1),(1,0)],
    ]

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        stamp(ctx: &ctx, at: point)
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        stamp(ctx: &ctx, at: point)
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        stamp(ctx: &ctx, at: point)
    }

    private func stamp(ctx: inout ToolContext, at point: NSPoint) {
        let size = ctx.options.brushSize
        // Mapping: size 1→0, 2→1, 3→4, 4→5
        let mapping = [0, 0, 1, 4, 5]
        let idx = size >= 1 && size <= 5 ? mapping[size] : ((size - 1) % 7)
        let index = max(0, min(idx, Self.patterns.count - 1))
        let offsets = Self.patterns[index]
        let cx = Int(point.x.rounded())
        let cy = Int(point.y.rounded())
        for (dx, dy) in offsets {
            ctx.bitmap.setPixel(x: cx + dx, y: cy + dy, color: ctx.fgColor)
        }
    }
}
