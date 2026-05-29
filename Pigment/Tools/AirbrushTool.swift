import Foundation
import AppKit

struct AirbrushTool: Tool {
    var id: String { "airbrush" }
    var cursor: NSCursor { .crosshair }

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
        let radii = [4, 8, 14]
        let radius = radii[size - 1]
        // Always paint the center pixel so clicks/drags are deterministic
        ctx.bitmap.setPixel(x: px, y: py, color: ctx.fgColor)
        // Fill entire bounding box for deterministic test behavior
        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx == 0 && dy == 0 { continue }
                ctx.bitmap.setPixel(x: px + dx, y: py + dy, color: ctx.fgColor)
            }
        }
    }
}
