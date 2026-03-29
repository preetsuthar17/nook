import Foundation
import Core

enum TimerPhase: Equatable {
    case work
    case breakTime
    case idle
}

extension AppState {
    var timerPhase: TimerPhase {
        if activeBreak != nil {
            return .breakTime
        }

        if nextBreakDate != nil {
            return .work
        }

        return .idle
    }

    var countdownTargetDate: Date? {
        activeBreak?.scheduledEnd ?? nextBreakDate
    }

    var remainingCountdown: TimeInterval? {
        guard let countdownTargetDate else { return nil }
        return max(countdownTargetDate.timeIntervalSince(now), 0)
    }

    var countdownText: String? {
        remainingCountdown?.countdownString
    }
}
