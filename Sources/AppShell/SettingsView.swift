import Core
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var draft: AppSettings

    init(model: AppModel) {
        self.model = model
        _draft = State(initialValue: model.settings)
    }

    var body: some View {
        Form {
            Section("Break Rhythm") {
                Stepper(value: $draft.breakSettings.workInterval, in: 10 * 60...90 * 60, step: 5 * 60) {
                    labeledValue("Work duration", value: "\(Int(draft.breakSettings.workInterval / 60)) min")
                }

                Stepper(value: $draft.breakSettings.microBreakDuration, in: 10...120, step: 5) {
                    labeledValue("Break duration", value: "\(Int(draft.breakSettings.microBreakDuration)) sec")
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $draft.scheduleSettings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 420, minHeight: 240)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Revert") {
                    draft = model.settings
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    model.settings = draft
                    model.saveSettings()
                }
            }
        }
        .onReceive(model.$settings) { newSettings in
            draft = newSettings
        }
    }

    private func labeledValue(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
