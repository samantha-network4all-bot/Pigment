import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let appController = AppController()
    private let windowController = WindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appController.startTestAPIIfNeeded()
        windowController.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
