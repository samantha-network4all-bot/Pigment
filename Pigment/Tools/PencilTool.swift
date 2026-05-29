import AppKit

struct PencilTool: Tool {
    var id: String { "pencil" }
    var cursor: NSCursor { NSCursor.crosshair }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        ctx.bitmap.setPixel(x: px, y: py, color: ctx.fgColor)
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        ctx.bitmap.setPixel(x: px, y: py, color: ctx.fgColor)
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        let px = Int(point.x.rounded())
        let py = Int(point.y.rounded())
        ctx.bitmap.setPixel(x: px, y: py, color: ctx.fgColor)
    }
}
