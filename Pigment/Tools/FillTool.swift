import Foundation
import AppKit

struct FillTool: Tool {
    var id: String { "fill" }
    var cursor: NSCursor { NSCursor.crosshair }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        // no-op: fill commits on pointerUp
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        // no-op
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        let ix = Int(point.x.rounded())
        let iy = Int(point.y.rounded())
        guard let existing = ctx.bitmap.pixelAt(x: ix, y: iy) else { return }
        let fillColor = ctx.fgColor
        guard existing.r != fillColor.0 || existing.g != fillColor.1 || existing.b != fillColor.2 else { return }
        ctx.bitmap.floodFill(x: ix, y: iy,
                             targetColor: (existing.r, existing.g, existing.b),
                             fillColor: fillColor)
    }
}
