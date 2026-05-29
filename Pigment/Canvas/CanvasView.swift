import AppKit

final class CanvasView: NSView {

    var bitmap: Bitmap? {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let bitmap = bitmap else { return }

        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.interpolationQuality = .none

        let pixelW = CGFloat(bitmap.width)
        let pixelH = CGFloat(bitmap.height)

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
        // Stub - tools will be implemented later
        nextResponder?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        // Stub - tools will be implemented later
        nextResponder?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        // Stub - tools will be implemented later
        nextResponder?.mouseUp(with: event)
    }
}
