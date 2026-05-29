import Foundation

struct Overlay {
    var bitmap: Bitmap
    var visible: Bool = true

    init(width: Int, height: Int) {
        self.bitmap = Bitmap(width: width, height: height)
    }
}
