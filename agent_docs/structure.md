# Directory structure

One SPM target/CocoaPods pod (`ApphudSDK`) rooted at `Sources/`. The three folders
under it are conventions inside a single module, not separate targets or products.
Every file in `ApphudUI/` and the UI-related files in `Public/` are wrapped in
`#if os(iOS)`; the rest compiles for iOS, macOS, tvOS, watchOS and visionOS.

```
Package.swift             # SPM: library product/target "ApphudSDK" (path Sources/) + test target
                          # "ApphudUnitTests" (path Tests/ApphudUnitTests); iOS 15 / macOS 13 / tvOS 16 /
                          # watchOS 9 / visionOS 1 (must match the podspec), swift-tools 5.9, PrivacyInfo.xcprivacy
ApphudSDK.podspec         # Pod: version (== apphud_sdk_version), same platform floors,
                          # source_files Sources/**/*.{swift,h,m}, resource bundle for PrivacyInfo
.swiftlint.yml            # line_length 300, identifier_name disabled (no lint step is wired up)
Sources/
  PrivacyInfo.xcprivacy   # Privacy manifest (FileTimestamp C617.1, UserDefaults CA92.1, purchase history)
  Public/                 # Everything a host app imports
    Apphud.swift                     # `final class Apphud` — all static entry points; `apphud_sdk_version`
    ApphudDelegate.swift             # ApphudDelegate protocol + empty default impls
    ApphudUIDelegate.swift           # @objc ApphudUIDelegate (Rules/Screens hooks), ApphudScreenDismissAction
    ApphudUser.swift                 # ApphudUser (Codable, cache v2 + legacy migration), ApphudCurrency
    ApphudSubscription.swift         # ApphudSubscription + ApphudSubscriptionStatus; stub inits (SKProduct / Product)
    ApphudNonRenewingPurchase.swift  # ApphudNonRenewingPurchase (+ SK2 product-type lookup, stub inits)
    ApphudPurchaseResult.swift       # ApphudPurchaseResult (transactionV2 + isPending; SK1 `transaction` deprecated)
    ApphudAsyncPurchaseResult.swift  # ApphudAsyncPurchaseResult (SK2 Transaction + isPending)
    ApphudPaywall.swift              # ApphudPaywall, ApphudPaywallID; product↔placement wiring, macro rendering
    ApphudPlacement.swift            # ApphudPlacement, ApphudPlacementID
    ApphudProduct.swift              # ApphudProduct (`product()` SK2 accessor; `skProduct` deprecated, fed lazily)
    ApphudGroup.swift                # ApphudGroup (permission group) + hasAccess
    ApphudPaywallScreen.swift        # ApphudPaywallScreen (per-locale URLs → paywallURL with live=true)
    ApphudPaywallScreenController.swift  # iOS: public controller surface, state/cache-policy enums, callbacks
    ApphudRule.swift                 # ApphudRule (rule/screen/paywall ids from notifications/push)
    ApphudRuleScreen.swift           # ApphudRuleScreen (status bar colour, name) from legacy screen JS
    ApphudReceipt.swift              # ApphudReceipt + POST /v1/subscriptions/raw
    ApphudAttributionData.swift      # ApphudAttributionData (raw + normalised attribution fields)
    ApphudUserPropertyKey.swift      # ApphudUserPropertyKey + built-in $email/$name/... keys
    ApphudEnums.swift                # ApphudAttributionProvider, callback typealiases, IAP coding keys
    ApphudError.swift                # ApphudError (NSError) + APPHUD_* constants (retries, timeouts, codes)
    ApphudUtils.swift                # ApphudUtils (log level, opt-out, log file; useStoreKitV2 is a no-op), apphudLog()
  Internal/               # Engine; `ApphudInternal` is split into extensions by concern
    ApphudInternal.swift             # Singleton state, initialize/identify, registration retry loop,
                                     # performWhenUserRegistered gate, events/notifications API, logout
    ApphudInternal+UserUpdate.swift  # parseUser, createOrGetUser, updateUser (POST /customers),
                                     # updateUserID, refreshUserData, grantPromotional, user properties
    ApphudInternal+Product.swift     # SKProduct fetch orchestration, preparePaywalls, fetchOfferingsFull,
                                     # permission groups, single paywall fetch, Caches read/write
    ApphudInternal+Purchase.swift    # Purchase entry (always SK2), handleTransactionResult, SK2 restore
                                     # (currentEntitlements / AppStore.sync), submitReceipt (POST /subscriptions,
                                     # receipt + transaction id + JWS, single-flight) + retry, promo offer signing
    ApphudInternal+Attribution.swift # setAttribution per provider, Apple Ads lookup, deep-link and
                                     # web2web attribution
    ApphudInternal+Eligibility.swift # intro/promo eligibility: SK2 by product id (+ deprecated SKProduct overloads)
    ApphudInternal+Currency.swift    # Storefront / priceLocale currency → customers params
    ApphudInternal+Fallback.swift    # Bundled-JSON paywall fallback, stub purchases (Product / SKProduct); host fallback
    ApphudHttpClient.swift           # Endpoints, request building, headers, response parsing, screen HTML cache,
                                     # testURLSessionConfiguration seam
    ApphudURLSession.swift           # URLSession.data(for:retries:delay:) retry loop
    ApphudDataActor.swift            # @globalActor: Caches-dir files, pending user props, attribution caches,
                                     # known product types
    ApphudProductsStorage.swift      # actor: SK2 Product set + in-flight ids
    ApphudStoreKitWrapper.swift      # SK1 compatibility: payment queue observer (observer mode / legacy twins),
                                     # SKProductsRequest feeder, shared receipt refresh, SKPaymentQueue.add swizzle,
                                     # applicationUsername. Starts no purchases.
    ApphudAsyncStoreKit.swift        # SK2 engine: Product cache, purchase(options:), processTransaction single-flight,
                                     # ApphudAsyncTransactionObserver (Transaction.updates),
                                     # ApphudPurchaseIntentsObserver (PurchaseIntent.intents)
    ApphudStoreKit2Extensions.swift  # Product.apphudSubmittableParameters / apphudPromoIdentifiers / currency+country
                                     # (priceFormatStyle, SK1 fallback); SKProduct + Locale legacy helpers
    ApphudKeychain.swift             # userID/deviceID in Keychain + UserDefaults
    ApphudUserProperty.swift         # ApphudUserProperty → JSON
    ApphudLoggerService.swift        # paywall_* events, load-time metrics
    ApphudWebController.swift        # iOS: hidden WKWebView for deferred deep-link visitor id
    ApphudSafeSet.swift              # barrier-queue Set (keeps ApphudProductsFetcher alive)
    ApphudExtensions.swift           # device params, receipt string, SKProduct → params/strings,
                                     # Error → message, ApphudAnyCodable, date formatters, UserDefaults dict cache
  ApphudUI/               # iOS-only web-view UI (Rules screens + Figma paywall screens)
    ApphudScreensManager.swift               # Rules dispatch, push handling, preloaded paywall controllers
    ApphudScreenController.swift             # Legacy HTML Rule screen (WKWebView, loader, dismiss)
    ApphudScreenController+Extensions.swift  # WKNavigationDelegate, in-page action routing, events
    ApphudScreenController+Macros.swift      # {{"product_id" | price}} replacement
    ApphudNavigationController.swift         # Portrait nav stack for multi-screen Rules, preload
    ApphudPaywallScreenController+I.swift    # Figma paywall controller internals: load, JS bridge,
                                             # pay.apphud.com navigation, purchase/restore, Rule callbacks
    ApphudView.swift                         # WKWebView subclass; PaywallSDK.processDomMacros / insets
    ApphudPaywallView.swift                  # SwiftUI UIViewControllerRepresentable wrapper
    ApphudLoadingView.swift                  # Blur + spinner overlay with 30 s auto-dismiss
Tests/
  ApphudUnitTests/        # SPM test target (`swift test`, @testable import): ApphudCoreTests (ApphudError,
                          # endpoint paths/host-fallback flags, UserDefaults dict cache),
                          # ApphudFailedTransactionTests (SK1 .failed finishing vs observer mode),
                          # ApphudReceiptRefreshTests (shared SKReceiptRefreshRequest, watchdog) — 13 tests
Examples/                 # Three CocoaPods demo apps, each `pod 'ApphudSDK', :path => '../../'`
  ApphudDemoSwift/        # UIKit demo (iOS 15); workspace ApphudSDKDemo.xcworkspace, schemes ApphudSDKDemo /
                          # StoreKitApphudSDKDemo; ApphudSDKTests/ = 12 StoreKitTest integration tests hosted by
                          # the demo app: ApphudStubURLProtocol stubs the backend, SKTestSession runs
                          # StoreKit.storekit (register, purchase → JWS upload, foreign purchase, concurrent
                          # delivery, failed-upload recovery, restore, legacy dedup-key migration)
  ApphudDemoSwiftUI/      # SwiftUI demo; schemes ApphudDemoSwiftUI / ApphudDemoSwiftUILocal
  ApphudDemoVisionOS/     # visionOS demo; scheme ApphudSDKDemo (platform :visionos); ApphudSDKTests/
                          # (3 XCTests against a hard-coded live key)
Documentation.docc/
  Documentation.md        # DocC landing page: feature overview + curated symbol lists
docs/                     # Rendered DocC static site (index.html, documentation/apphudsdk/, data/, index/)
README.md                 # Marketing README (links to docs.apphud.com)
LICENSE                   # MIT
```

