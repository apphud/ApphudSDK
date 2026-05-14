# ``ApphudSDK``

Apphud is an all-in-one growth infrastructure for subscription apps, giving marketing and product teams the data and tools they need to make better decisions.

  * [Subscriptions Infrastructure](https://docs.apphud.com/docs/ios) — Integrate in-app purchases and subscriptions with just two lines of code. No server-side code required. Cross-platform support for iOS, iPadOS, macOS, tvOS, watchOS, visionOS and Android out of the box.
  * [Real-time Revenue Analytics](https://docs.apphud.com/docs/dashboard) — Track every key subscription metric in one place: MRR, subscriber retention (cohorts), churn rate, ARPU, trial conversions, proceeds, refunds, and more.
  * [Integrations](https://docs.apphud.com/docs/appsflyer) — Forward subscription events to your favorite third-party platforms with automatic currency conversion. Choose from 18 integrations including AppsFlyer, Adjust, Branch, Firebase, Amplitude, Mixpanel, OneSignal, Facebook, and TikTok. Custom server-to-server webhooks and APIs are also supported.
  * [A/B Experiments](https://docs.apphud.com/docs/experiments) — Test different in-app purchases and paywalls. Run experiments to find the combination of prices and paywall parameters that maximizes ROI.
  * [Paywall Screens](https://docs.apphud.com/docs/paywall-screens) — Design fully customizable paywalls in Figma and render them natively in your app — no HTML or hand-written UI code required. You get the flexibility of a design tool with the performance and feel of a native paywall.
  * [Web-to-App](https://docs.apphud.com/docs/web-to-app-solution) — Overcome post-iOS 14.5 IDFA limitations. Run paid campaigns on Facebook or TikTok and attribute installs in real time with near 100% accuracy.
  * [Rules](https://docs.apphud.com/docs/rules) — Win back lapsed subscribers, reduce churn, capture cancellation insights, and send push notifications using Rules. Choose between manual, scheduled and automated rules, build the screens with our visual web editor, and analyze user stats for every screen you ship.

Sign up [for free](https://app.apphud.com).

### The easiest way to integrate in-app subscriptions

Apphud provides ready-to-use infrastructure for every kind of in-app purchase — subscriptions, consumables and non-consumables. Three lines of code is all you need to get started:

```swift
// Init SDK
Apphud.start(apiKey: "api_key")

// Get a placement by identifier, then access its paywall
let placement = await Apphud.placement("onboarding")

// Purchase a product from the paywall
let result = await Apphud.purchase(product)
```

### Pre-designed Paywall Screens

Apphud SDK can render fully designed paywall screens straight from the Apphud dashboard, with no additional UI work in your app. Fetch and present them in just a few lines of code:

```swift
// Preload paywall screens for faster presentation
Apphud.preloadPaywallScreens(placementIdentifiers: ["onboarding", "settings"])

// Fetch and present a paywall screen
if let paywall = placement.paywall {
    Apphud.fetchPaywallScreen(paywall) { result in
        switch result {
        case .success(let controller):
            // Present the ready-to-use paywall screen controller
            present(controller, animated: true)
        case .error(let error):
            print("Failed to load paywall screen: \(error)")
        }
    }
}

// For SwiftUI apps, use fetchPaywallView
do {
    let paywallView = try await Apphud.fetchPaywallView(paywall) {
        // Handle dismissal
    }
    // Present the SwiftUI view
} catch {
    print("Failed to load paywall view: \(error)")
}
```

With paywall screens you can:
- Build beautiful paywalls without writing UI code
- A/B test different layouts and copy
- Update designs over the air, with no app release
- Tailor paywall variations to different user segments

### Remote Config & Experiments

Apphud lets you ship app-level remote configuration and A/B-test variations from the dashboard. The current user exposes the assigned experiment, variation and config payload, so you can branch your UI or business logic without shipping a new build.

```swift
guard let user = Apphud.currentUser() else { return }

// App-level remote config, parsed as a JSON dictionary
let config = user.remoteConfig()
if let theme = config["onboarding_theme"] as? String {
    applyTheme(theme)
}

// Or read the raw JSON string directly
let raw = user.remoteConfigString

// Active A/B experiment and variation, if any
if let experiment = user.experimentName,
   let variation = user.variationName {
    Analytics.track("ab_assignment", [
        "experiment": experiment,
        "variation": variation
    ])
}

// Number of devices associated with the same userId — handy for spotting account sharing
if user.totalDevicesCount > 5 {
    // limit premium features, prompt re-authentication, etc.
}
```

## Topics

### Apphud Methods

See full list of methods here: ``Apphud``

Here are some primary methods:

#### Initialization & User Management
- ``Apphud/start(apiKey:userID:observerMode:callback:)``
- ``Apphud/startManually(apiKey:userID:deviceID:observerMode:callback:)``
- ``Apphud/updateUserID(_:callback:)``
- ``Apphud/userID()``
- ``Apphud/deviceID()``
- ``Apphud/currentUser()``
- ``Apphud/logout()``
- ``Apphud/refreshUserData(callback:)``

#### Placements & Paywalls
- ``Apphud/placements(maxAttempts:)``
- ``Apphud/rawPlacements()``
- ``Apphud/placement(_:)``
- ``Apphud/fetchPlacements(maxAttempts:_:)``
- ``Apphud/deferPlacements()``
- ``Apphud/paywallShown(_:)``

#### Paywall Screen Presentation
- ``Apphud/preloadPaywallScreens(placementIdentifiers:)``
- ``Apphud/fetchPaywallScreen(_:maxTimeout:cachePolicy:completion:)``
- ``Apphud/fetchPaywallView(_:maxTimeout:cachePolicy:onDismiss:)``
- ``Apphud/unloadPaywallScreen(_:)``

#### Purchase & Products
- ``Apphud/purchase(_:callback:)-6dhy3``
- ``Apphud/purchase(_:)``
- ``Apphud/purchasePromo(apphudProduct:discountID:_:)``
- ``Apphud/fetchProducts(maxAttempts:_:)``
- ``Apphud/fetchSKProducts(maxAttempts:)``
- ``Apphud/products``
- ``Apphud/product(productIdentifier:)``

#### Subscription Status
- ``Apphud/hasPremiumAccess()``
- ``Apphud/hasActiveSubscription()``
- ``Apphud/subscription()``
- ``Apphud/subscriptions()``
- ``Apphud/nonRenewingPurchases()``
- ``Apphud/isNonRenewingPurchaseActive(productIdentifier:)``

#### Restore & Receipts
- ``Apphud/restorePurchases()``
- ``Apphud/restorePurchases(callback:)``
- ``Apphud/appStoreReceipt()``
- ``Apphud/fetchRawReceiptInfo(_:)``

#### User Properties & Attribution
- ``Apphud/setUserProperty(key:value:setOnce:)``
- ``Apphud/incrementUserProperty(key:by:)``
- ``Apphud/forceFlushUserProperties(completion:)``
- ``Apphud/setAttribution(data:from:identifer:callback:)``
- ``Apphud/attributeFromWeb(data:callback:)``
- ``Apphud/attributeFromDeeplink(callback:)``
- ``Apphud/setDeviceIdentifiers(idfa:idfv:)``

#### Eligibility & Offers
- ``Apphud/checkEligibilityForIntroductoryOffer(product:callback:)``
- ``Apphud/checkEligibilityForPromotionalOffer(product:callback:)``
- ``Apphud/checkEligibilitiesForIntroductoryOffers(products:callback:)``
- ``Apphud/checkEligibilitiesForPromotionalOffers(products:callback:)``

#### Observer Mode
- ``Apphud/willPurchaseProductFrom(paywallIdentifier:placementIdentifier:)``

#### Other
- ``Apphud/grantPromotional(daysCount:productId:permissionGroup:callback:)``
- ``Apphud/submitPushNotificationsToken(token:callback:)``
- ``Apphud/handlePushNotification(apsInfo:)``
- ``Apphud/showPendingRuleScreen()``
- ``Apphud/pendingRuleScreenController()``
- ``Apphud/pendingRule()``

### ApphudDelegate main methods

- ``ApphudDelegate/apphudSubscriptionsUpdated(_:)``
- ``ApphudDelegate/apphudNonRenewingPurchasesUpdated(_:)``
- ``ApphudDelegate/apphudDidChangeUserID(_:)``
- ``ApphudDelegate/userDidLoad(user:)``
- ``ApphudDelegate/paywallsDidFullyLoad(paywalls:)``
- ``ApphudDelegate/placementsDidFullyLoad(placements:)``
- ``ApphudDelegate/apphudShouldStartAppStoreDirectPurchase(_:)``
- ``ApphudDelegate/apphudDidObservePurchase(result:)``
- ``ApphudDelegate/handleDeferredTransaction(transaction:)``

### ApphudUIDelegate main methods

- ``ApphudUIDelegate/apphudShouldPerformRule(rule:)``
- ``ApphudUIDelegate/apphudShouldShowScreen(screenName:)``
- ``ApphudUIDelegate/apphudParentViewController(controller:)``
- ``ApphudUIDelegate/apphudScreenPresentationStyle(controller:)``
- ``ApphudUIDelegate/apphudWillPurchase(product:offerID:screenName:)``
- ``ApphudUIDelegate/apphudDidPurchase(product:offerID:screenName:)``
- ``ApphudUIDelegate/apphudDidFailPurchase(product:offerID:errorCode:screenName:)``
- ``ApphudUIDelegate/apphudScreenDidAppear(screenName:)``
- ``ApphudUIDelegate/apphudScreenWillDismiss(screenName:error:)``
- ``ApphudUIDelegate/apphudDidDismissScreen(controller:)``
- ``ApphudUIDelegate/apphudScreenDismissAction(screenName:controller:)``
- ``ApphudUIDelegate/apphudDidSelectSurveyAnswer(question:answer:screenName:)``

