import Foundation

struct WindowState {
    var cursorX: Int?
    var cursorY: Int?
    var selectionWidth: Int?
    var selectionHeight: Int?
    var canvasWidth: Int
    var canvasHeight: Int

    init(canvasWidth: Int = 800, canvasHeight: Int = 600) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}
