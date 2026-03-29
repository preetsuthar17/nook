import Core
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case duration = "Duration"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .duration: "clock"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 200)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsPane(model: model)
            case .duration:
                DurationSettingsPane(model: model)
            }
        }
        .toolbar(content: { ToolbarItem { EmptyView() } })
        .toolbar(.hidden)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { model.settings.scheduleSettings.launchAtLogin },
                set: { newValue in
                    model.settings.scheduleSettings.launchAtLogin = newValue
                    model.saveSettings()
                }
            ))
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

private struct DurationSettingsPane: View {
    @ObservedObject var model: AppModel

    private var workMinutes: Binding<Double> {
        Binding(
            get: { model.settings.breakSettings.workInterval / 60 },
            set: { newValue in
                model.settings.breakSettings.workInterval = newValue * 60
                model.saveSettings()
            }
        )
    }

    private var breakSeconds: Binding<Double> {
        Binding(
            get: { model.settings.breakSettings.microBreakDuration },
            set: { newValue in
                model.settings.breakSettings.microBreakDuration = newValue
                model.saveSettings()
            }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Work duration")
                        Spacer()
                        Text("\(Int(workMinutes.wrappedValue)) min")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: workMinutes, in: 10...90, step: 5)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Break duration")
                        Spacer()
                        Text("\(Int(breakSeconds.wrappedValue)) sec")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: breakSeconds, in: 10...120, step: 5)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Duration")
    }
}
