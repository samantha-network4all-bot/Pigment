import AppKit

struct EraserTool: Tool {
    var id: String { "eraser" }

    var cursor: NSCursor {
        NSCursor.crosshair
    }

    func pointerDown(_ ctx: inout ToolContext, _ point: NSPoint) {
        stampSquare(ctx: &ctx, x: Int(point.x.rounded()), y: Int(point.y.rounded()))
    }

    func pointerDragged(_ ctx: inout ToolContext, _ point: NSPoint) {
        stampSquare(ctx: &ctx, x: Int(point.x.rounded()), y: Int(point.y.rounded()))
    }

    func pointerUp(_ ctx: inout ToolContext, _ point: NSPoint) {
        stampSquare(ctx: &ctx, x: Int(point.x.rounded()), y: Int(point.y.rounded()))
    }

    private func stampSquare(ctx: inout ToolContext, x: Int, y: Int) {
        let size = ctx.options.eraserSize
        let half = size / 2
        let xStart = x - half
        let yStart = y - half
        let xEnd = xStart + size
        let yEnd = yStart + size

        let clampedXStart = max(0, xStart)
        let clampedYStart = max(0, yStart)
        let clampedXEnd = min(ctx.bitmap.width, xEnd)
        let clampedYEnd = min(ctx.bitmap.height, yEnd)

        for py in clampedYStart..<clampedYEnd {
            for px in clampedXStart..<clampedXEnd {
                ctx.bitmap.setPixel(x: px, y: py, color: ctx.bgColor)
            }
        }
    }
}
