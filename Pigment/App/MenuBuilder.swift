import AppKit

@objc final class MenuBuilder: NSObject {

    @objc static func build() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Pigment")
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About Pigment", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Pigment", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // File
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New", action: #selector(noop), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open\u{2026}", action: #selector(noop), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Save", action: #selector(noop), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As\u{2026}", action: #selector(noop), keyEquivalent: "S")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Page Setup\u{2026}", action: #selector(noop), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Print\u{2026}", action: #selector(noop), keyEquivalent: "p")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        // Edit
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        let undoItem = NSMenuItem(title: "Undo", action: #selector(AppDelegate.undo(_:)), keyEquivalent: "z")
        undoItem.target = NSApp.delegate
        editMenu.addItem(undoItem)
        let redoItem = NSMenuItem(title: "Redo", action: #selector(AppDelegate.redo(_:)), keyEquivalent: "Z")
        redoItem.target = NSApp.delegate
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(noop), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(noop), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(noop), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Clear Selection", action: #selector(noop), keyEquivalent: String(format: "%c", 0x7f))
        editMenu.addItem(withTitle: "Select All", action: #selector(noop), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Copy To\u{2026}", action: #selector(noop), keyEquivalent: "")
        editMenu.addItem(withTitle: "Paste From\u{2026}", action: #selector(noop), keyEquivalent: "")

        // View
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let zoomMenuItem = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        let zoomMenu = NSMenu(title: "Zoom")
        zoomMenuItem.submenu = zoomMenu
        viewMenu.addItem(zoomMenuItem)

        zoomMenu.addItem(withTitle: "Normal 100%", action: #selector(noop), keyEquivalent: "1")
        zoomMenu.addItem(withTitle: "Large 400%", action: #selector(noop), keyEquivalent: "")
        zoomMenu.addItem(withTitle: "Custom\u{2026}", action: #selector(noop), keyEquivalent: "")
        zoomMenu.addItem(.separator())
        zoomMenu.addItem(withTitle: "Show Grid", action: #selector(noop), keyEquivalent: "")
        zoomMenu.addItem(withTitle: "Show Thumbnail", action: #selector(noop), keyEquivalent: "")

        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Tool Box", action: #selector(noop), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Color Box", action: #selector(noop), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Status Bar", action: #selector(noop), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Text Toolbar", action: #selector(noop), keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "View Bitmap", action: #selector(noop), keyEquivalent: "")

        // Image
        let imageMenuItem = NSMenuItem()
        mainMenu.addItem(imageMenuItem)
        let imageMenu = NSMenu(title: "Image")
        imageMenuItem.submenu = imageMenu
        imageMenu.addItem(withTitle: "Flip/Rotate\u{2026}", action: #selector(noop), keyEquivalent: "r")
        imageMenu.addItem(withTitle: "Stretch/Skew\u{2026}", action: #selector(noop), keyEquivalent: "w")
        imageMenu.addItem(withTitle: "Invert Colors", action: #selector(noop), keyEquivalent: "i")
        imageMenu.addItem(withTitle: "Attributes\u{2026}", action: #selector(noop), keyEquivalent: "e")
        imageMenu.addItem(withTitle: "Clear Image", action: #selector(noop), keyEquivalent: "")
        imageMenu.addItem(.separator())
        imageMenu.addItem(withTitle: "Draw Opaque", action: #selector(noop), keyEquivalent: "")

        // Colors
        let colorsMenuItem = NSMenuItem()
        mainMenu.addItem(colorsMenuItem)
        let colorsMenu = NSMenu(title: "Colors")
        colorsMenuItem.submenu = colorsMenu
        colorsMenu.addItem(withTitle: "Edit Colors\u{2026}", action: #selector(noop), keyEquivalent: "")

        // Help
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "Help Topics", action: #selector(noop), keyEquivalent: "")
        helpMenu.addItem(withTitle: "About Pigment", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    }

    @objc static func noop(_ sender: Any?) {}
}
