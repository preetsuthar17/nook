import Foundation

public protocol PauseConditionProvider: Sendable {
    var name: String { get }
    func isPaused(at date: Date) -> Bool
}

public final class BreakScheduler: @unchecked Sendable {
    public struct Snapshot: Sendable {
        public var state: AppState
        public var reminderJustActivated: Bool
        public var breakJustStarted: Bool
        public var breakJustEnded: Bool

        public init(state: AppState, reminderJustActivated: Bool, breakJustStarted: Bool, breakJustEnded: Bool) {
            self.state = state
            self.reminderJustActivated = reminderJustActivated
            self.breakJustStarted = breakJustStarted
            self.breakJustEnded = breakJustEnded
        }
    }

    private struct AutomaticPauseState: Sendable {
        var providerName: String
        var pausedAt: Date
        var remainingUntilBreak: TimeInterval?
        var remainingUntilReminder: TimeInterval?
    }

    private var settings: AppSettings
    private let calendar: Calendar
    private var pauseProviders: [any PauseConditionProvider]
    private var nextBreakDate: Date?
    private var reminderForBreakDate: Date?
    private var activeBreak: BreakSession?
    private var isPaused = false
    private var pauseReason: String?
    private var automaticPauseState: AutomaticPauseState?
    private var suppressReminderForCurrentBreak = false
    private var completedMicroBreaks = 0
    private var postponedUntil: Date?
    private var lastKnownNow: Date?
    private var idleResetApplied = false
    private var manualPauseRemainingUntilBreak: TimeInterval?
    private var statusText = "Preparing your first session"
    private let smartPauseResumeGracePeriod: TimeInterval = 2 * 60

    public init(
        settings: AppSettings = .default,
        calendar: Calendar = .current,
        pauseProviders: [any PauseConditionProvider] = []
    ) {
        self.settings = settings
        self.calendar = calendar
        self.pauseProviders = pauseProviders
    }

    public func updateSettings(_ settings: AppSettings, now: Date) -> Snapshot {
        self.settings = settings.migrated()
        if settings.scheduleSettings.officeHours.isEmpty {
            nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
        } else if !isWithinOfficeHours(now) {
            nextBreakDate = nil
            reminderForBreakDate = nil
            activeBreak = nil
        } else if nextBreakDate == nil {
            nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
        }

        return advance(to: now, idleSeconds: 0)
    }

    public func setPauseProviders(_ providers: [any PauseConditionProvider]) {
        pauseProviders = providers
    }

    public func advance(to now: Date, idleSeconds: TimeInterval) -> Snapshot {
        let reminderWasVisible = reminderForBreakDate != nil
        let hadActiveBreak = activeBreak != nil
        lastKnownNow = now

        if isPaused, automaticPauseState == nil, pauseReason != nil, activeBreak == nil {
            statusText = pauseReason ?? "Paused"
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
        }

        if automaticPauseState != nil, !isWithinOfficeHours(now) {
            clearAutomaticPause()
        }

        guard isWithinOfficeHours(now) else {
            activeBreak = nil
            reminderForBreakDate = nil
            nextBreakDate = nil
            suppressReminderForCurrentBreak = false
            statusText = "Outside office hours"
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: hadActiveBreak)
        }

        if activeBreak == nil, let provider = pauseProviders.first(where: { $0.isPaused(at: now) }) {
            enterAutomaticPause(named: provider.name, now: now)
            statusText = "Paused by \(provider.name)"
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
        }

        if automaticPauseState != nil {
            restoreAutomaticPause(at: now)
        }

        if activeBreak == nil, idleSeconds >= settings.scheduleSettings.idleResetThreshold {
            if !idleResetApplied {
                nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
                reminderForBreakDate = nil
                postponedUntil = nil
                suppressReminderForCurrentBreak = false
                idleResetApplied = true
            }
            statusText = "Timer reset after idle time"
        } else {
            idleResetApplied = false
        }

        if let breakSession = activeBreak {
            if now >= breakSession.scheduledEnd {
                completeActiveBreak(at: now)
                return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: true)
            }

