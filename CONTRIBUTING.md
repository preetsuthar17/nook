# Contributing

Thanks for helping build nook.

## Local setup

1. Install a current Swift toolchain and full Xcode.
2. Clone the repo and open the package in Xcode, or use SwiftPM from Terminal.
3. Run `swift test` before opening a pull request.

## Contribution guidelines

- Keep the product native to macOS.
- Preserve the privacy-first, local-only posture.
- Prefer testable logic in `Core` over view-driven state.
- Avoid introducing telemetry, accounts, or remote dependencies without a design discussion.

## Pull requests

- Include a short summary of the user-facing change.
- Add or update tests for scheduler and persistence behavior.
- Attach screenshots or recordings for UI changes.
