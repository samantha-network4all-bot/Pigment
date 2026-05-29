import AppKit

final class RootView: NSView {

    private let toolboxPlaceholder: NSView
    private let toolOptionsPlaceholder: NSView
    private let canvasPlaceholder: NSView
    private let colorBoxPlaceholder: NSView
    private let statusBarView: StatusBarView

    let canvasController: CanvasController

    override init(frame frameRect: NSRect) {
        toolboxPlaceholder = NSView()
        toolOptionsPlaceholder = NSView()
        canvasPlaceholder = NSView()
        colorBoxPlaceholder = NSView()
        statusBarView = StatusBarView(frame: .zero)

        canvasController = CanvasController()

        super.init(frame: frameRect)

        toolboxPlaceholder.wantsLayer = true
        toolboxPlaceholder.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        toolOptionsPlaceholder.wantsLayer = true
        toolOptionsPlaceholder.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        canvasPlaceholder.wantsLayer = true
        canvasPlaceholder.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        colorBoxPlaceholder.wantsLayer = true
        colorBoxPlaceholder.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        statusBarView.wantsLayer = true
        statusBarView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        addSubview(toolboxPlaceholder)
        addSubview(toolOptionsPlaceholder)
        addSubview(canvasPlaceholder)
        addSubview(colorBoxPlaceholder)
        addSubview(statusBarView)

        layoutSubviews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func layoutSubviews() {
        let bounds = self.bounds
        let toolboxW = Metrics.toolboxWidth
        let optionsH = Metrics.toolOptionsHeight
        let colorH = Metrics.colorBoxHeight
        let statusH = Metrics.statusBarHeight

        // Status bar at bottom
        statusBarView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: statusH)

        // Color box above status bar
        colorBoxPlaceholder.frame = NSRect(x: 0, y: statusH, width: bounds.width, height: colorH)

        // Toolbox on the left
        let leftColumnY = statusH + colorH
        let leftColumnH = bounds.height - leftColumnY
        toolboxPlaceholder.frame = NSRect(x: 0, y: leftColumnY, width: toolboxW, height: leftColumnH - optionsH)

        // Tool-options strip under toolbox
        toolOptionsPlaceholder.frame = NSRect(x: 0, y: leftColumnY + leftColumnH - optionsH, width: toolboxW, height: optionsH)

        // Canvas area fills the center
        let canvasX = toolboxW
        canvasPlaceholder.frame = NSRect(x: canvasX, y: leftColumnY, width: bounds.width - canvasX, height: leftColumnH)

        // Add the canvas controller's view as subview of canvas placeholder
        let cc = canvasController
        if cc.view.superview != canvasPlaceholder {
            cc.view.frame = canvasPlaceholder.bounds
            cc.view.autoresizingMask = [.width, .height]
            canvasPlaceholder.addSubview(cc.view)
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutSubviews()
    }

    override var isFlipped: Bool { false }
}
