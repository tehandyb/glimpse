import Foundation

struct GlassesFrame {
    let jpegData: Data
    let capturedAt: Date

    var base64: String {
        jpegData.base64EncodedString()
    }
}
