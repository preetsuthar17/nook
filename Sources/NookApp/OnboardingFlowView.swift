import ConfettiSwiftUI
import SwiftUI

enum OnboardingStep: Equatable {
    case welcome
    case durationSetup
    case complete
}

struct OnboardingFlowView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var welcomeVisible = false
    @State private var setupVisible = false
    @State private var completeVisible = false
    @State private var confettiTrigger = 0
    @State private var workMinutes: Int = 30
    @State private var breakSeconds: Int = 45
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinish: (TimeInterval, TimeInterval) -> Void

    private let workOptions = [15, 30, 45, 60]
    private let breakOptions = [15, 30, 45, 60]

    private var enterSpring: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(duration: 0.45, bounce: 0.08)
    }
    private var exitCurve: Animation {
        reduceMotion ? .linear(duration: 0) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.25)
    }
    private var chipAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(duration: 0.25, bounce: 0)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)

            ZStack {
                if step == .welcome {
                    welcomeContent
                        .offset(y: welcomeVisible ? 0 : 20)
                        .opacity(welcomeVisible ? 1 : 0)
                }

                if step == .durationSetup {
                    durationSetupContent
                        .offset(y: setupVisible ? 0 : 24)
                        .opacity(setupVisible ? 1 : 0)
                }

                if step == .complete {
                    completeContent
                        .offset(y: completeVisible ? 0 : 20)
                        .opacity(completeVisible ? 1 : 0)
                        .confettiCannon(
                            counter: $confettiTrigger,
                            num: 50,
                            colors: [.white, .white.opacity(0.8), .white.opacity(0.6)],
                            confettiSize: 8,
                            rainHeight: 600,
                            radius: 400,
                            repetitions: 2,
                            repetitionInterval: 0.5
                        )
                }
            }
        }
        .ignoresSafeArea()
        .task {
            withAnimation(enterSpring) {
                welcomeVisible = true
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(exitCurve) {
                welcomeVisible = false
            }
            try? await Task.sleep(for: .milliseconds(300))
            step = .durationSetup
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(enterSpring) {
                setupVisible = true
            }
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            pauseIcon(size: 64, cornerRadius: 16, barWidth: 7, barHeight: 26, barSpacing: 8)

            Text("Find your pause.")
                .font(.system(size: 48, weight: .semibold))
                .tracking(-1)
                .foregroundStyle(.white)
        }
    }

    private var durationSetupContent: some View {
        VStack(spacing: 0) {
            card
                .frame(maxWidth: 580)

            HStack {
                Spacer()
                Button(action: handleFinishSetup) {
                    Text("Finish setup")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .pointerCursor()
            }
            .frame(maxWidth: 580)
            .padding(.top, 20)
        }
    }

    private func handleFinishSetup() {
        Task { @MainActor in
            withAnimation(exitCurve) {
                setupVisible = false
            }
            try? await Task.sleep(for: .milliseconds(300))
            step = .complete
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(enterSpring) {
                completeVisible = true
            }
            try? await Task.sleep(for: .milliseconds(200))
            confettiTrigger += 1
            try? await Task.sleep(for: .seconds(2.5))
            onFinish(
                TimeInterval(workMinutes * 60),
                TimeInterval(breakSeconds)
            )
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                pauseIcon(size: 44, cornerRadius: 10, barWidth: 6, barHeight: 20, barSpacing: 6)

                Text("Work/break duration setup")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Work mode duration")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(workOptions, id: \.self) { minutes in
                            chip(
                                label: "\(minutes) min",
                                isSelected: workMinutes == minutes
                            ) {
                                withAnimation(chipAnimation) {
                                    workMinutes = minutes
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Break duration")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(breakOptions, id: \.self) { seconds in
                            chip(
                                label: "\(seconds) sec",
                                isSelected: breakSeconds == seconds
                            ) {
                                withAnimation(chipAnimation) {
                                    breakSeconds = seconds
                                }
                            }
                        }
                    }
                }
            }

            Button {
                Task { @MainActor in
                    withAnimation(exitCurve) {
                        setupVisible = false
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                    step = .welcome
                    welcomeVisible = false
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(enterSpring) {
                        welcomeVisible = true
                    }
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation(exitCurve) {
                        welcomeVisible = false
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                    step = .durationSetup
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(enterSpring) {
                        setupVisible = true
                    }
                }
            } label: {
                Text("Back")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .modifier(GlassChipModifier(cornerRadius: 22))
            }
            .buttonStyle(ScaleButtonStyle())
            .pointerCursor()
        }
        .padding(32)
        .modifier(GlassCardModifier(cornerRadius: 28))
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white)
                            .shadow(color: .white.opacity(0.15), radius: 8)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .modifier(GlassChipModifier(cornerRadius: 14))
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .pointerCursor()
    }

    private var completeContent: some View {
        VStack(spacing: 24) {
            pauseIcon(size: 64, cornerRadius: 16, barWidth: 7, barHeight: 26, barSpacing: 8)

            Text("You're all set!")
                .font(.system(size: 48, weight: .semibold))
                .tracking(-1)
                .foregroundStyle(.white)
        }
    }

    private func pauseIcon(size: CGFloat, cornerRadius: CGFloat, barWidth: CGFloat, barHeight: CGFloat, barSpacing: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white)
            .frame(width: size, height: size)
            .overlay {
                HStack(spacing: barSpacing) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .frame(width: barWidth, height: barHeight)
                    RoundedRectangle(cornerRadius: 2.5)
                        .frame(width: barWidth, height: barHeight)
                }
                .foregroundStyle(.black)
            }
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
#if compiler(>=6.3)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            fallbackCard(content: content)
        }
#else
        fallbackCard(content: content)
#endif
    }

    private func fallbackCard(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}

private struct GlassChipModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
#if compiler(>=6.3)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            fallbackChip(content: content)
        }
#else
        fallbackChip(content: content)
#endif
    }

    private func fallbackChip(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2, bounce: 0), value: configuration.isPressed)
    }
}

private struct PointerCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}
