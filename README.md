<div align="center">

# TestStepHUD

**Make every XCUITest recording explain itself.**

[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138.svg)](https://swift.org)
[![iOS 16+](https://img.shields.io/badge/iOS-16%2B-000000.svg)](https://developer.apple.com/ios/)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://www.swift.org/package-manager/)
[![GitHub release](https://img.shields.io/github/v/release/kei-sidorov/TestStepHUD?sort=semver)](https://github.com/kei-sidorov/TestStepHUD/releases)
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<a href="Docs/Assets/teststephud-demo.mp4">
  <img
    src="Docs/Assets/teststephud-demo.webp"
    width="360"
    alt="TestStepHUD visualizing typing, swipe, long press, drag, coordinate tap, and double tap in an XCUITest recording"
  >
</a>

<sub>
Typing, swipe, long press, drag, coordinate tap, and double tap.
<a href="Docs/Assets/teststephud-demo.mp4">Watch the MP4 demo.</a>
</sub>

</div>

TestStepHUD adds a readable, non-interactive HUD to recorded XCUITest runs. A
test names the current step, the app displays it, and the action begins only
after the HUD is on screen.

Regular XCUITest calls need no wrappers. Taps flash their target, swipes draw a
directional arrow, typing marks the input, and drags show their path. The
result is a recording that communicates both **what the test expects** and
**where it interacts**.

## Why TestStepHUD?

- **Readable test intent.** Step text remains visible while the test acts.
- **Test-case introductions.** Recordings can open with a centered title and
  the scenario steps.
- **Visible interactions.** Common element and coordinate actions are
  visualized automatically.
- **Synchronized recordings.** The test waits for app-side layout before
  continuing.
- **Zero production behavior.** `TestStepHUD.install()` is a strict no-op
  outside an authenticated HUD test session.
- **Safe overlay.** The HUD never becomes key, never handles touches, and is
  hidden from accessibility.
- **No service dependencies.** No URL schemes, App Groups, entitlements,
  fixed ports, or third-party runtime packages.

## Requirements

- iOS 16 or later
- Xcode 15 or later
- Swift 5.9 or later
- Swift Package Manager

The current test matrix uses Xcode 26.4.1 with iOS 16.0 and iOS 26.1
Simulators. See [Compatibility](#compatibility) for details.

## Installation

### Xcode

In **File → Add Package Dependencies**, enter:

```text
https://github.com/kei-sidorov/TestStepHUD
```

Link the products to different targets:

| Product | Target |
| --- | --- |
| `TestStepHUD` | Application |
| `TestStepHUDTestSupport` | UI tests |

### Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/kei-sidorov/TestStepHUD.git",
        from: "0.1.0"
    )
]
```

Use `TestStepHUD` only from the application target and
`TestStepHUDTestSupport` only from the UI-test target.

## Quick start

### 1. Install the app-side receiver

Call `install()` once during application launch:

```swift
import TestStepHUD

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [
        UIApplication.LaunchOptionsKey: Any
    ]?
) -> Bool {
    TestStepHUD.install()
    return true
}
```

It is safe to leave this line in every build configuration. Without valid
TestStepHUD launch metadata, it creates no connection, window, or observers.

### 2. Describe the UI-test flow

```swift
import XCTest
import TestStepHUDTestSupport

final class CheckoutUITests: XCTestCase {
    @MainActor
    func testCheckout() {
        let app = XCUIApplication()
        let hud = app.launchWithTestStepHUD()

        addTeardownBlock {
            hud.cancel()
        }

        hud.testCase(
            "An active purchase does not show the paywall",
            steps: [
                "Configure the application for the purchase scenario",
                "Activate the subscription",
                "Tap Continue",
                "Verify that the paywall is not shown"
            ]
        )

        hud.step("Find the Continue button")
        XCTAssertTrue(
            app.buttons["continue"].waitForExistence(timeout: 5)
        )

        hud.step("Tap Continue")
        app.buttons["continue"].tap()

        hud.step("Verify the confirmation")
        XCTAssertTrue(
            app.staticTexts["Order confirmed"].exists
        )

        hud.hide()
    }
}
```

`testCase(_:steps:)` shows a separate centered card and keeps it visible for
the configured recording duration. In the default fast profile it is a strict
no-op, so adding an introduction does not slow automated test runs.

`step(_:)` sends the new step text and waits until the HUD has updated and
completed main-thread layout. It can be inserted before an existing action or
assertion without moving that code into a closure.

The closure overload remains available when an XCTest activity is useful:

```swift
hud.step("Tap Continue") {
    app.buttons["continue"].tap()
}
```

`step(_:action:)`:

1. Sends the step text to the application.
2. Waits until the HUD has updated and completed main-thread layout.
3. Runs the closure inside an `XCTContext` activity with the same name.

HUD setup and presentation are best-effort: missing app integration, a closed
connection, or a command timeout never fails the UI test or prevents the
original XCUITest action. `startupError` and `isAvailable` can be inspected
when HUD availability matters to diagnostics.

### System UI

Hide the overlay before presenting system-managed UI such as a document picker,
share sheet, or permission alert. If the HUD session is finished, `cancel()`
does this for you: it sends an acknowledged `hide` command before disconnecting
the UI-test transport, so a separate `hide()` call is unnecessary.

```swift
hud.show("Choose a folder")
hud.cancel()

// The app can now present UIDocumentPickerViewController.
```

When the test needs the HUD again after the system dialog, keep the session
active and use `hide()` before the dialog instead. You can later call `show()`
or `step(_:)` on the same session.

## Automatic interaction visualization

After `launchWithTestStepHUD()` returns, TestStepHUD observes ordinary
XCUITest calls:

| XCUITest action | Recording visual |
| --- | --- |
| `tap()` | Filled rounded rectangle with two alpha flashes |
| `doubleTap()` | Two quick pulses around the element or coordinate |
| `swipeUp/Down/Left/Right()` | Directional arrow |
| `typeText(_:)` | Highlighted input frame and `Typing…` badge |
| `press(forDuration:)` | Circular hold-progress indicator |
| `press(forDuration:thenDragTo:)` | Arrow from source to destination |
| Coordinate tap, double tap, press, and drag | Ripple, pulse, hold indicator, or path |

The visual appears before the original XCTest implementation runs and fades
quickly afterward. If visualization fails, TestStepHUD still performs the
original action without recording an XCTest failure.

Typed content is never transmitted to the application. A typing visual
contains only the interaction kind and normalized target frame.

## Fast and visual runs

`launchWithTestStepHUD()` reads a presentation profile from the UI-test
process environment. The default is **fast**:

- `testCase(_:steps:)` is skipped.
- Automatic interaction visuals add no artificial delay.
- Regular `show`, `step`, and interaction commands remain synchronized with
  the application.

Enable recording-friendly pauses in an Xcode Test Plan, scheme environment,
or the environment that launches `xcodebuild`:

```sh
TESTSTEPHUD_MODE=visual xcodebuild test ...
```

| Environment variable | Fast/default | Visual default | Behavior |
| --- | --- | --- | --- |
| `TESTSTEPHUD_MODE` | unset or `fast` | `visual` | Only `visual` enables deliberate pauses. |
| `TESTSTEPHUD_CASE_DURATION` | `0` | `4` seconds | Time the centered test-case card remains visible; clamped to `0...60`. |
| `TESTSTEPHUD_INTERACTION_DELAY` | `0` | `0.5` seconds | Lead-in before the original intercepted interaction; clamped to `0...5`. |

Profiles can also be selected explicitly in code:

```swift
let fastHUD = app.launchWithTestStepHUD(presentation: .fast)

let visualHUD = app.launchWithTestStepHUD(
    presentation: .visual(
        testCaseDuration: 5,
        interactionDelay: 0.6
    )
)
```

The historical overload remains source-compatible:

```swift
let hud = app.launchWithTestStepHUD(tapHighlightDelay: 0.35)
```

That overload configures only the interaction delay and leaves test-case
introductions disabled. `timeout` still defaults to five seconds and controls
listener startup, app handshake, and each acknowledged HUD command.

## App-side appearance and behavior

The default step HUD is a high-contrast translucent card at the top safe area
with centered, 17-point semibold text and a subtle pulse on every new step.
The separate test-case card always appears in the center and uses the same app-
side colors and base font size.

Pass `TestStepHUD.Configuration` to `install()` during app launch. This is the
single place that controls the card, interaction visuals, home position, and
element-following behavior for the HUD session:

```swift
TestStepHUD.install(
    configuration: .init(
        backgroundColor: .init(rgb: 0x123B5D),
        backgroundOpacity: 0.84,
        position: .bottom,
        fontSize: 19,
        textAlignment: .leading,
        highlightColor: .init(rgb: 0xFFD166),
        highlightOpacity: 0.30,
        movesHUDToHighlightedElement: true,
        pulsesHUDOnStepChange: true
    )
)
```

| Option | Default | Values and behavior |
| --- | --- | --- |
| `backgroundColor` | `.ink` (`#151B2B`) | Base color of the step card. Use a built-in color or create a custom RGB color. |
| `backgroundOpacity` | `0.9` | Card opacity, clamped to `0...1`. |
| `position` | `.top` | Home position inside the safe area: `.top`, `.center`, or `.bottom`. See [Card position](#card-position). |
| `fontSize` | `17` | Semibold text size, clamped to `11...42` points. Dynamic Type scaling is supported up to 42 points. |
| `textAlignment` | `.center` | Multiline label alignment: `.leading`, `.center`, or `.trailing`. |
| `highlightColor` | `.highlight` (`#FFD166`) | Color used for tap highlights, strokes, glows, gesture paths, arrows, ripples, and interaction badges. |
| `highlightOpacity` | `0.3` | Fill opacity for interaction highlights, clamped to `0...1`; strokes and paths keep the solid `highlightColor`. |
| `movesHUDToHighlightedElement` | `false` | When `true`, temporarily moves the step card beside the latest element or coordinate interaction. See [Following interactions](#following-interactions). |
| `pulsesHUDOnStepChange` | `true` | When `true`, scales and fades the card surface twice whenever `step(_:)`, `step(_:action:)`, or `show(_:)` presents new text. |

### Custom colors

`TestStepHUD.Color` has three presets and two public initializers:

```swift
let preset: TestStepHUD.Color = .highlight
let hex = TestStepHUD.Color(rgb: 0x4F46E5)
let components = TestStepHUD.Color(
    red: 79.0 / 255.0,
    green: 70.0 / 255.0,
    blue: 229.0 / 255.0
)
```

| Preset | RGB value | Intended use |
| --- | --- | --- |
| `.ink` | `#151B2B` | Default card background |
| `.white` | `#FFFFFF` | Light custom surfaces |
| `.highlight` | `#FFD166` | Default interaction accent |

Opacity is configured separately with `backgroundOpacity` and
`highlightOpacity`. Step text is always white.

### Card position

`position` defines the card's home position, not the location of interaction
visuals. The card is horizontally centered, limited to 90% of the safe-area
width, and grows vertically for multiline text.

| Position | Placement |
| --- | --- |
| `.top` | 12 points below the safe area's top edge |
| `.center` | Vertically centered in the safe area |
| `.bottom` | 12 points above the safe area's bottom edge |

If `movesHUDToHighlightedElement` is disabled, the card stays at this home
position until hidden. If following is enabled, `position` is still the place
the card returns to after the follow timer expires.

### Following interactions

With `movesHUDToHighlightedElement: true`, an intercepted element or
coordinate interaction temporarily moves the card near its visual target:

- The card prefers the side that keeps it away from the target: above targets
  in the lower half of the safe area, otherwise below.
- If the preferred side does not fit, it uses the other side or clamps the
  card inside the safe area. The normal gap from the target is 16 points.
- Element interactions follow the visible element frame. Coordinate gestures
  and drags follow the interaction's starting point.
- Every new interaction restarts the five-second idle timer. When the timer
  expires, the card animates back to its configured `position`.
- A new step can pulse while the card is following an element; the pulse and
  the outer card movement use independent animations.

Following changes only the step card position. Highlights, arrows, ripples,
and paths are always drawn at the actual interaction geometry.

## How it works

```text
UI-test runner                            Application under test
─────────────────────────────────────    ─────────────────────────────────
Create ephemeral 127.0.0.1 listener
Generate random session token
Add namespaced launch environment   ───▶ TestStepHUD.install()
                                         Connect back over loopback
Validate token + protocol version   ◀─── Authenticated hello
Send show / interaction command     ───▶ Update non-key HUD UIWindow
Wait for matching UUID ACK          ◀─── ACK after main-thread layout
Execute the original XCTest action
```

Messages use versioned JSON inside four-byte, network-order,
length-prefixed frames. Frames are limited to 64 KiB, and the decoder handles
fragmented and coalesced TCP reads.

The test runner owns the listener, bound strictly to IPv4 loopback on an
operating-system-selected port. The application only connects back after
receiving namespaced launch metadata and authenticates with a cryptographically
random per-session token.

The app-side HUD uses a separate transparent `UIWindow`:

- It never calls `makeKeyAndVisible()`.
- It returns `nil` from hit testing.
- It hides the complete hierarchy from accessibility.
- It updates only on the main actor.
- It retains pending state until a foreground scene becomes available.

## Security and privacy

- The application never opens a listener.
- The test listener is unreachable outside IPv4 loopback.
- Parallel test processes receive different ephemeral ports and tokens.
- Session tokens and complete wire payloads are never logged.
- Typed strings never cross the transport.
- The application product does not link XCTest or swizzle application code.
- Interaction interception exists only inside the UI-test runner.
- Cancellation closes all candidates, the authenticated connection, pending
  acknowledgements, and the listener.

## Compatibility

| Component | Support |
| --- | --- |
| Deployment target | iOS 16.0+ |
| Package manifest | Swift tools 5.9 |
| Declared toolchain | Xcode 15+ |
| Verified toolchain | Xcode 26.4.1 |
| Verified runtimes | iOS Simulator 16.0 and 26.1 |

The architecture is designed for simulators and physical iOS devices. The
current automated acceptance matrix covers simulators; physical devices, iPad,
landscape, and multiple simultaneously active scenes have not yet been
validated.

Only one HUD session may be active in a UI-test process. A second launch fails
before starting another application.

Element `tap()` is the required baseline interception selector. Additional
gesture selectors are installed only when the XCTest runtime exposes the
expected Objective-C ABI, so an unavailable optional gesture does not disable
the HUD or tap highlighting.

Velocity-specific swipes, pinch, rotation, picker-wheel adjustment, slider
adjustment, hardware keyboard keys, and device-level actions are not currently
visualized.

## Demo and validation

The repository includes a UIKit demo application and three UI-test scenarios:

- Readable step annotations and tap highlighting
- Common automatic interaction visuals
- Concurrent-session rejection

Open
[`Examples/TestStepHUDDemo/TestStepHUDDemo.xcodeproj`](Examples/TestStepHUDDemo/TestStepHUDDemo.xcodeproj)
and run the `TestStepHUDDemo` scheme, or use:

```sh
./Scripts/test-package.sh
./Scripts/test-demo.sh
./Scripts/export-ui-test-videos.sh Artifacts/TestStepHUDDemo.xcresult
```

`test-package.sh` runs protocol and transport unit tests on an iOS Simulator.
`test-demo.sh` runs the full unit and UI-test suite and writes an `.xcresult`.
The export script extracts keep-always screenshots and Xcode screen
recordings.

Use a specific Simulator or result path when needed:

```sh
DESTINATION="platform=iOS Simulator,id=SIMULATOR_UDID" \
RESULT_BUNDLE="/tmp/TestStepHUD.xcresult" \
./Scripts/test-demo.sh
```

Deliberate short pauses in the demo are part of the visual acceptance fixture:
they ensure each step remains readable in the exported recording.

## Contributing

Contributions are welcome. Read [AGENTS.md](AGENTS.md) for the architecture
invariants, repository layout, and required validation commands.

## License

TestStepHUD is available under the [MIT License](LICENSE).
