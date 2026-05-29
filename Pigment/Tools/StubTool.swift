import AppKit

struct StubTool: Tool {
    let toolId: String
    var id: String { toolId }
    var cursor: NSCursor { NSCursor.arrow }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {}
    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {}
    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {}
}
