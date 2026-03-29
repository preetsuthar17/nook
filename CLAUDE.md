# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is nook?

A privacy-first, open-source macOS menu bar app that reminds users to take screen breaks. All data stays on-device — no accounts, telemetry, or cloud syncing. Built with SwiftUI as a native MenuBarExtra.

## Build Commands

```bash
swift build          # Build the package
swift test           # Run all tests
swift run            # Run the app
swift test --filter CoreTests.BreakSchedulerTests      # Run a single test class
swift test --filter CoreTests.BreakSchedulerTests/testBreakInitiatesAfterWorkInterval  # Single test
```

Environment: `NOOK_FORCE_ONBOARDING=1 swift run` to force the onboarding flow during development.

## Architecture

**Two-target Swift Package** (Swift 6 strict concurrency, macOS 13+):

- **Core** (library) — Pure business logic with no UI. All schedulers, engines, models, and persistence live here. Prefer adding logic here over AppShell for testability.
- **AppShell** (executable) — SwiftUI shell, views, and window coordination. Depends on Core.

**Key components and data flow:**

- `AppModel` (@MainActor) is the single source of truth. It orchestrates all engines via a 1Hz timer tick and system wake events.
- `BreakScheduler` is a state machine managing break timing, reminders, skip policies, postpone, idle reset, and office hours. Returns immutable `Snapshot` structs describing state transitions.
- `SettingsStore` persists `AppSettings` as versioned JSON to `~/Library/Application Support/nook/settings.json` and migrates legacy data from `~/Library/Application Support/Nook/settings.json` on load.
- `AppWindowCoordinator` dispatches all transient windows (reminder panels, break overlays, wellness reminders, hints) and prevents stacking conflicts.
- `ActivityMonitor` detects idle time via `CGEventSource`.
- `WellnessReminderEngine` and `ContextualEducationEngine` run independently from the break scheduler.

## Contribution Guidelines

- Keep everything native macOS — no Electron, no cross-platform abstractions.
- Preserve privacy-first, local-only posture. No network calls, remote dependencies, or telemetry.
- Prefer testable Core logic over view-driven state.
- PRs need: user-facing summary, tests for logic changes, screenshots for UI changes.

## CI

GitHub Actions runs `swift test` on macOS 15 with latest Xcode on pushes to main and PRs.
