import Foundation

public enum BreakKind: String, Codable, CaseIterable, Sendable {
    case micro
    case long

    public var title: String {
        switch self {
        case .micro:
            "Short Break"
        case .long:
            "Long Break"
        }
    }
}

public enum SkipPolicy: String, Codable, CaseIterable, Sendable, Identifiable {
    case casual
    case balanced
    case hardcore

    public var id: String { rawValue }

    public var buttonDelay: TimeInterval {
        switch self {
        case .casual:
            0
        case .balanced:
            8
        case .hardcore:
            .infinity
        }
    }

    public var title: String {
        rawValue.capitalized
    }
}

public enum BreakSound: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case breeze
    case glass
    case hero

    public var id: String { rawValue }
}

public enum BreakBackgroundStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case dawn
    case ocean
    case moss
    case graphite

    public var id: String { rawValue }
}

public struct OfficeHoursRule: Codable, Hashable, Sendable, Identifiable {
    public var weekday: Int
    public var startMinutes: Int
    public var endMinutes: Int
    public var isEnabled: Bool

    public init(weekday: Int, startMinutes: Int, endMinutes: Int, isEnabled: Bool = true) {
        self.weekday = weekday
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.isEnabled = isEnabled
    }

    public var id: String {
        "\(weekday)-\(startMinutes)-\(endMinutes)"
    }
}

public struct BreakSettings: Codable, Hashable, Sendable {
    public var workInterval: TimeInterval
    public var microBreakDuration: TimeInterval
    public var reminderLeadTime: TimeInterval
    public var longBreakDuration: TimeInterval
    public var longBreakCadence: Int
    public var longBreaksEnabled: Bool
    public var allowEarlyEnd: Bool
    public var skipPolicy: SkipPolicy
    public var customMessages: [String]
    public var selectedSound: BreakSound
    public var backgroundStyle: BreakBackgroundStyle

    public init(
        workInterval: TimeInterval,
        microBreakDuration: TimeInterval,
        reminderLeadTime: TimeInterval,
        longBreakDuration: TimeInterval,
        longBreakCadence: Int,
        longBreaksEnabled: Bool,
        allowEarlyEnd: Bool,
        skipPolicy: SkipPolicy,
        customMessages: [String],
        selectedSound: BreakSound,
        backgroundStyle: BreakBackgroundStyle
    ) {
        self.workInterval = workInterval
        self.microBreakDuration = microBreakDuration
        self.reminderLeadTime = reminderLeadTime
        self.longBreakDuration = longBreakDuration
        self.longBreakCadence = longBreakCadence
        self.longBreaksEnabled = longBreaksEnabled
        self.allowEarlyEnd = allowEarlyEnd
        self.skipPolicy = skipPolicy
        self.customMessages = customMessages
        self.selectedSound = selectedSound
        self.backgroundStyle = backgroundStyle
    }

    public static let `default` = BreakSettings(
        workInterval: 20 * 60,
        microBreakDuration: 20,
        reminderLeadTime: 60,
        longBreakDuration: 5 * 60,
        longBreakCadence: 3,
        longBreaksEnabled: true,
        allowEarlyEnd: true,
        skipPolicy: .balanced,
        customMessages: [
            "Look across the room and relax your focus.",
            "Drop your shoulders and unclench your jaw.",
            "Blink slowly a few times and take a breath.",
        ],
        selectedSound: .breeze,
        backgroundStyle: .dawn
    )
}

public struct ScheduleSettings: Codable, Hashable, Sendable {
    public var idleResetThreshold: TimeInterval
    public var officeHours: [OfficeHoursRule]
    public var launchAtLogin: Bool

