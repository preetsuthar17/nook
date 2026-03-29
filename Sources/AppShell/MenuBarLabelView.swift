import Core
import SwiftUI

struct MenuBarLabelContent: Equatable {
    var symbolName: String
    var countdownText: String?
    var accessibilityLabel: String
}

enum MenuBarLabelFormatter {
    static func content(launchPhase: AppLaunchPhase, state: AppState) -> MenuBarLabelContent {
        guard launchPhase == .ready else {
            return MenuBarLabelContent(
                symbolName: "pause.fill",
                countdownText: nil,
                accessibilityLabel: "nook"
            )
        }

        if let activeBreak = state.activeBreak {
            return MenuBarLabelContent(
                symbolName: "pause.circle.fill",
                countdownText: state.countdownText,
                accessibilityLabel: "\(activeBreak.kind.title) in progress"
            )
        }

        if state.isPaused {
            return MenuBarLabelContent(
                symbolName: "pause.fill",
                countdownText: nil,
                accessibilityLabel: state.pauseReason ?? "Paused"
            )
        }

        if state.nextBreakDate != nil {
            return MenuBarLabelContent(
                symbolName: state.reminder == nil ? "hourglass" : "bell.badge.fill",
                countdownText: state.countdownText,
                accessibilityLabel: "Next break countdown"
            )
        }

        return MenuBarLabelContent(
            symbolName: "pause.fill",
            countdownText: nil,
            accessibilityLabel: state.statusText
        )
    }
}

struct MenuBarLabelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let content = MenuBarLabelFormatter.content(
            launchPhase: model.launchPhase,
            state: model.appState
        )

        HStack(spacing: 6) {
            Image(systemName: content.symbolName)

            if let countdownText = content.countdownText {
                Text(countdownText)
                    .monospacedDigit()
            }
        }
        .help(model.appState.statusText)
        .accessibilityLabel(content.accessibilityLabel)
    }
}
