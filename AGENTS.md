<!-- AGENTS.md — index + rules. Detail lives in agent_docs/. Add rules on failure, remove when redundant. -->

# ApphudSDK (iOS)

Upstream Apphud in-app-subscription SDK: registers a customer, loads placements/paywalls,
purchases through StoreKit 1 or 2, uploads receipts/transactions, tracks attribution and
user properties, and renders Rules and Figma paywall screens in web views. Single SPM
target / CocoaPods pod. This checkout is an unmodified clone of `apphud/ApphudSDK` at
tag `4.4.9`; the docs describe that tag.

## Reference docs

| Topic | Doc |
| --- | --- |
| Init/registration flow, identity (userID/deviceID/logout), purchase paths, HTTP + retry, persistence, swizzling, ApphudUI, threading | [agent_docs/architecture.md](agent_docs/architecture.md) |
| Directory layout, where new code goes, naming | [agent_docs/structure.md](agent_docs/structure.md) |

## Tech stack

Swift 5.9 (`swiftLanguageVersions: [.v5]`), iOS 15+ / macOS 13+ / watchOS 9+ (SPM);
podspec adds tvOS 16+ / visionOS 1+. StoreKit only framework dependency; no third-party
packages. Distributed via `Package.swift` and `ApphudSDK.podspec`. `.swiftlint.yml`
exists but nothing runs it. The only tests are `Examples/ApphudDemoSwift/ApphudSDKTests`
and `Examples/ApphudDemoVisionOS/ApphudSDKTests` (three XCTests against a hard-coded live API key).

## Key commands

```bash
# Build the package (scheme "ApphudSDK" comes from Package.swift)
xcodebuild build -scheme ApphudSDK -destination 'generic/platform=iOS Simulator'

# Validate the pod
pod lib lint ApphudSDK.podspec

# Demo apps (CocoaPods, pod 'ApphudSDK', :path => '../../')
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
- **State lives on the main actor** — `ApphudInternal` user/paywall state is
  `@MainActor`; HTTP and StoreKit callbacks hop to main before touching it. Off-main
  data goes through `ApphudDataActor` / `ApphudProductsStorage`, not new locks.
- **Identity is two ids** — `userID` and `deviceID` are persisted in Keychain and
  UserDefaults by `ApphudKeychain`; `logout()` blanks both and the next `start` mints a
  new device id. Read the Identity section of architecture.md before touching
  `identify`, `checkUserID`, `updateUserID` or `logout`.
- **`ApphudUI/` and screen files are `#if os(iOS)`** — keep macOS/watchOS/tvOS/visionOS
  compiling; do not add UIKit imports outside those guards.
- **Delegate protocols are source-compatible** — new `ApphudDelegate` methods need an
  empty default in the protocol extension; `ApphudUIDelegate` methods are `@objc optional`.
- **Do not edit `docs/`** — it is the rendered DocC output; edit `Documentation.docc/`
  and doc comments instead.
