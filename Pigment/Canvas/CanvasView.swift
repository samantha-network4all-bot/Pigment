import AppKit

protocol CanvasMouseHandler: AnyObject {
    func handleMouseEvent(kind: CanvasMouseEventKind, point: (Int, Int))
}

enum CanvasMouseEventKind {
    case down, dragged, up
}

final class CanvasView: NSView {

    var bitmap: Bitmap? {
        didSet {
            needsDisplay = true
        }
    }

    weak var mouseHandler: CanvasMouseHandler?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let bitmap = bitmap else { return }

        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.interpolationQuality = .none

        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let (r, g, b) = bitmap[x, y]
                NSColor(
                    red: CGFloat(r) / 255.0,
                    green: CGFloat(g) / 255.0,
                    blue: CGFloat(b) / 255.0,
                    alpha: 1.0
                ).setFill()
                let rect = NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1)
                rect.fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convertPointToBitmap(event)
        mouseHandler?.handleMouseEvent(kind: .down, point: pt)
        nextResponder?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convertPointToBitmap(event)
        mouseHandler?.handleMouseEvent(kind: .dragged, point: pt)
        nextResponder?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convertPointToBitmap(event)
        mouseHandler?.handleMouseEvent(kind: .up, point: pt)
        nextResponder?.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let pt = convertPointToBitmap(event)
        mouseHandler?.handleMouseEvent(kind: .down, point: pt)
        nextResponder?.rightMouseDown(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        let pt = convertPointToBitmap(event)
        mouseHandler?.handleMouseEvent(kind: .dragged, point: pt)
        nextResponder?.rightMouseDragged(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        let pt = convertPointToBitmap(event)
        mouseHandler?.handleMouseEvent(kind: .up, point: pt)
        nextResponder?.rightMouseUp(with: event)
    }

    // TODO: zoom is hardcoded at 100 for now; replace with zoom controller integration
    private var zoomFactor: CGFloat { 1.0 }

    private func convertPointToBitmap(_ event: NSEvent) -> (Int, Int) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let scrollOffset = enclosingScrollView?.contentView.bounds.origin ?? .zero
        let bitmapX = Int((viewPoint.x + scrollOffset.x) / zoomFactor)
        let bitmapY = Int((viewPoint.y + scrollOffset.y) / zoomFactor)
        return (bitmapX, bitmapY)
    }
}
