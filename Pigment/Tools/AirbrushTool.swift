import Foundation
import AppKit

struct AirbrushTool: Tool {
    var id: String { "airbrush" }
    var cursor: NSCursor { NSCursor.crosshair }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        spray(ctx: &ctx, center: point)
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        spray(ctx: &ctx, center: point)
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        spray(ctx: &ctx, center: point)
    }

    private func spray(ctx: inout ToolContext, center: NSPoint) {
        let px = Int(center.x.rounded())
        let py = Int(center.y.rounded())
        let size = max(1, min(ctx.options.airbrushSize, 3))
        let radius = [4, 8, 14][size - 1]
        let count = radius * radius / 2
        for _ in 0..<count {
            let dx = Int.random(in: -radius...radius)
            let dy = Int.random(in: -radius...radius)
            if dx * dx + dy * dy > radius * radius { continue }
            ctx.bitmap.setPixel(x: px + dx, y: py + dy, color: ctx.fgColor)
        }
    }
}
