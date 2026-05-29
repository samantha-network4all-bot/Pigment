import AppKit

final class PigmentWindow: NSWindow {

    init() {
        let defaultContentSize = NSSize(width: 1000, height: 720)
        super.init(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = "untitled - Pigment"
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 400, height: 300)
    }
}
