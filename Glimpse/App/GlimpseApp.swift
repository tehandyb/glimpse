import SwiftUI

@main
struct GlimpseApp: App {

    init() {
        Speaker.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
