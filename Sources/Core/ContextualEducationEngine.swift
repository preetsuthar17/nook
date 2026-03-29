import Foundation

public struct ContextualEducationContext: Sendable {
    public var isSetupComplete: Bool
    public var now: Date

    public init(isSetupComplete: Bool, now: Date = Date()) {
        self.isSetupComplete = isSetupComplete
        self.now = now
    }
}

public final class ContextualEducationEngine: @unchecked Sendable {
    public private(set) var state: ContextualEducationState

    public init(state: ContextualEducationState = .default) {
        self.state = state
    }

    public func updateState(_ state: ContextualEducationState) {
        self.state = state
    }

    public func nextHint(for kind: HintKind, context: ContextualEducationContext) -> HintEvent? {
        guard context.isSetupComplete else { return nil }

        switch kind {
        case .firstBreak:
            guard !state.hasSeenFirstBreakHint else { return nil }
        case .firstWellness:
            guard !state.hasSeenFirstWellnessHint else { return nil }
        }

        return HintEvent(
            kind: kind,
            title: kind.title,
            body: kind.body,
            delivery: .panel
        )
    }

    public func markSeen(_ kind: HintKind) {
        switch kind {
        case .firstBreak:
            state.hasSeenFirstBreakHint = true
        case .firstWellness:
            state.hasSeenFirstWellnessHint = true
        }
    }

    public func reset() {
        state = .default
    }
}
