import Foundation

struct ToolContext {
    var bitmap: Bitmap
    var overlay: Bitmap?
    var fgColor: (UInt8, UInt8, UInt8)
    var bgColor: (UInt8, UInt8, UInt8)
    var options: ToolOptions

    init(
        bitmap: Bitmap,
        overlay: Bitmap? = nil,
        fgColor: (UInt8, UInt8, UInt8) = (0, 0, 0),
        bgColor: (UInt8, UInt8, UInt8) = (255, 255, 255),
        options: ToolOptions = ToolOptions()
    ) {
        self.bitmap = bitmap
        self.overlay = overlay
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.options = options
    }
}
