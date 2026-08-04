# TestStepHUD Contributor Guide

## Project goal

TestStepHUD makes recorded XCUITest runs understandable by drawing the current
test step in a non-interactive HUD over the application under test.

The repository is complete only when the Swift package, protocol unit tests,
demo application, and demo UI test all build, and the UI test result bundle
contains a video where each step is readable.

## Language and style

- Write documentation, public API comments, test names, and user-facing demo
  copy in English.
- Keep the public API small and source-compatible whenever practical.
- Do not add third-party runtime dependencies.
- Prefer explicit error handling over logging. Never log session tokens or
  complete wire payloads.

## Architecture invariants

- `TestStepHUD` is the app-side SwiftPM product.
- `TestStepHUDTestSupport` is the UI-test-side SwiftPM product.
- `TestStepHUDProtocol` is an internal shared target.
- The UI-test runner owns an ephemeral `NWListener` bound to IPv4 loopback.
- The app connects back to that listener using launch-environment metadata.
- The transport uses a versioned, length-prefixed JSON protocol and a random
  per-session token.
- App-side installation is a strict no-op without valid namespaced launch
  environment values.
- A `show` acknowledgement is sent only after the label has been updated and
  the HUD hierarchy has completed layout on the main thread.
- `TestStepHUDTestSupport` intercepts supported `XCUIElement` and
  `XCUICoordinate` interactions only while a HUD session is active. It presents
  the interaction geometry first and always invokes the original XCUITest
  implementation afterward.
- Only one HUD session may be active per UI-test process. A second activation
  must fail explicitly rather than silently replacing interaction routing.
- Element `tap()` interception is required. Additional selectors degrade
  independently when an XCTest runtime does not expose the expected ABI.
- Typing visualization transmits only the target frame and interaction kind.
  Never transmit, store, or log the typed string.
- Element-following is app-side configuration. Each new highlight restarts the
  five-second idle timer; expiry returns the step card to its configured home
  position.
- New step cards pulse by default. Pulse animation must remain independent of
  the outer card translation used by element-following.
- While a HUD session is active, the test-side product observes recorded
  `XCTIssue` values without swizzling assertion functions. Failure presentation
  is best-effort and must never create another XCTest issue.
- Failure cards use the existing app-side HUD window, replace other transient
  visuals, acknowledge only after main-thread layout, and remain visible long
  enough to be readable when XCTest stops the test after a failure.
- The HUD uses a separate, non-key `UIWindow`, ignores all hit testing, and is
  hidden from accessibility.

Do not replace the transport with URL schemes, App Groups, pasteboard,
accessibility commands, private API, fixed ports, or an externally reachable
listener.

## Repository layout

```text
Sources/
  TestStepHUD/             App runtime and HUD window
  TestStepHUDTestSupport/  XCUITest API and listener
  TestStepHUDProtocol/     Shared wire protocol and framing
Tests/
  TestStepHUDProtocolTests/ Protocol and test-transport coverage
Examples/TestStepHUDDemo/  Demo app, UI tests, and Xcode project
Scripts/                   Reproducible validation helpers
Artifacts/                 Local generated results; ignored by Git
```

## Validation

Use an available iOS Simulator. The standard checks are:

```sh
swift package describe
./Scripts/test-package.sh
./Scripts/test-demo.sh
./Scripts/export-ui-test-videos.sh Artifacts/TestStepHUDDemo.xcresult
```

When changing framing, authentication, acknowledgement routing, lifecycle, or
window behavior, add or update focused tests. Do not weaken timeouts merely to
hide a race.

## Demo expectations

The demo UI test must use the same public API documented in the README:

```swift
let hud = try app.launchWithTestStepHUD()
try hud.step("Readable action") {
    app.buttons["Action"].tap()
}
```

Keep deliberate short pauses in the demo flow. They are part of the visual
acceptance fixture and make the step text readable in the recorded result.
Keep plain element and coordinate interaction calls so the demo verifies the
transparent interceptor without wrapper APIs.