    public init(idleResetThreshold: TimeInterval, officeHours: [OfficeHoursRule], launchAtLogin: Bool) {
        self.idleResetThreshold = idleResetThreshold
        self.officeHours = officeHours
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = ScheduleSettings(
        idleResetThreshold: 5 * 60,
        officeHours: [],
        launchAtLogin: true
    )

    public func isWithinOfficeHours(_ date: Date, calendar: Calendar = .current) -> Bool {
        let rules = officeHours.filter(\.isEnabled)
        guard !rules.isEmpty else { return true }

        let weekday = calendar.component(.weekday, from: date)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        return rules.contains { rule in
            rule.weekday == weekday && minutes >= rule.startMinutes && minutes < rule.endMinutes
        }
    }
}

public struct SmartPauseSettings: Codable, Hashable, Sendable {
    public var pauseDuringFullscreenFocus: Bool

    public init(pauseDuringFullscreenFocus: Bool) {
        self.pauseDuringFullscreenFocus = pauseDuringFullscreenFocus
    }

    public static let `default` = SmartPauseSettings(
        pauseDuringFullscreenFocus: true
    )

    public static let migratedDefault = SmartPauseSettings(
        pauseDuringFullscreenFocus: false
    )
}

public enum WellnessReminderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case posture
    case blink

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .posture:
            "Posture Check"
        case .blink:
            "Blink Reminder"
        }
    }

    public var body: String {
        switch self {
        case .posture:
            "Sit tall, relax your shoulders, and let your neck reset."
        case .blink:
            "Blink slowly a few times and soften your focus for a moment."
        }
    }
}

public enum WellnessDeliveryStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case panel
    case notification

    public var id: String { rawValue }
}

public struct WellnessReminderConfig: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var interval: TimeInterval
    public var deliveryStyle: WellnessDeliveryStyle

    public init(isEnabled: Bool, interval: TimeInterval, deliveryStyle: WellnessDeliveryStyle) {
        self.isEnabled = isEnabled
        self.interval = interval
        self.deliveryStyle = deliveryStyle
    }
}

public struct WellnessSettings: Codable, Hashable, Sendable {
    public var posture: WellnessReminderConfig
    public var blink: WellnessReminderConfig

    public init(posture: WellnessReminderConfig, blink: WellnessReminderConfig) {
        self.posture = posture
        self.blink = blink
    }

    public static let `default` = WellnessSettings(
        posture: WellnessReminderConfig(isEnabled: true, interval: 30 * 60, deliveryStyle: .panel),
        blink: WellnessReminderConfig(isEnabled: true, interval: 10 * 60, deliveryStyle: .panel)
    )

    public static let migratedDefault = WellnessSettings(
        posture: WellnessReminderConfig(isEnabled: false, interval: 30 * 60, deliveryStyle: .panel),
        blink: WellnessReminderConfig(isEnabled: false, interval: 10 * 60, deliveryStyle: .panel)
    )
}

public struct WellnessContext: Sendable {
    public var isOnboardingComplete: Bool
    public var isPaused: Bool
    public var activeBreak: BreakSession?
    public var idleSeconds: TimeInterval
    public var isWithinOfficeHours: Bool
    public var hasPendingBreakReminder: Bool
    public var now: Date

    public init(
        isOnboardingComplete: Bool,
        isPaused: Bool,
        activeBreak: BreakSession?,
        idleSeconds: TimeInterval,
        isWithinOfficeHours: Bool,
        hasPendingBreakReminder: Bool,
        now: Date
    ) {
        self.isOnboardingComplete = isOnboardingComplete
        self.isPaused = isPaused
        self.activeBreak = activeBreak
        self.idleSeconds = idleSeconds
        self.isWithinOfficeHours = isWithinOfficeHours
        self.hasPendingBreakReminder = hasPendingBreakReminder
        self.now = now
    }
}

public struct WellnessReminderEvent: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var kind: WellnessReminderKind
    public var title: String
    public var body: String
    public var deliveryStyle: WellnessDeliveryStyle
    public var scheduledAt: Date

    public init(kind: WellnessReminderKind, title: String, body: String, deliveryStyle: WellnessDeliveryStyle, scheduledAt: Date) {
        self.kind = kind
        self.title = title
        self.body = body
        self.deliveryStyle = deliveryStyle
        self.scheduledAt = scheduledAt
    }
}

