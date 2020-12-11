import SwiftUI

@main
struct WiiMoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(connectionManager: WiiMoteConntectionManager())
        }
    }
}
