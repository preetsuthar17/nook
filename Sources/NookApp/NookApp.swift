import SwiftUI

@main
struct NookApp: App {
    @NSApplicationDelegateAdaptor(NookApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
