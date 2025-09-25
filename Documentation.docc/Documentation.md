# ``ApphudSDK``

Apphud is all-in-one infrastructure for your app growth. Apphud helps marketing and product management teams to make right decisions based on the data and tools. 

  * [Subscriptions Infrastructure](https://docs.apphud.com/docs/ios) - integrate in-app purchases and subscriptions in your mobile app in 2 lines of code. No server code required. Apphud works with all apps on iOS, iPadOS, MacOS, tvOS, watchOS and Android. Cross-platform support out of the box.
  * [Real-time Revenue Analytics](https://docs.apphud.com/docs/dashboard) - view key subscription metrics in our dashboard and charts, like MRR, Subscriber Retention (Cohorts), Churn rate, ARPU, Trial Conversions, Proceeds, Refunds, etc.
  * [Integrations](https://docs.apphud.com/docs/appsflyer) - Send subscription events to your favorite third party platforms with automatic currency conversion. Choose from 18 integrations, including: AppsFlyer, Adjust, Branch, Firebase, Amplitude, Mixpanel, OneSignal, Facebook, TikTok, and more. Custom Server-to-Server webhooks and APIs are also available.
  * [A/B Experiments](https://docs.apphud.com/docs/experiments) - Test different in-app purchases and paywalls. Run experiments to find the best combination of prices and purchase screen parameters that maximise ROI.
  * [Web-to-App](https://docs.apphud.com/docs/web-to-app-solution) - solution overcomes IDFA limitations in the post iOS 14.5 era. Using this solution you can run paid campaigns in Facebook or TikTok and get real-time attribution with nearly 100% accuracy.
  * [Rules](https://docs.apphud.com/docs/rules) - Apphud may win back lapsed subscribers, reduce churn rate, get cancellation insights, send push notifications and many more using the mechanics below. This mechanics are called Rules. Choose between manual, scheduled and automated rule. Use our visual web editor to create you custom screen or screen sequence for Rule, and analyze user stats from every created screen.



Sign up [for free](https://app.apphud.com).

### The easiest way to integrate in-app subscriptions

Apphud provides ready-to-use infrastructure for all kinds of in-app purchases: subscriptions, consumables and non-consumables. Integrate Apphud SDK and implement 3 lines of code:

```swift
// Init SDK
Apphud.start(apiKey: "api_key")

// SDK 3.2.0 and above
// Get Placement by Identifier, and then get it's paywall
let placement = await Apphud.placement(ApphudPlacementID.onboarding.rawValue)

// Purchase product from the paywall
let result = await Apphud.purchase(product)
```

## Topics

### Apphud Methods

See full list of methods here: ``Apphud``

Here are some primary methods:

- ``Apphud/start(apiKey:userID:observerMode:callback:)``

- ``Apphud/paywalls()``
- ``Apphud/placements()``
- ``Apphud/paywall(_:)``
- ``Apphud/placement(_:)``
- ``Apphud/paywallsDidLoadCallback(_:)``
- ``Apphud/placementsDidLoadCallback(_:)``
- ``Apphud/paywallShown(_:)``

- ``Apphud/purchase(_:callback:)-6dhy3``
- ``Apphud/grantPromotional(daysCount:productId:permissionGroup:callback:)``
- ``Apphud/restorePurchases(callback:)``

- ``Apphud/hasPremiumAccess()``
- ``Apphud/hasActiveSubscription()``

- ``Apphud/willPurchaseProductFrom(paywallIdentifier:placementIdentifier:)``

- ``Apphud/setUserProperty(key:value:setOnce:)``
- ``Apphud/addAttribution(data:from:identifer:callback:)``

- ``Apphud/checkEligibilityForIntroductoryOffer(product:callback:)``
- ``Apphud/checkEligibilityForPromotionalOffer(product:callback:)``

### ApphudDelegate main methods

- ``ApphudDelegate/apphudSubscriptionsUpdated(_:)``
- ``ApphudDelegate/apphudNonRenewingPurchasesUpdated(_:)``
- ``ApphudDelegate/apphudDidChangeUserID(_:)``
- ``ApphudDelegate/paywallsDidFullyLoad(paywalls:)-3kcab``
- ``ApphudDelegate/placementsDidFullyLoad(placements:)-8b6v8``
- ``ApphudDelegate/userDidLoad(user:)-4f87g``

- ``ApphudDelegate/apphudShouldStartAppStoreDirectPurchase(_:)``
- ``ApphudDelegate/apphudDidObservePurchase(result:)``
- ``ApphudDelegate/handleDeferredTransaction(transaction:)``

### ApphudUIDelegate main methods

- ``ApphudUIDelegate/apphudShouldPerformRule(rule:)``
- ``ApphudUIDelegate/apphudShouldShowScreen(screenName:)``
- ``ApphudUIDelegate/apphudParentViewController(controller:)``

- ``ApphudUIDelegate/apphudScreenPresentationStyle(controller:)``
- ``ApphudUIDelegate/apphudParentViewController(controller:)``
- ``ApphudUIDelegate/apphudWillPurchase(product:offerID:screenName:)``
- ``ApphudUIDelegate/apphudDidPurchase(product:offerID:screenName:)``
- ``ApphudUIDelegate/apphudScreenDismissAction(screenName:controller:)``

