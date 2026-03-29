import Foundation
import Core
import XCTest

final class WorkspaceContextProviderTests: XCTestCase {
    private final class MockWorkspaceContextProvider: WorkspaceContextProviding {
        var currentSnapshot: WorkspaceContextSnapshot

        init(currentSnapshot: WorkspaceContextSnapshot) {
            self.currentSnapshot = currentSnapshot
        }

        func snapshot() -> WorkspaceContextSnapshot {
            currentSnapshot
        }
    }

    func testFullscreenPauseProviderReflectsFullscreenSnapshots() {
        let workspaceContextProvider = MockWorkspaceContextProvider(
            currentSnapshot: WorkspaceContextSnapshot(
                frontmostApplicationBundleIdentifier: "com.apple.Keynote",
                isFrontmostApplicationFullscreenFocused: true
            )
        )
        let provider = FullscreenPauseConditionProvider(
            workspaceContextProvider: workspaceContextProvider
        )

        XCTAssertTrue(provider.isPaused(at: Date()))
    }

    func testFullscreenPauseProviderIgnoresNonFullscreenSnapshots() {
        let workspaceContextProvider = MockWorkspaceContextProvider(
            currentSnapshot: WorkspaceContextSnapshot(
                frontmostApplicationBundleIdentifier: "com.apple.Safari",
                isFrontmostApplicationFullscreenFocused: false
            )
        )
        let provider = FullscreenPauseConditionProvider(
            workspaceContextProvider: workspaceContextProvider
        )

        XCTAssertFalse(provider.isPaused(at: Date()))
    }
}
