# ``ApphudSDK``

Apphud is an all-in-one infrastructure for your app growth. Apphud helps marketing and product management teams make the right decisions based on data and tools. 

  * [Subscriptions Infrastructure](https://docs.apphud.com/docs/ios) - Integrate in-app purchases and subscriptions in your mobile app in 2 lines of code. No server code required. Apphud works with all apps on iOS, iPadOS, macOS, tvOS, watchOS and Android. Cross-platform support out of the box.
  * [Real-time Revenue Analytics](https://docs.apphud.com/docs/dashboard) - View key subscription metrics in our dashboard and charts, like MRR, Subscriber Retention (Cohorts), Churn rate, ARPU, Trial Conversions, Proceeds, Refunds, etc.
  * [Integrations](https://docs.apphud.com/docs/appsflyer) - Send subscription events to your favorite third party platforms with automatic currency conversion. Choose from 18 integrations, including: AppsFlyer, Adjust, Branch, Firebase, Amplitude, Mixpanel, OneSignal, Facebook, TikTok, and more. Custom Server-to-Server webhooks and APIs are also available.
  * [A/B Experiments](https://docs.apphud.com/docs/experiments) - Test different in-app purchases and paywalls. Run experiments to find the best combination of prices and purchase screen parameters that maximize ROI.
  * [Paywall Screens (Beta)](https://docs.apphud.com/docs/paywall-screens) - Design fully customizable paywalls in Figma and display them in your app using our SDK — all without writing a single line of HTML or native UI code. Create beautiful paywall designs with the flexibility of design tools like Figma, combined with the performance and user experience of native paywalls.
  * [Web-to-App](https://docs.apphud.com/docs/web-to-app-solution) - This solution overcomes IDFA limitations in the post iOS 14.5 era. Using this solution, you can run paid campaigns on Facebook or TikTok and get real-time attribution with nearly 100% accuracy.
  * [Rules](https://docs.apphud.com/docs/rules) - Apphud can win back lapsed subscribers, reduce churn rate, get cancellation insights, send push notifications and much more using the mechanics below. These mechanics are called Rules. Choose between manual, scheduled and automated rules. Use our visual web editor to create your custom screen or screen sequence for Rules, and analyze user stats from every created screen.



Sign up [for free](https://app.apphud.com).

### The easiest way to integrate in-app subscriptions

Apphud provides ready-to-use infrastructure for all kinds of in-app purchases: subscriptions, consumables and non-consumables. Integrate Apphud SDK and implement 3 lines of code:

```swift
// Init SDK
Apphud.start(apiKey: "api_key")

// Get Placement by Identifier, and then get it's paywall
let placement = await Apphud.placement("onboarding")

// Purchase product from the paywall
let result = await Apphud.purchase(product)
```

### Pre-designed Paywall Screens

Apphud SDK provides a powerful feature that allows you to show beautifully designed paywall screens directly in your app without any additional UI development. These screens are created and configured in the Apphud dashboard and can be fetched and displayed with just a few lines of code:

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

This feature enables you to:
- Create beautiful paywall designs without coding
- A/B test different paywall layouts and content
- Update paywall designs remotely without app updates
- Support multiple paywall variations for different user segments

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

