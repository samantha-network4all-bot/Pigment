import AppKit

struct PickColorTool: Tool {
    let id: String = "pick-color"
    var cursor: NSCursor { NSCursor.crosshair }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        let ix = Int(point.x.rounded())
        let iy = Int(point.y.rounded())
        if let (r, g, b) = ctx.bitmap.pixelAt(x: ix, y: iy) {
            ctx.result = .pickColor(fg: ctx.button == .primary, r: r, g: g, b: b)
        }
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {}

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {}
}
