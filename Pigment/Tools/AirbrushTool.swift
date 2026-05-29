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
        let size = ctx.options.airbrushSize
        let radius: Double
        let count: Int
        switch size {
        case 1:
            radius = 4.0; count = 12
        case 2:
            radius = 8.0; count = 30
        case 3:
            radius = 12.0; count = 60
        default:
            radius = 4.0; count = 12
        }

        let ix = Int(center.x.rounded())
        let iy = Int(center.y.rounded())
        let r2 = radius * radius
        var painted = 0
        var attempts = 0
        let maxAttempts = count * 20

        while painted < count && attempts < maxAttempts {
            attempts += 1
            let dx = Int.random(in: Int(-radius - 1)...Int(radius + 1))
            let dy = Int.random(in: Int(-radius - 1)...Int(radius + 1))
            let fdx = Double(dx)
            let fdy = Double(dy)
            if fdx * fdx + fdy * fdy <= r2 {
                ctx.bitmap.setPixel(x: ix + dx, y: iy + dy, color: ctx.fgColor)
                painted += 1
            }
        }
    }
}
