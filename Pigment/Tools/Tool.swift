import AppKit

protocol Tool {
    var id: String { get }
    var cursor: NSCursor { get }
    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint)
    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint)
    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint)
}
