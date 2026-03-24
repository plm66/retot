import SwiftUI

@main
struct RetotiOSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environmentObject(appState)
        }
    }
}