public struct OnboardingState: Codable, Hashable, Sendable {
    public var hasCompletedStarterSetup: Bool
    public var completedAt: Date?
    public var lastCompletedVersion: Int?

    public init(hasCompletedStarterSetup: Bool, completedAt: Date? = nil, lastCompletedVersion: Int? = nil) {
        self.hasCompletedStarterSetup = hasCompletedStarterSetup
        self.completedAt = completedAt
        self.lastCompletedVersion = lastCompletedVersion
    }

    public static let `default` = OnboardingState(hasCompletedStarterSetup: false)
    public static let migratedDefault = OnboardingState(hasCompletedStarterSetup: true)

    enum CodingKeys: String, CodingKey {
        case hasCompletedStarterSetup
        case hasCompleted
        case completedAt
        case lastCompletedVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let completion = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedStarterSetup)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasCompleted)
            ?? false

        self.init(
            hasCompletedStarterSetup: completion,
            completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt),
            lastCompletedVersion: try container.decodeIfPresent(Int.self, forKey: .lastCompletedVersion)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasCompletedStarterSetup, forKey: .hasCompletedStarterSetup)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(lastCompletedVersion, forKey: .lastCompletedVersion)
    }
}

public enum HintKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case firstBreak
    case firstWellness

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstBreak:
            "Skip or postpone"
        case .firstWellness:
            "Turn this off anytime"
        }
    }

    public var body: String {
        switch self {
        case .firstBreak:
            "If you need a little more time, you can postpone this break."
        case .firstWellness:
            "Posture and blink reminders live in Settings whenever you want to change them."
        }
    }

    public var symbolName: String {
        switch self {
        case .firstBreak:
            "pause.circle"
        case .firstWellness:
            "figure.seated.side.air.upper"
        }
    }
}

public enum HintDeliveryStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case panel

    public var id: String { rawValue }
}

public struct HintEvent: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var kind: HintKind
    public var title: String
    public var body: String
    public var delivery: HintDeliveryStyle

    public init(kind: HintKind, title: String, body: String, delivery: HintDeliveryStyle) {
        self.kind = kind
        self.title = title
        self.body = body
        self.delivery = delivery
    }
}

public struct ContextualEducationState: Codable, Hashable, Sendable {
    public var hasSeenFirstBreakHint: Bool
    public var hasSeenFirstWellnessHint: Bool

    public init(hasSeenFirstBreakHint: Bool, hasSeenFirstWellnessHint: Bool) {
        self.hasSeenFirstBreakHint = hasSeenFirstBreakHint
        self.hasSeenFirstWellnessHint = hasSeenFirstWellnessHint
    }

    public static let `default` = ContextualEducationState(
        hasSeenFirstBreakHint: false,
        hasSeenFirstWellnessHint: false
    )

    public static let migratedDefault = ContextualEducationState(
        hasSeenFirstBreakHint: true,
        hasSeenFirstWellnessHint: true
    )
}

