import Combine
import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var isEnabled: Bool = false

    public init() {
        refresh()
    }

    public func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        refresh()
    }
}