## Where new code goes

- **Public API** — a static method on `Apphud` in `Public/Apphud.swift` that forwards to
  `ApphudInternal`; new models are `Codable` classes in `Public/` (snake_case JSON is
  handled by `.convertFromSnakeCase` on the decoders, so `CodingKeys` only for renames).
- **Backend endpoint** — a case in `ApphudHttpClient.ApphudEndpoint` (+ `value`, and
  `canTriggerHostFallback` if it is critical), then a method on the matching
  `ApphudInternal+*.swift` extension that calls `httpClient?.startRequest(...)` and
  wraps it in `performWhenUserRegistered` when it needs a customer.
- **Persisted value** — ids go through `ApphudKeychain`; blobs go through
  `ApphudDataActor.apphudDataToCache(data:key:)` (Caches directory, timestamp-based
  expiry); small flags are `UserDefaults` computed properties on `ApphudInternal` with
  the key declared next to the other `*Key` constants. Add it to `logout()` if it is
  per-user.
- **Purchase behaviour** — StoreKit 2 only: purchase options and result mapping in
  `Internal/ApphudAsyncStoreKit.swift` (`purchaseResult`) / `ApphudInternal+Purchase.swift`
  (`purchaseAsync`); `Product`-derived payload fields in `Internal/ApphudStoreKit2Extensions.swift`
  (mirror any new field in `SKProduct.apphudSubmittableParameters` too); anything that
  turns a transaction into an upload belongs in `ApphudInternal+Purchase.swift`
  (`handleTransactionResult` → `submitReceipt`). `Internal/ApphudStoreKitWrapper.swift` is
  for observer-mode tracking of the host app's own SK1 payments, the feeder and the
  swizzle only — do not add purchase logic there.
