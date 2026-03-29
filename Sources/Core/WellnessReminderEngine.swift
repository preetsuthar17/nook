import Foundation

public final class WellnessReminderEngine: @unchecked Sendable {
    private struct ReminderState: Sendable {
        var nextDueDate: Date?
        var lastDeliveredAt: Date?
    }

    private var settings: WellnessSettings
    private var states: [WellnessReminderKind: ReminderState]
    private var idleResetThreshold: TimeInterval

    public init(settings: WellnessSettings, idleResetThreshold: TimeInterval = 5 * 60) {
        self.settings = settings
        self.idleResetThreshold = idleResetThreshold
        self.states = Dictionary(uniqueKeysWithValues: WellnessReminderKind.allCases.map { ($0, ReminderState()) })
    }

    public func updateSettings(_ settings: WellnessSettings, idleResetThreshold: TimeInterval) {
        self.settings = settings
        self.idleResetThreshold = idleResetThreshold
    }

    public func advance(context: WellnessContext) -> [WellnessReminderEvent] {
        guard context.isOnboardingComplete else {
            reset(at: context.now)
            return []
        }

        guard context.activeBreak == nil,
              !context.isPaused,
              context.isWithinOfficeHours,
              !context.hasPendingBreakReminder
        else {
            return []
        }

        if context.idleSeconds >= idleResetThreshold {
            reset(at: context.now)
            return []
        }

        var events: [WellnessReminderEvent] = []
        for kind in WellnessReminderKind.allCases {
            let config = config(for: kind)
            guard config.isEnabled else { continue }

            let currentState = states[kind] ?? ReminderState()
            let nextDue = currentState.nextDueDate ?? context.now.addingTimeInterval(config.interval)
            if nextDue <= context.now {
                events.append(
                    WellnessReminderEvent(
                        kind: kind,
                        title: kind.title,
                        body: kind.body,
                        deliveryStyle: config.deliveryStyle,
                        scheduledAt: context.now
                    )
                )
            } else {
                states[kind] = ReminderState(nextDueDate: nextDue, lastDeliveredAt: currentState.lastDeliveredAt)
            }
        }

        return events
    }

    public func markDelivered(_ kind: WellnessReminderKind, at date: Date) {
        let config = config(for: kind)
        states[kind] = ReminderState(
            nextDueDate: date.addingTimeInterval(config.interval),
            lastDeliveredAt: date
        )
    }

    public func reset(at date: Date) {
        for kind in WellnessReminderKind.allCases {
            let config = config(for: kind)
            states[kind] = ReminderState(
                nextDueDate: date.addingTimeInterval(config.interval),
                lastDeliveredAt: nil
            )
        }
    }

    private func config(for kind: WellnessReminderKind) -> WellnessReminderConfig {
        switch kind {
        case .posture:
            settings.posture
        case .blink:
            settings.blink
        }
    }
}
