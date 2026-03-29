import AppKit
@preconcurrency import Combine
import Foundation
import Core
import OSLog
import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var appState: AppState
    @Published var launchPhase: AppLaunchPhase
    @Published var menuBarMode: MenuBarMode
    @Published var onboardingState: OnboardingState
    @Published var settingsError: String?
    @Published var pendingWellnessEvent: WellnessReminderEvent?

    private let scheduler: BreakScheduler
    private let wellnessReminderEngine: WellnessReminderEngine
    private let contextualEducationEngine: ContextualEducationEngine
    private let settingsStore: SettingsStore
    private let activityMonitor: any ActivityMonitoring
    let launchAtLoginController: LaunchAtLoginController
    private let workspaceContextProvider: any WorkspaceContextProviding
    private let fullscreenPauseProvider: FullscreenPauseConditionProvider
    private let injectedWindowCoordinator: (any WindowCoordinator)?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "nook", category: "Timer")

    private var timerCancellable: AnyCancellable?
    private var wakeObserver: NSObjectProtocol?
    private var hasHandledInitialAppLaunch = false

    private lazy var onboardingFlowWindowController = OnboardingFlowWindowController()
    private lazy var breakOverlayController = BreakOverlayWindowController(model: self)
    private lazy var breakReminderController = ReminderPanelController(model: self)
    private lazy var wellnessPanelController = WellnessPanelController()
    private lazy var defaultWindowCoordinator = AppWindowCoordinator(
        model: self,
        onboardingFlowController: onboardingFlowWindowController,
        breakOverlayController: breakOverlayController,
        breakReminderController: breakReminderController,
        wellnessReminderController: wellnessPanelController
    )
    private var windowCoordinator: any WindowCoordinator {
        injectedWindowCoordinator ?? defaultWindowCoordinator
    }

    init(
        settingsStore: SettingsStore = SettingsStore(),
        activityMonitor: any ActivityMonitoring = ActivityMonitor(),
        scheduler: BreakScheduler? = nil,
        launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController(),
        workspaceContextProvider: any WorkspaceContextProviding = WorkspaceContextProvider(),
        windowCoordinator: (any WindowCoordinator)? = nil,
        launchConfiguration: AppLaunchConfiguration = .current,
        startsTimer: Bool = true,
        observesSystemEvents: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.activityMonitor = activityMonitor
        var loadedSettings = (try? settingsStore.load()) ?? .default
        if let work = launchConfiguration.workIntervalOverride {
            loadedSettings.breakSettings.workInterval = work
        }
        if let brk = launchConfiguration.breakDurationOverride {
            loadedSettings.breakSettings.microBreakDuration = brk
        }
        let requiresStarterSetup = Self.requiresStarterSetup(
            settings: loadedSettings,
            launchConfiguration: launchConfiguration
        )
        let scheduler = scheduler ?? BreakScheduler(settings: loadedSettings)
        let fullscreenPauseProvider = FullscreenPauseConditionProvider(
            workspaceContextProvider: workspaceContextProvider
        )
        self.scheduler = scheduler
        self.wellnessReminderEngine = WellnessReminderEngine(
            settings: loadedSettings.wellnessSettings,
            idleResetThreshold: loadedSettings.scheduleSettings.idleResetThreshold
        )
        self.contextualEducationEngine = ContextualEducationEngine(state: loadedSettings.contextualEducationState)
        self.settings = loadedSettings
        self.onboardingState = loadedSettings.onboardingState
        self.launchPhase = requiresStarterSetup ? .onboarding : .ready
        self.menuBarMode = requiresStarterSetup ? .setup : .active
        self.launchAtLoginController = launchAtLoginController
        self.workspaceContextProvider = workspaceContextProvider
        self.fullscreenPauseProvider = fullscreenPauseProvider
        self.injectedWindowCoordinator = windowCoordinator

        scheduler.setPauseProviders(Self.makePauseProviders(
            settings: loadedSettings,
            fullscreenPauseProvider: fullscreenPauseProvider
        ))

        let now = Date()
        self.appState = requiresStarterSetup
            ? Self.setupState(now: now)
            : scheduler.currentState(now: now)

        if observesSystemEvents {
            self.bindSystemEvents()
        }
        if startsTimer {
            self.startTimer()
        }
    }

    func handleAppDidFinishLaunching(now: Date = Date()) {
        guard !hasHandledInitialAppLaunch else { return }
        hasHandledInitialAppLaunch = true

        if launchPhase == .ready {
            applySettingsSideEffects()
            tick(now: now)
        } else {
            windowCoordinator.show(.onboardingFlow)
        }
    }

    private static func requiresStarterSetup(
        settings: AppSettings,
        launchConfiguration: AppLaunchConfiguration
    ) -> Bool {
        launchConfiguration.forceOnboarding || !settings.onboardingState.hasCompletedStarterSetup
    }

    func tick(now: Date = Date()) {
        guard launchPhase == .ready else {
            appState = Self.setupState(now: now)
            pendingWellnessEvent = nil
            windowCoordinator.hideAllTransientWindows()
            return
        }

        let idleSeconds = activityMonitor.idleSeconds
        let snapshot = scheduler.advance(to: now, idleSeconds: idleSeconds)
        apply(snapshot: snapshot, now: now, idleSeconds: idleSeconds)
        processWellnessReminders(now: now, idleSeconds: idleSeconds)
    }

    func finishOnboardingFlow(workInterval: TimeInterval, breakDuration: TimeInterval) {
        let now = Date()

        settings.breakSettings.workInterval = workInterval
        settings.breakSettings.microBreakDuration = breakDuration
        settings.onboardingState = OnboardingState(
            hasCompletedStarterSetup: true,
            completedAt: now,
            lastCompletedVersion: AppSettings.currentSchemaVersion
        )

        do {
            try settingsStore.save(settings)
            settings = settings.migrated()
            onboardingState = settings.onboardingState
        } catch {
            settingsError = error.localizedDescription
        }

        windowCoordinator.hide(.onboardingFlow)

        launchPhase = .ready
        menuBarMode = .active
        _ = scheduler.updateSettings(settings, now: now)
        wellnessReminderEngine.updateSettings(
            settings.wellnessSettings,
            idleResetThreshold: settings.scheduleSettings.idleResetThreshold
        )
        configurePauseProviders()
        wellnessReminderEngine.reset(at: now)
        contextualEducationEngine.updateState(settings.contextualEducationState)
        applySettingsSideEffects()
        tick(now: now)
        requestNotificationPermissions()
        settingsError = nil
    }

    func startBreakNow() {
        guard launchPhase == .ready else {
            if launchPhase == .onboarding {
                windowCoordinator.show(.onboardingFlow)
            }
            return
        }
        let now = Date()
        let snapshot = scheduler.startBreakNow(at: now)
        apply(snapshot: snapshot, now: now, idleSeconds: activityMonitor.idleSeconds)
    }

    func postpone(minutes: Int) {
        guard launchPhase == .ready else { return }
        let now = Date()
        let snapshot = scheduler.postpone(minutes: minutes, now: now)
        apply(snapshot: snapshot, now: now, idleSeconds: activityMonitor.idleSeconds)
    }

    func skipCurrentBreak() {
        guard launchPhase == .ready else { return }
        let now = Date()
        let snapshot = scheduler.skipCurrentBreak(at: now)
        apply(snapshot: snapshot, now: now, idleSeconds: activityMonitor.idleSeconds)
    }

    func pauseOrResume() {
        guard launchPhase == .ready else { return }
        let now = Date()
        let snapshot: BreakScheduler.Snapshot
        if appState.isPaused {
            snapshot = scheduler.resume(now: now)
        } else {
            snapshot = scheduler.pause(reason: "Paused manually", now: now)
        }
        apply(snapshot: snapshot, now: now, idleSeconds: activityMonitor.idleSeconds)
    }

    func endBreakEarly() {
        guard launchPhase == .ready else { return }
        let now = Date()
        let snapshot = scheduler.endBreakEarly(at: now)
        apply(snapshot: snapshot, now: now, idleSeconds: activityMonitor.idleSeconds)
    }

    func saveSettings() {
        do {
            try settingsStore.save(settings)
            settings = settings.migrated()
            onboardingState = settings.onboardingState
            wellnessReminderEngine.updateSettings(
                settings.wellnessSettings,
                idleResetThreshold: settings.scheduleSettings.idleResetThreshold
            )
            contextualEducationEngine.updateState(settings.contextualEducationState)
            configurePauseProviders()
            if launchPhase == .ready {
                let now = Date()
                let snapshot = scheduler.updateSettings(settings, now: now)
                apply(snapshot: snapshot, now: now, idleSeconds: activityMonitor.idleSeconds)
                wellnessReminderEngine.reset(at: now)
            }
            applySettingsSideEffects()
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
        }
    }

    func dismissBreakWindow() {
        windowCoordinator.hideBreakOverlay()
    }

    func dismissStarterSetupWithDefaults() {
        finishOnboardingFlow(
            workInterval: BreakSettings.default.workInterval,
            breakDuration: BreakSettings.default.microBreakDuration
        )
    }

    private func apply(snapshot: BreakScheduler.Snapshot, now: Date, idleSeconds: TimeInterval) {
        appState = snapshot.state
        logTimerState(snapshot: snapshot, now: now, idleSeconds: idleSeconds)
        reconcileTimerWindows()

        if snapshot.reminderJustActivated, let nextBreakDate = snapshot.state.nextBreakDate {
            scheduleNotification(
                title: "Break almost time",
                body: "Take a short reset in \(nextBreakDate.timeIntervalSince(now).countdownString)."
            )
            _ = maybeShowContextualHint(.firstBreak, now: now)
        }

        if snapshot.breakJustStarted, let breakSession = snapshot.state.activeBreak {
            playSound(for: settings.breakSettings.selectedSound)
            pendingWellnessEvent = nil
            scheduleNotification(title: breakSession.kind.title, body: breakSession.message)
        }
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tick(now: date)
            }
    }

    private func bindSystemEvents() {
        wakeObserver = NotificationCenter.default.addObserver(
            forName: .nookSystemDidWake,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick(now: Date())
            }
        }
    }

    private func applySettingsSideEffects() {
        guard launchPhase == .ready else { return }
        do {
            try launchAtLoginController.setEnabled(settings.scheduleSettings.launchAtLogin)
        } catch {
            settingsError = "Launch at login could not be updated: \(error.localizedDescription)"
        }
    }

    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private func requestNotificationPermissions() {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(title: String, body: String) {
        guard canUseUserNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func playSound(for sound: BreakSound) {
        switch sound {
        case .none:
            return
        case .breeze:
            NSSound(named: "Submarine")?.play()
        case .glass:
            NSSound(named: "Glass")?.play()
        case .hero:
            NSSound(named: "Hero")?.play()
        }
    }

    private func processWellnessReminders(now: Date, idleSeconds: TimeInterval) {
        let context = WellnessContext(
            isOnboardingComplete: onboardingState.hasCompletedStarterSetup,
            isPaused: appState.isPaused,
            activeBreak: appState.activeBreak,
            idleSeconds: idleSeconds,
            isWithinOfficeHours: settings.scheduleSettings.isWithinOfficeHours(now),
            hasPendingBreakReminder: appState.reminder != nil,
            now: now
        )

        guard let event = wellnessReminderEngine.advance(context: context).first else {
            if appState.reminder != nil || appState.activeBreak != nil {
                if let existingEvent = pendingWellnessEvent {
                    windowCoordinator.hide(.wellnessReminder(existingEvent.kind))
                }
                pendingWellnessEvent = nil
            }
            return
        }

        pendingWellnessEvent = event
        if maybeShowContextualHint(.firstWellness, now: now) {
            pendingWellnessEvent = nil
        } else {
            switch event.deliveryStyle {
            case .panel:
                windowCoordinator.show(.wellnessReminder(event.kind))
            case .notification:
                scheduleNotification(title: event.title, body: event.body)
            }
        }
        wellnessReminderEngine.markDelivered(event.kind, at: now)
    }

    @discardableResult
    private func maybeShowContextualHint(_ kind: HintKind, now: Date) -> Bool {
        guard let hint = contextualEducationEngine.nextHint(
            for: kind,
            context: ContextualEducationContext(
                isSetupComplete: onboardingState.hasCompletedStarterSetup,
                now: now
            )
        ) else {
            return false
        }

        windowCoordinator.show(.contextualHint(hint.kind))
        contextualEducationEngine.markSeen(hint.kind)
        settings.contextualEducationState = contextualEducationEngine.state
        persistSettingsSnapshot()
        return true
    }

    private func reconcileTimerWindows() {
        if let activeBreak = appState.activeBreak {
            if !windowCoordinator.isBreakOverlayVisible || windowCoordinator.currentBreakOverlaySessionID != activeBreak.id {
                logger.debug("Showing break overlay session=\(activeBreak.id.uuidString, privacy: .public)")
                windowCoordinator.showBreakOverlay(session: activeBreak)
            }

            if windowCoordinator.isBreakReminderVisible {
                logger.debug("Hiding break reminder because break is active")
                windowCoordinator.hideBreakReminder()
            }
            return
        }

        if windowCoordinator.isBreakOverlayVisible {
            logger.debug("Hiding break overlay because there is no active break")
            windowCoordinator.hideBreakOverlay()
        }

        guard !appState.isPaused,
              appState.reminder != nil,
              let nextBreakDate = appState.nextBreakDate
        else {
            if windowCoordinator.isBreakReminderVisible {
                logger.debug("Hiding break reminder because reminder state is inactive")
                windowCoordinator.hideBreakReminder()
            }
            return
        }

        if !windowCoordinator.isBreakReminderVisible || windowCoordinator.currentBreakReminderDate != nextBreakDate {
            logger.debug("Showing break reminder for nextBreakDate=\(nextBreakDate.formatted(date: .omitted, time: .standard), privacy: .public)")
            windowCoordinator.showBreakReminder(nextBreakDate: nextBreakDate)
        }
    }

    private func logTimerState(snapshot: BreakScheduler.Snapshot, now: Date, idleSeconds: TimeInterval) {
        let nextBreakDescription = snapshot.state.nextBreakDate?.formatted(date: .omitted, time: .standard) ?? "nil"
        let activeBreakDescription = snapshot.state.activeBreak.map {
            "\($0.kind.rawValue):\($0.scheduledEnd.formatted(date: .omitted, time: .standard))"
        } ?? "nil"
        let reminderVisible = self.windowCoordinator.isBreakReminderVisible
        let overlayVisible = self.windowCoordinator.isBreakOverlayVisible
        logger.debug(
            "tick now=\(now.formatted(date: .omitted, time: .standard), privacy: .public) nextBreak=\(nextBreakDescription, privacy: .public) activeBreak=\(activeBreakDescription, privacy: .public) paused=\(snapshot.state.isPaused, privacy: .public) idleSeconds=\(idleSeconds, privacy: .public) reminderVisible=\(reminderVisible, privacy: .public) overlayVisible=\(overlayVisible, privacy: .public)"
        )
    }

    private func persistSettingsSnapshot() {
        do {
            let persistedSettings = (try? settingsStore.load()) ?? settings.migrated()
            var updatedSettings = persistedSettings
            updatedSettings.contextualEducationState = settings.contextualEducationState
            try settingsStore.save(updatedSettings)
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
        }
    }

    private static func setupState(now: Date) -> AppState {
        AppState(
            now: now,
            nextBreakDate: nil,
            activeBreak: nil,
            reminder: nil,
            isPaused: false,
            pauseReason: nil,
            statusText: "Finish setup to start your break rhythm"
        )
    }

    private func configurePauseProviders() {
        scheduler.setPauseProviders(
            Self.makePauseProviders(
                settings: settings,
                fullscreenPauseProvider: fullscreenPauseProvider
            )
        )
    }

    private static func makePauseProviders(
        settings: AppSettings,
        fullscreenPauseProvider: FullscreenPauseConditionProvider
    ) -> [any PauseConditionProvider] {
        settings.smartPauseSettings.pauseDuringFullscreenFocus ? [fullscreenPauseProvider] : []
    }
}
