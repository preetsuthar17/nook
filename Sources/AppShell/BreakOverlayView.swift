import Core
import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var model: AppModel
    let session: BreakSession
    @State private var contentVisible = false

    private var remainingText: String {
        model.appState.countdownText ?? "00:00"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)

            VStack(spacing: 20) {
                Text(session.kind.title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Text(session.message)
                    .font(.system(size: 42, weight: .semibold))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 600)

                Text("Break ends in \(remainingText)")
                    .font(.system(size: 17, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 14) {
                    Button("End Early") {
                        model.endBreakEarly()
                    }
                    .buttonStyle(OverlayButtonStyle(filled: true))

                    Button("Skip") {
                        model.skipCurrentBreak()
                    }
                    .buttonStyle(OverlayButtonStyle(filled: false))
                }
                .padding(.top, 8)
            }
            .offset(y: contentVisible ? 0 : 20)
            .opacity(contentVisible ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.08)) {
                contentVisible = true
            }
        }
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(filled ? .black : .white.opacity(0.85))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2, bounce: 0), value: configuration.isPressed)
            .pointerCursor()
    }
}
