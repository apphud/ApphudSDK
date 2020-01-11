<img src="https://cdn.siter.io/assets/ast_kSk43nA4wqPNF8sfBtWdJsL1Z/85cc5c6c-43dd-44a2-90cf-2ae17cd6a25d.svg" alt="Apphud"/>

## Apphud SDK

Apphud SDK is a lightweight open-source Swift library to manage auto-renewable subscriptions in your iOS app. No backend required.

Visit our website for details: https://apphud.com

## Features

👍 Integrating subscriptions using our SDK is very easy.<br/>Apphud takes care of a subscription purchase process. Integrate SDK in just a few lines of code.

🧾 App Store receipts validation.<br/>Apphud validates and periodically refreshes App Store receipts to give you real-time data.

🕗 View subscription details and transactions history.<br/>Get expiration date, autorenew status in our SDK.

🔍 Determine for trial, introductory and promotional offer eligibility using our SDK. 

🔔 Receive a real-time notification when a user gets billed.<br/>We will send you a message to Slack and Telegram immediately when a user gets billed or started trial.

📊 View key subscription metrics in our [dashboard](https://docs.apphud.com/analyze/dashboard).<br/>Apphud has a convenient dashboard with key metrics of your subscriptions.

🔌 Integrations. Are available on all plans. Send subscription renewal events to other mobile analytics.<br/>Apphud reduces pain in sending all subscription events to external mobile analytics: Amplitude, Mixpanel, AppsFlyer, etc.

🎨 Create subscription purchase screens without coding in our visual web editor.<br/>You don't need to develop purchase screens. Just pick a template and modify it. So easy! *For now only promotional purchase screen are available, initial purchase screens will be available soon.*

✔ Promotional [subscription offers](https://docs.apphud.com/getting-started/promo-offers) support.<br/>Use Apphud to easily give a discount for existing and lapsed customers. No backend required.

💱 User local currency real-time conversion.

🏆 Increase app revenue using our [Rules](https://docs.apphud.com/rules-and-screens/rules).<br/>Apphud will automatically offer a promotional discount based subscription events.

🕵️ Subscription cancellation insights tool.<br/>Understand why you customers cancel a subscription to make right product decisions.

💸 Handle billing grace period and billing issues.<br/>Apphud will automatically ask a user to update his billing details in case of billing issue during renewal.

👏 Great [documentation](https://docs.apphud.com/).

🏃‍♂️ Fast [support](https://apphud.com/contacts ). We are online.

## SDK Requirements

Apphud SDK requires minimum iOS 11.2, Xcode 10 and Swift 4.2. 

## Installation

Apphud SDK can be installed via CocoaPods or manually.

##### Install via CocoaPods

Add the following line to your Podfile:

```ruby
pod 'ApphudSDK'
```

> In Objective-C project make sure `use_frameworks!` is added in your Podfile.

And then run in the Terminal:

```ruby
pod install
```

#### Manual Installation

Copy all files in `Source` folder to your project.

## Initialize Apphud SDK

To set up Apphud SDK you will need API Key. [Register](https://docs.apphud.com/getting-started/creating-app) your app in Apphud and get your API key.

```swift
import ApphudSDK

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
	
  Apphud.start(apiKey: "YOUR_API_KEY")

  // the rest of your code
  return true
}

```

> In Objective-C project you should import like this: `#import "ApphudSDK-Swift.h"`

## Use Apphud in Observer Mode

If you have a live app and already implemented subscription purchasing, it is not necessary to rewrite your subscription purchase flow with Apphud methods. Apphud SDK will still automatically track all purchases in your app.

In this case your setup is complete. However configuring push notifications is highly recommended.

## Push Notifications

To handle [push notifications](https://docs.apphud.com/getting-started/push) you need to provide Apphud with device tokens and handle incoming notifications. This is highly recommended in order to use [Rules](https://docs.apphud.com/rules-and-screens/rules) – a powerful feature that lets you increase your app revenue by automatically offering a discount to a user at the specified moment.

## Handle Subscriptions

Apphud SDK provides a set of methods to manage subscriptions. All these methods can be used regardless how you purchased the subscription (via Apphud SDK or your existing code).

### Fetch Products

Apphud automatically fetches SKProduct objects upon launch. Products identifiers must be [added](https://docs.apphud.com/getting-started/adding-products) in our dashboard. To get your products call:

```swift
Apphud.products()
```

When products are fetched from the App Store you will also receive a notification from Notification Center along with Apphud delegate method call (use what fits better your needs).

### Make a Purchase

To make a purchase:

```swift
Apphud.purchase(product) { (subscription, error) in
   // handle result
}
```

This method will return a subscription model, which contains all relevant info about your subscription, including expiration date. See `ApphudSubscription.swift` file for details.

### Check Subscription Status

```swift
Apphud.hasActiveSubscription()
```

Returns `true` if the user has active subscription. Use this method to determine whether or not to unlock premium functionality to the user. 

### Get Subscription Details

To get subscription object (which contains expiration date, autorenew status, etc.) use the following method: 

```swift
Apphud.subscription()
```

 See `ApphudSubscription.swift` file for details.

### Restore Purchases

If your app doesn't have a login system, which identifies a premium user by his credentials, then you need a restore mechanism. If you already have a restore purchases mechanism by calling `SKPaymentQueue.default().restoreCompletedTransactions()`, then you have nothing to worry about – Apphud SDK will automatically intercept and send latest App Store Receipt to Apphud servers when your restoration is completed. However, better to call our restore method from SDK:

```swift
Apphud.restoreSubscriptions{ subscriptions in 
   // handle here
}
```

Basically it just sends App Store Receipt to Apphud and returns subscriptions in callback (or `nil` if nothing was ever purchased).

## Migrate Existing Subscribers

If you already have a live app with paying users and you want Apphud to track their subscriptions, you should import their App Store receipts into Apphud. Apphud SDK doesn't automatically submit App Store receipts of your existing subscribers. Run this code at launch of your app:

```swift
// hasPurchases - is your own boolean value indicating that current user is paying user.
if hasPurchases {
    Apphud.migrateSubscriptionsIfNeeded {_ in}
}
```

## Determing Eligibility for Introductory or Promotional Offer

You can use Apphud SDK to determine if a user is eligible for an introductory or promotional offer:

```swift
// Checking eligibility for introductory offer
Apphud.checkEligibilityForIntroductoryOffer(product: myProduct) { result in
  if result {
    // User is eligible for introductory offer
  }
}

// Checking eligibility for promotional offer
Apphud.checkEligibilityForPromotionalOffer(product: myProduct) { result in
  if result {
    // User is eligible for promotional offer
  }
}
```

You may also check eligibility for multiple offers at one call: 
`checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: ApphudEligibilityCallback)` or `checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: ApphudEligibilityCallback)`

## Integrations

See the full setup guide if you need to add integrations with mobile analytics and messengers.

https://docs.apphud.com/getting-started/sdk-integration#match-user-identifiers-by-apphuds-userid-recommended

https://docs.apphud.com/integrations/parameters-and-properties

## Pricing

Apphud is absolutely free unless you make $10K per month. You can check our pricing [here](https://apphud.com/pricing).

## Having troubles?

If you have any questions or troubles with SDK integration feel free to contact us. We are online.

https://apphud.com/contacts



*Like Apphud? Place a star at the top 😊*
