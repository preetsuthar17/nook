import Foundation
import Core
import XCTest

final class SettingsStoreTests: XCTestCase {
    func testDefaultFileURLUsesLowercaseDirectory() {
        XCTAssertEqual(SettingsStore.defaultFileURL.lastPathComponent, "settings.json")
        XCTAssertEqual(SettingsStore.defaultFileURL.deletingLastPathComponent().lastPathComponent, "nook")
    }

    func testSettingsStorePersistsAndLoadsMigratedSettings() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: fileURL)

        var settings = AppSettings.default
        settings.schemaVersion = 0
        try store.save(settings)

        let loaded = try store.load()

        XCTAssertEqual(loaded.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(loaded.breakSettings, settings.breakSettings)
        XCTAssertEqual(loaded.smartPauseSettings, settings.smartPauseSettings)
    }

    func testMissingSmartPauseSettingsUseMigratedDefaults() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: fileURL)
        let legacyJSON = """
        {
          "schemaVersion" : 3,
          "breakSettings" : {
            "allowEarlyEnd" : true,
            "backgroundStyle" : "dawn",
            "customMessages" : [
              "Look across the room and relax your focus."
            ],
            "longBreakCadence" : 3,
            "longBreakDuration" : 300,
            "longBreaksEnabled" : true,
            "microBreakDuration" : 20,
            "reminderLeadTime" : 60,
            "selectedSound" : "breeze",
            "skipPolicy" : "balanced",
            "workInterval" : 1200
          },
          "contextualEducationState" : {
            "hasSeenFirstBreakHint" : true,
            "hasSeenFirstWellnessHint" : true
          },
          "onboardingState" : {
            "hasCompletedStarterSetup" : true
          },
          "scheduleSettings" : {
            "idleResetThreshold" : 300,
            "launchAtLogin" : true,
            "officeHours" : []
          },
          "wellnessSettings" : {
            "blink" : {
              "deliveryStyle" : "panel",
              "interval" : 600,
              "isEnabled" : false
            },
            "posture" : {
              "deliveryStyle" : "panel",
              "interval" : 1800,
              "isEnabled" : false
            }
          }
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let legacyData = legacyJSON.data(using: .utf8) else {
            XCTFail("Expected legacy JSON data")
            return
        }
        try legacyData.write(to: fileURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertFalse(loaded.smartPauseSettings.pauseDuringFullscreenFocus)
    }

    func testLoadMigratesFromLegacyFileLocationWhenPrimaryFileIsMissing() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let newFileURL = directory
            .appendingPathComponent("current", isDirectory: true)
            .appendingPathComponent("nook", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
        let legacyFileURL = directory
            .appendingPathComponent("legacy", isDirectory: true)
            .appendingPathComponent("Nook", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)

        try FileManager.default.createDirectory(
            at: legacyFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var settings = AppSettings.default
        settings.breakSettings.workInterval = 45 * 60
        let legacyData = try JSONEncoder().encode(settings)
        try legacyData.write(to: legacyFileURL)

        let store = SettingsStore(fileURL: newFileURL, legacyFileURL: legacyFileURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded.breakSettings.workInterval, 45 * 60)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyFileURL.path))
    }

    func testLoadDoesNotOverwriteExistingPrimaryFileDuringLegacyMigration() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let newFileURL = directory
            .appendingPathComponent("current", isDirectory: true)
            .appendingPathComponent("nook", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
        let legacyFileURL = directory
            .appendingPathComponent("legacy", isDirectory: true)
            .appendingPathComponent("Nook", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)

        var primarySettings = AppSettings.default
        primarySettings.breakSettings.workInterval = 20 * 60
        try FileManager.default.createDirectory(
            at: newFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(primarySettings).write(to: newFileURL)

        var legacySettings = AppSettings.default
        legacySettings.breakSettings.workInterval = 55 * 60
        try FileManager.default.createDirectory(
            at: legacyFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(legacySettings).write(to: legacyFileURL)

        let store = SettingsStore(fileURL: newFileURL, legacyFileURL: legacyFileURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded.breakSettings.workInterval, 20 * 60)
    }
}
