import AppKit
import NookKit
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: AppModel
    var dismiss: () -> Void

    var body: some View {
        if model.menuBarMode == .setup {
            setupMenu
        } else {
            activeMenu
        }
    }

    private var setupMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Start with the recommended setup or adjust it before you begin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Start Using Nook", systemImage: "play.fill") {
                model.dismissStarterSetupWithDefaults()
                dismiss()
            }

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Quit", systemImage: "power", isLast: true) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
    }

    private var activeMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.appState.statusText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Start Break Now", systemImage: "cup.and.saucer") {
                model.startBreakNow()
                dismiss()
            }

            PopoverMenuRow(title: "Postpone 5 Minutes", systemImage: "clock.arrow.circlepath") {
                model.postpone(minutes: 5)
                dismiss()
            }

            PopoverMenuRow(title: "Postpone 15 Minutes", systemImage: "clock.arrow.circlepath") {
                model.postpone(minutes: 15)
                dismiss()
            }

            PopoverMenuRow(
                title: model.appState.isPaused ? "Resume Reminders" : "Pause Reminders",
                systemImage: model.appState.isPaused ? "play.circle" : "pause.circle"
            ) {
                model.pauseOrResume()
                dismiss()
            }

            if model.appState.activeBreak != nil {
                PopoverMenuRow(title: "Skip Current Break", systemImage: "forward.end") {
                    model.skipCurrentBreak()
                    dismiss()
                }

                PopoverMenuRow(title: "End Break Early", systemImage: "stop.circle") {
                    model.endBreakEarly()
                    dismiss()
                }
            }

            PopoverMenuRow(title: "Open Settings", systemImage: "gearshape") {
                if #available(macOS 14, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Quit", systemImage: "power", isLast: true) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct PopoverMenuRow: View {
    let title: String
    let systemImage: String?
    let isLast: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(title: String, systemImage: String? = nil, isLast: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLast = isLast
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 20)
                }
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? .white : .primary)
        .background(isHovered ? Color(nsColor: NSColor(red: 0.075, green: 0.376, blue: 0.702, alpha: 1.0)) : .clear)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: isLast ? 12 : 4, bottomTrailingRadius: isLast ? 12 : 4, topTrailingRadius: 4))
        .onHover { isHovered = $0 }
    }
}
