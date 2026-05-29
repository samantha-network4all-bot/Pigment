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
        let ix = Int(center.x.rounded())
        let iy = Int(center.y.rounded())
        let size = ctx.options.airbrushSize

        let radius: Int
        let count: Int
        switch size {
        case 1:
            radius = 4
            count = 12
        case 2:
            radius = 8
            count = 30
        case 3:
            radius = 12
            count = 60
        default:
            radius = 4
            count = 12
        }

        var sprayed = 0
        let maxAttempts = count * 10 // safety bound
        var attempts = 0

        while sprayed < count && attempts < maxAttempts {
            attempts += 1
            let dx = Int.random(in: -radius...radius)
            let dy = Int.random(in: -radius...radius)
            if dx * dx + dy * dy <= radius * radius {
                ctx.bitmap.setPixel(x: ix + dx, y: iy + dy, color: ctx.fgColor)
                sprayed += 1
            }
        }
    }
}
