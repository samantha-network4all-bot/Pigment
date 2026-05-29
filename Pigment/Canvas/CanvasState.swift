import Foundation

final class CanvasState {
    var bitmap: Bitmap
    var zoom: Int = 100
    var dirty: Bool = false
    var filePath: String? = nil
    var drawOpaque: Bool = true
    var selection: String? = nil // TODO: Selection model
    private var undoStack: [[UInt8]] = []
    private var redoStack: [[UInt8]] = []
    private let maxUndo = 50

    init(width: Int = 800, height: Int = 600) {
        self.bitmap = Bitmap(width: width, height: height)
        pushUndo()
    }

    func pushUndo() {
        if undoStack.count >= maxUndo {
            undoStack.removeFirst()
        }
        undoStack.append(bitmap.pixels)
        redoStack.removeAll()
    }

    func undo() -> Bool {
        guard undoStack.count > 1 else { return false }
        let current = undoStack.removeLast()
        redoStack.append(current)
        bitmap.pixels = undoStack.last!
        dirty = true
        return true
    }

    func redo() -> Bool {
        guard !redoStack.isEmpty else { return false }
        let pixels = redoStack.removeLast()
        undoStack.append(pixels)
        bitmap.pixels = pixels
        dirty = true
        return true
    }

    func clearRedo() {
        redoStack.removeAll()
    }
}
