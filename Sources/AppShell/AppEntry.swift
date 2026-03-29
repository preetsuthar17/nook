import SwiftUI

@main
struct AppEntry: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
