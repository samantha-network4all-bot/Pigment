import Foundation

enum ToolButton { case primary, secondary }

enum ToolResult {
    case pickColor(fg: Bool, r: UInt8, g: UInt8, b: UInt8)
}

struct ToolContext {
    var bitmap: Bitmap
    var overlay: Bitmap?
    var fgColor: (UInt8, UInt8, UInt8)
    var bgColor: (UInt8, UInt8, UInt8)
    var options: ToolOptions
    var button: ToolButton = .primary
    var result: ToolResult? = nil

    init(
        bitmap: Bitmap,
        overlay: Bitmap? = nil,
        fgColor: (UInt8, UInt8, UInt8) = (0, 0, 0),
        bgColor: (UInt8, UInt8, UInt8) = (255, 255, 255),
        options: ToolOptions = ToolOptions(),
        button: ToolButton = .primary
    ) {
        self.bitmap = bitmap
        self.overlay = overlay
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.options = options
        self.button = button
    }
}
