import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let appController = AppController()
    private let windowController = WindowController()
    private let menuController = MenuController()
    private let toolController = ToolController()
    private let colorState = ColorState()
    private var colorController: ColorController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        MenuBuilder.build()
        _ = menuController.view // force viewDidLoad to register routes
        appController.startTestAPIIfNeeded()

        // Instantiate ColorController so its routes are registered before tests call /color/set
        let cc = ColorController(colorState: colorState)
        _ = cc.view // force viewDidLoad to register routes
        colorController = cc

        // Force-load tool controller so its viewDidLoad fires and registers routes
        _ = toolController.view
        windowController.showWindow(nil)

        // Wire tool controller and color state into the window's canvas
        if let pigmentWindow = windowController.window as? PigmentWindow {
            pigmentWindow.toolController = toolController
            pigmentWindow.colorState = colorState
        }
    }

    @objc func undo(_ sender: Any?) {
        guard let win = (NSApp.keyWindow ?? NSApp.windows.first) as? PigmentWindow else { return }
        win.canvasController.performUndo()
    }

    @objc func redo(_ sender: Any?) {
        guard let win = (NSApp.keyWindow ?? NSApp.windows.first) as? PigmentWindow else { return }
        win.canvasController.performRedo()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