- **Tests** — pure logic and seams (`makeReceiptRefreshRequest`,
  `testURLSessionConfiguration`) go in `Tests/ApphudUnitTests/` (`swift test`, no
  network/StoreKit); anything that needs a real StoreKit transaction goes in
  `Examples/ApphudDemoSwift/ApphudSDKTests/` behind `ApphudStubURLProtocol` + `SKTestSession`.
- **Delegate callback** — add to `ApphudDelegate` with an empty default in the protocol
  extension (host apps must keep compiling), or as `@objc optional` on `ApphudUIDelegate`.
- **Rule/screen or paywall-screen UI** — `Sources/ApphudUI/`, wrapped in `#if os(iOS)`;
  its public surface goes in `Public/ApphudPaywallScreenController.swift`.
- **Version bump** — `apphud_sdk_version` in `Public/Apphud.swift` and `s.version` in
  `ApphudSDK.podspec` must match; the demo `Podfile.lock`s pin the same number.

## Naming

- Every type is prefixed `Apphud`; internal free functions are prefixed `apphud`
  (`apphudLog`, `apphudIsSandbox`, `apphudReceiptDataString`).
- `ApphudInternal+<Concern>.swift` for extensions of the engine; `+I.swift` /
  `+Extensions.swift` / `+Macros.swift` for controller extensions in `ApphudUI/`.
- `*Wrapper` for the SK1 compatibility facade, `*AsyncStoreKit` for the SK2 engine,
  `*Observer` for its `for await` listeners, `*Actor`/`*Storage` for actors, `*Manager`
  for the screen coordinator, `*Controller` for view controllers, `*Service` for the
  logger, `*Tests` for XCTest cases; SK2 counterparts of `SKProduct` helpers keep the same
  `apphud*` name on `Product`.
- Public constants are `APPHUD_UPPER_SNAKE`; UserDefaults keys are stored in
  `*Key` properties or string literals colocated with their accessor.
- JSON fields are snake_case on the wire and camelCase in Swift; the only `@objc`
  snake_case public properties are on `ApphudRule`/`ApphudRuleScreen` (`rule_name`,
  `screen_name`, `status_bar_color`).
