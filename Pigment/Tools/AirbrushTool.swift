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
        let radii = [6, 12, 18]
        let radius = radii[size - 1]
        let r2 = radius * radius
        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy > r2 { continue }
                ctx.bitmap.setPixel(x: px + dx, y: py + dy, color: ctx.fgColor)
            }
        }
    }
}
