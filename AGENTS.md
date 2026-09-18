<!-- AGENTS.md — index + rules. Detail lives in agent_docs/. Add rules on failure, remove when redundant. -->

# ApphudSDK (iOS)

Upstream Apphud in-app-subscription SDK: registers a customer, loads placements/paywalls,
purchases through StoreKit 2 (StoreKit 1 is kept only to observe the host app's own
payments and to feed the deprecated `SKProduct` API), uploads signed transactions (JWS)
plus the App Store receipt, tracks attribution and user properties, and renders Rules and
Figma paywall screens in web views. Single SPM target / CocoaPods pod. This checkout is
an unmodified clone of `apphud/ApphudSDK` at tag `4.5.0`; the docs describe that tag.

## Reference docs

| Topic | Doc |
| --- | --- |
| Init/registration flow, identity (userID/deviceID/logout), purchase paths, HTTP + retry, persistence, swizzling, ApphudUI, threading | [agent_docs/architecture.md](agent_docs/architecture.md) |
| Directory layout, where new code goes, naming | [agent_docs/structure.md](agent_docs/structure.md) |

## Tech stack

Swift 5.9 (`swiftLanguageVersions: [.v5]`), iOS 15+ / macOS 13+ / tvOS 16+ / watchOS 9+ /
visionOS 1+ declared identically in `Package.swift` and the podspec. StoreKit only
framework dependency; no third-party packages. Distributed via `Package.swift` and
`ApphudSDK.podspec`. `.swiftlint.yml` exists but nothing runs it. Tests:
`Tests/ApphudUnitTests` (SPM test target, 13 XCTests, pure logic + seams, runs with
`swift test` on macOS), `Examples/ApphudDemoSwift/ApphudSDKTests` (12 StoreKitTest
integration tests with a stubbed backend, hosted by the demo app), and
`Examples/ApphudDemoVisionOS/ApphudSDKTests` (three XCTests against a hard-coded live API key).

## Key commands

```bash
# Build the package (scheme "ApphudSDK" comes from Package.swift)
xcodebuild build -scheme ApphudSDK -destination 'generic/platform=iOS Simulator'

# Unit tests (Tests/ApphudUnitTests, no network or StoreKit needed)
swift test

# Validate the pod
pod lib lint ApphudSDK.podspec

# Demo apps (CocoaPods, pod 'ApphudSDK', :path => '../../'); the ApphudSDKDemo scheme
# runs the StoreKitTest integration suite (stubbed backend, StoreKit.storekit)
cd Examples/ApphudDemoSwift && pod install
xcodebuild test -workspace Examples/ApphudDemoSwift/ApphudSDKDemo.xcworkspace \
  -scheme ApphudSDKDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
# Other workspaces: Examples/ApphudDemoSwiftUI/ApphudDemoSwiftUI.xcworkspace (scheme ApphudDemoSwiftUI),
#                   Examples/ApphudDemoVisionOS/ApphudSDKDemoVisionOS.xcworkspace (scheme ApphudSDKDemo)
```

## Rules

- **Upstream mirror** — keep this checkout in step with `apphud/ApphudSDK` release tags
  (`git fetch && git merge <tag>`); do not carry local source changes here.
- **Version is in two places** — `apphud_sdk_version` (`Sources/Public/Apphud.swift`)
  and `s.version` (`ApphudSDK.podspec`) must match the git tag.
- **Everything waits for registration** — new backend calls go behind
  `ApphudInternal.performWhenUserRegistered`; new endpoints are cases on
  `ApphudHttpClient.ApphudEndpoint`. See [agent_docs/structure.md](agent_docs/structure.md).
- **StoreKit 2 is the only purchase engine** — every SDK purchase ends in
  `ApphudAsyncStoreKit.purchaseResult`; do not add `SKPaymentQueue.add` paths.
  `ApphudProduct.skProduct` and the other `SKProduct` APIs are deprecated and filled by
  a best-effort background feeder, so new features must not depend on an `SKProduct`
  being present — read `ApphudProduct.product()` / `ApphudAsyncStoreKit` instead.
- **Finish only after the backend acknowledged** — `transaction.finish()` happens in
  `ApphudAsyncStoreKit.processTransaction` only when `submitReceipt` returned no error,
  and `lastUploadedTransactions` is written only on success. Keep that invariant; an
  unfinished transaction is redelivered by StoreKit, a finished-but-unsubmitted one is lost.
- **State lives on the main actor** — `ApphudInternal` user/paywall state is
  `@MainActor`, as are `submittingTransaction` and the per-transaction single-flight
  map; HTTP and StoreKit callbacks hop to main before touching it. Off-main data goes
  through `ApphudDataActor` / `ApphudProductsStorage`, not new locks.
- **Identity is two ids** — `userID` and `deviceID` are persisted in Keychain and
  UserDefaults by `ApphudKeychain`; `logout()` blanks both and the next `start` mints a
  new device id. Read the Identity section of architecture.md before touching
  `identify`, `checkUserID`, `updateUserID` or `logout`.
- **UIKit/WebKit code is compile-guarded** — `ApphudUI/` and
  `Public/ApphudPaywallScreenController.swift` sit in `#if os(iOS)` (per-file details in
  [agent_docs/structure.md](agent_docs/structure.md)); keep macOS/watchOS/tvOS/visionOS
  compiling; do not add unguarded UIKit imports (an import above the `#if os(iOS)` body
  goes behind `#if canImport(UIKit)`).
- **Delegate protocols are source-compatible** — new `ApphudDelegate` methods need an
  empty default in the protocol extension; `ApphudUIDelegate` methods are `@objc optional`.
  Prefer `productId:` / `Product` parameters; the `SKProduct` variants are deprecated and
  only reachable when the feeder has the product.
- **Callbacks must always be answered** — `startRequest`, `submitReceipt`, restore and
  `performWhenUserRegistered(allowFailure: true)` all guarantee a completion (including
  on `logout()`); a dropped callback hangs an awaiting purchase or restore.
- **Do not edit `docs/`** — it is the rendered DocC output; edit `Documentation.docc/`
  and doc comments instead.
