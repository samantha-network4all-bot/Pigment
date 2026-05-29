import AppKit

final class PigmentWindow: NSWindow {

    private lazy var rootView: RootView = {
        let v = RootView(frame: NSRect(origin: .zero, size: Metrics.defaultWindowSize))
        return v
    }()

    var canvasController: CanvasController {
        return rootView.canvasController
    }

    var toolController: ToolController? {
        didSet {
            canvasController.toolController = toolController
        }
    }

    var colorState: ColorState? {
        didSet {
            canvasController.colorState = colorState
        }
    }

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Metrics.defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.contentView = rootView
        self.title = "untitled - Pigment"
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 400, height: 300)
    }
}
