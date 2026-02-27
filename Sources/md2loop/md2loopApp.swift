import SwiftUI

@main
struct md2loopApp: App {
    var body: some Scene {
        Window("md2loop", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 280, height: 220)
    }
}