            let remaining = breakSession.scheduledEnd.timeIntervalSince(now)
            statusText = "\(breakSession.kind.title) in progress (\(remaining.countdownString) left)"
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
        }

        if nextBreakDate == nil {
            nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
        }

        if let postponedUntil, let nextBreakDate, postponedUntil > nextBreakDate {
            self.nextBreakDate = postponedUntil
        }

        guard let nextBreakDate else {
            statusText = "Waiting for office hours"
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
        }

        let reminderLead = settings.breakSettings.reminderLeadTime
        let shouldShowReminder = !suppressReminderForCurrentBreak &&
            reminderLead > 0 &&
            now >= nextBreakDate.addingTimeInterval(-reminderLead) &&
            now < nextBreakDate
        if shouldShowReminder {
            reminderForBreakDate = nextBreakDate
            statusText = "Break coming up in \(nextBreakDate.timeIntervalSince(now).countdownString)"
            return snapshot(
                now: now,
                reminderJustActivated: !reminderWasVisible,
                breakJustStarted: false,
                breakJustEnded: false
            )
        }

        reminderForBreakDate = nil

        if now >= nextBreakDate {
            beginBreak(at: now)
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: true, breakJustEnded: false)
        }

        statusText = "Next break in \(nextBreakDate.timeIntervalSince(now).countdownString)"
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
    }

    public func startBreakNow(at now: Date) -> Snapshot {
        beginBreak(at: now)
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: true, breakJustEnded: false)
    }

    public func postpone(minutes: Int, now: Date) -> Snapshot {
        guard activeBreak == nil else {
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
        }

        let postponeDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        postponedUntil = postponeDate
        suppressReminderForCurrentBreak = false
        if let nextBreakDate {
            self.nextBreakDate = max(nextBreakDate, postponeDate)
        } else {
            self.nextBreakDate = postponeDate
        }
        reminderForBreakDate = nil
        statusText = "Break postponed by \(minutes) minutes"
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
    }

    public func skipCurrentBreak(at now: Date) -> Snapshot {
        if let activeBreak {
            guard canSkip(breakSession: activeBreak, now: now) else {
                return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
            }

            if activeBreak.kind == .long {
                completedMicroBreaks = 0
            }
            self.activeBreak = nil
            nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
            reminderForBreakDate = nil
            suppressReminderForCurrentBreak = false
            statusText = "Break skipped"
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: true)
        }

        nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
        reminderForBreakDate = nil
        suppressReminderForCurrentBreak = false
        statusText = "Upcoming break skipped"
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
    }

    public func endBreakEarly(at now: Date) -> Snapshot {
        guard activeBreak != nil else {
            return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
        }

        completeActiveBreak(at: now)
        statusText = "Break ended early"
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: true)
    }

    public func pause(reason: String = "Manual Pause", now: Date) -> Snapshot {
        automaticPauseState = nil
        isPaused = true
        pauseReason = reason
        manualPauseRemainingUntilBreak = nextBreakDate.map { max($0.timeIntervalSince(now), 0) }
        statusText = reason
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
    }

    public func resume(now: Date) -> Snapshot {
        automaticPauseState = nil
        isPaused = false
        pauseReason = nil
        if activeBreak == nil {
            if let remaining = manualPauseRemainingUntilBreak {
                nextBreakDate = now.addingTimeInterval(remaining)
            } else {
                nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
            }
            reminderForBreakDate = nil
            suppressReminderForCurrentBreak = false
        }
        manualPauseRemainingUntilBreak = nil
        statusText = "Back on schedule"
        return snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false)
    }

    public func currentState(now: Date) -> AppState {
        snapshot(now: now, reminderJustActivated: false, breakJustStarted: false, breakJustEnded: false).state
    }

    private func canSkip(breakSession: BreakSession, now: Date) -> Bool {
        switch settings.breakSettings.skipPolicy {
        case .casual:
            return true
        case .balanced:
            guard let skipAvailableAfter = breakSession.skipAvailableAfter else { return true }
            return now >= skipAvailableAfter
        case .hardcore:
            return false
        }
    }

    private func beginBreak(at now: Date) {
        let kind = nextBreakKind
        let duration = kind == .long ? settings.breakSettings.longBreakDuration : settings.breakSettings.microBreakDuration
        let message = settings.breakSettings.customMessages.randomElement() ?? "Rest your eyes for a moment."
        let skipAvailableAfter: Date?
        switch settings.breakSettings.skipPolicy {
        case .casual:
            skipAvailableAfter = now
        case .balanced:
            skipAvailableAfter = now.addingTimeInterval(settings.breakSettings.skipPolicy.buttonDelay)
        case .hardcore:
            skipAvailableAfter = nil
        }

        activeBreak = BreakSession(
            kind: kind,
            startedAt: now,
            scheduledEnd: now.addingTimeInterval(duration),
            message: message,
            backgroundStyle: settings.breakSettings.backgroundStyle,
            skipAvailableAfter: skipAvailableAfter
        )
        reminderForBreakDate = nil
        suppressReminderForCurrentBreak = false
        postponedUntil = nil
        nextBreakDate = nil
        statusText = "\(kind.title) started"
    }

    private func completeActiveBreak(at now: Date) {
        guard let activeBreak else { return }

        switch activeBreak.kind {
        case .micro:
            completedMicroBreaks += 1
        case .long:
            completedMicroBreaks = 0
        }

        self.activeBreak = nil
        reminderForBreakDate = nil
        suppressReminderForCurrentBreak = false
        postponedUntil = nil
        nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
        statusText = "Nice work. Next break in \(settings.breakSettings.workInterval.countdownString)"
    }

    private var nextBreakKind: BreakKind {
        guard settings.breakSettings.longBreaksEnabled else {
            return .micro
        }

        let cadence = max(settings.breakSettings.longBreakCadence, 1)
        return completedMicroBreaks >= cadence ? .long : .micro
    }

    private func snapshot(
        now: Date,
        reminderJustActivated: Bool,
        breakJustStarted: Bool,
        breakJustEnded: Bool
    ) -> Snapshot {
        let displayedNextBreakDate = automaticPauseState?.remainingUntilBreak.map {
            now.addingTimeInterval($0)
        } ?? nextBreakDate

        return Snapshot(
            state: AppState(
                now: now,
                nextBreakDate: displayedNextBreakDate,
                activeBreak: activeBreak,
                reminder: automaticPauseState == nil ? reminderForBreakDate.map {
                    ReminderState(
                        dueDate: now,
                        scheduledBreakDate: $0
                    )
                } : nil,
                isPaused: isPaused,
                pauseReason: pauseReason,
                statusText: statusText
            ),
            reminderJustActivated: reminderJustActivated,
            breakJustStarted: breakJustStarted,
            breakJustEnded: breakJustEnded
        )
    }

    private func isWithinOfficeHours(_ date: Date) -> Bool {
        settings.scheduleSettings.isWithinOfficeHours(date, calendar: calendar)
    }

    private func enterAutomaticPause(named providerName: String, now: Date) {
        if automaticPauseState == nil {
            automaticPauseState = AutomaticPauseState(
                providerName: providerName,
                pausedAt: now,
                remainingUntilBreak: nextBreakDate.map { max($0.timeIntervalSince(now), 0) },
                remainingUntilReminder: remainingUntilReminder(at: now)
            )
        }

        isPaused = true
        pauseReason = providerName
        reminderForBreakDate = nil
    }

    private func restoreAutomaticPause(at now: Date) {
        guard let automaticPauseState else { return }

        let pausedDuration = now.timeIntervalSince(automaticPauseState.pausedAt)
        let reminderWouldHaveBeenDue = automaticPauseState.remainingUntilReminder.map { pausedDuration >= $0 } ?? false
        let breakWouldHaveBeenDue = automaticPauseState.remainingUntilBreak.map { pausedDuration >= $0 } ?? false

        self.automaticPauseState = nil
        isPaused = false
        pauseReason = nil

        if reminderWouldHaveBeenDue || breakWouldHaveBeenDue {
            nextBreakDate = now.addingTimeInterval(smartPauseResumeGracePeriod)
            reminderForBreakDate = nil
            suppressReminderForCurrentBreak = true
            return
        }

        if let remainingUntilBreak = automaticPauseState.remainingUntilBreak {
            nextBreakDate = now.addingTimeInterval(remainingUntilBreak)
        } else if nextBreakDate == nil, activeBreak == nil {
            nextBreakDate = now.addingTimeInterval(settings.breakSettings.workInterval)
        }

        reminderForBreakDate = nil
        suppressReminderForCurrentBreak = false
    }

    private func clearAutomaticPause() {
        automaticPauseState = nil
        if pauseReason != nil {
            isPaused = false
            pauseReason = nil
        }
    }

    private func remainingUntilReminder(at now: Date) -> TimeInterval? {
        guard let nextBreakDate else { return nil }

        if reminderForBreakDate != nil {
            return 0
        }

        let reminderLead = settings.breakSettings.reminderLeadTime
        guard reminderLead > 0 else { return nil }

        return max(nextBreakDate.addingTimeInterval(-reminderLead).timeIntervalSince(now), 0)
    }
}