public struct AppSettings: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    public var breakSettings: BreakSettings
    public var scheduleSettings: ScheduleSettings
    public var smartPauseSettings: SmartPauseSettings
    public var wellnessSettings: WellnessSettings
    public var onboardingState: OnboardingState
    public var contextualEducationState: ContextualEducationState

    public init(
        schemaVersion: Int = AppSettings.currentSchemaVersion,
        breakSettings: BreakSettings,
        scheduleSettings: ScheduleSettings,
        smartPauseSettings: SmartPauseSettings,
        wellnessSettings: WellnessSettings,
        onboardingState: OnboardingState,
        contextualEducationState: ContextualEducationState
    ) {
        self.schemaVersion = schemaVersion
        self.breakSettings = breakSettings
        self.scheduleSettings = scheduleSettings
        self.smartPauseSettings = smartPauseSettings
        self.wellnessSettings = wellnessSettings
        self.onboardingState = onboardingState
        self.contextualEducationState = contextualEducationState
    }

    public static let `default` = AppSettings(
        breakSettings: .default,
        scheduleSettings: .default,
        smartPauseSettings: .default,
        wellnessSettings: .default,
        onboardingState: .default,
        contextualEducationState: .default
    )

    public func migrated() -> AppSettings {
        AppSettings(
            schemaVersion: AppSettings.currentSchemaVersion,
            breakSettings: breakSettings,
            scheduleSettings: scheduleSettings,
            smartPauseSettings: smartPauseSettings,
            wellnessSettings: wellnessSettings,
            onboardingState: OnboardingState(
                hasCompletedStarterSetup: onboardingState.hasCompletedStarterSetup,
                completedAt: onboardingState.completedAt,
                lastCompletedVersion: onboardingState.lastCompletedVersion ?? AppSettings.currentSchemaVersion
            ),
            contextualEducationState: contextualEducationState
        )
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case breakSettings
        case scheduleSettings
        case smartPauseSettings
        case wellnessSettings
        case onboardingState
        case contextualEducationState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let breakSettings = try container.decodeIfPresent(BreakSettings.self, forKey: .breakSettings) ?? .default
        let scheduleSettings = try container.decodeIfPresent(ScheduleSettings.self, forKey: .scheduleSettings) ?? .default
        let smartPauseSettings = try container.decodeIfPresent(SmartPauseSettings.self, forKey: .smartPauseSettings) ?? .migratedDefault
        let wellnessSettings = try container.decodeIfPresent(WellnessSettings.self, forKey: .wellnessSettings) ?? .migratedDefault
        let onboardingState = try container.decodeIfPresent(OnboardingState.self, forKey: .onboardingState) ?? .migratedDefault
        let contextualEducationState = try container.decodeIfPresent(ContextualEducationState.self, forKey: .contextualEducationState) ?? .migratedDefault

        self.init(
            schemaVersion: schemaVersion,
            breakSettings: breakSettings,
            scheduleSettings: scheduleSettings,
            smartPauseSettings: smartPauseSettings,
            wellnessSettings: wellnessSettings,
            onboardingState: onboardingState,
            contextualEducationState: contextualEducationState
        )
    }
}

public struct ReminderState: Hashable, Sendable {
    public var dueDate: Date
    public var scheduledBreakDate: Date
}

public struct BreakSession: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: BreakKind
    public var startedAt: Date
    public var scheduledEnd: Date
    public var message: String
    public var backgroundStyle: BreakBackgroundStyle
    public var skipAvailableAfter: Date?

    public init(
        id: UUID = UUID(),
        kind: BreakKind,
        startedAt: Date,
        scheduledEnd: Date,
        message: String,
        backgroundStyle: BreakBackgroundStyle,
        skipAvailableAfter: Date?
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.scheduledEnd = scheduledEnd
        self.message = message
        self.backgroundStyle = backgroundStyle
        self.skipAvailableAfter = skipAvailableAfter
    }
}

public struct AppState: Sendable {
    public var now: Date
    public var nextBreakDate: Date?
    public var activeBreak: BreakSession?
    public var reminder: ReminderState?
    public var isPaused: Bool
    public var pauseReason: String?
    public var statusText: String

    public init(
        now: Date,
        nextBreakDate: Date?,
        activeBreak: BreakSession?,
        reminder: ReminderState?,
        isPaused: Bool,
        pauseReason: String?,
        statusText: String
    ) {
        self.now = now
        self.nextBreakDate = nextBreakDate
        self.activeBreak = activeBreak
        self.reminder = reminder
        self.isPaused = isPaused
        self.pauseReason = pauseReason
        self.statusText = statusText
    }
}

public extension TimeInterval {
    var countdownString: String {
        let total = max(Int(ceil(self)), 0)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var clockString: String {
        countdownString
    }
}
