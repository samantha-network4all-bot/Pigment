import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let appController = AppController()
    private let windowController = WindowController()
    private let menuController = MenuController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        MenuBuilder.build()
        _ = menuController // instantiate to register routes
        appController.startTestAPIIfNeeded()
        windowController.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
