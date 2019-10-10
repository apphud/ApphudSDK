<p align="left">
  <img src="https://cdn.siter.io/assets/ast_kSk43nA4wqPNF8sfBtWdJsL1Z/85cc5c6c-43dd-44a2-90cf-2ae17cd6a25d.svg" alt="Apphud"/>
</p>

## Apphud SDK

Apphud SDK is a lightweight open-source Swift library to help you grow your iOS subscriptions business.

Visit our website for details: https://apphud.com

## Features

👍 Easily purchase subscriptions using our SDK.

🧾 App Store receipts validation.

💰 Track subscriptions info and view transactions history.

📊 View key subscription metrics in our [dashboard.](https://docs.apphud.com/analyze/dashboard)

💻 Create mobile purchase screens in our dashboard in just a few clicks with no coding.

✔ Promotional [subscription offers](https://docs.apphud.com/getting-started/promo-offers) support.

📈 [Integrations](https://docs.apphud.com/integrations/events) with mobile analytics and messengers (Amplitude, AppsFlyer, Branch, Mixpanel, Slack, Telegram).

💱 User local currency real-time conversion.

🏆 Automated rules to [win back](https://docs.apphud.com/win-back/rules) lapsed subscribers.

🕵️ Subscription cancellation insights tool.

💸 Handle billing grace period and billing issues.

👏 Great [documentation](https://docs.apphud.com/).

🏃‍♂️ Fast [support](https://apphud.com/contacts ). We are online.

## SDK Requirements

Apphud SDK requires minimum iOS 11.2, Xcode 10 and Swift 5.0. 

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

## Configuring Apphud SDK

To set up Apphud SDK you will need API Key. [Register](https://docs.apphud.com/getting-started/creating-app) your app in Apphud and get your API key.

```swift
import ApphudSDK

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
	
  Apphud.start(apiKey: "YOUR_API_KEY")

  // the rest of your code
  return true
}

```

> In Objective-C project you should import like this: `#import <ApphudSDK-Swift.h>

However if you want to use Integrations, you will need to update the code to set user identifier. See the bottom of this guide to get the link.

## Getting Products

Apphud will automatically fetch SKProduct objects upon launch. Products identifiers must be [added](https://docs.apphud.com/getting-started/adding-products) in our dashboard. To get your products call:

```swift
Apphud.products()
```

When products are fetched from App Store you will also receive notification from Notification Center and delegate method called as well.

## Making a Purchase

To make a purchase:

```swift
Apphud.purchase(product) { (subscription, error) in
   // handle result
}
```

If you handle payments by yourself, you can just submit App Store receipt after successful purchase:

```swift
Apphud.submitReceipt("productID") { (subscription, error) in
    // handle result
}
```

Both methods will return a subscription model, which contains all relevant info about your subscription, including expiration date. See `ApphudSubscription.swift` file for details.

## Checking Subscription Status

```swift
Apphud.hasActiveSubscription()
```

Returns `true` if user has active subscription. Use this method to determine whether or not to unlock premium functionality to the user. To get subscription object (which contains expiration date, autorenew status, etc.) use the following method: 

```swift
Apphud.subscription()
```

 See `ApphudSubscription.swift` file for details.

## Restoring Purchases

If your app doesn't have a login system, which identifies a premium user by his credentials, then you need a restore mechanism. If you already have a restore purchases mechanism by calling `SKPaymentQueue.default().restoreCompletedTransactions()`, then you have nothing to worry about – Apphud SDK will automatically intercept and send latest App Store Receipt to Apphud servers when your restoration is completed. However, better to call our restore method from SDK:

```swift
Apphud.restoreSubscriptions{ subscriptions in 
   // handle here
}
```

Basically it just sends App Store Receipt to Apphud and returns subscriptions in callback (or `nil` if nothing was ever purchased).

## Setting up a Delegate

You can set up Apphud delegate by calling:

```swift
Apphud.setDelegate(self)
```

You can set a delegate at any time but after Apphud SDK has been initialized.

 See `Apphud.swift` file for details.

## Determing User Eligibility

You can use Apphud to determine if a user eligible to activate introductory or promotional offer:

```swift
// Checking eligibility for introductory offer
Apphud.checkEligibilityForIntroductoryOffer(product: myProduct) { result in
  if result {
    // User is eligible to purchase introductory offer
  }
}

// Checking eligibility for promotional offer
Apphud.checkEligibilityForPromotionalOffer(product: myProduct) { result in
  if result {
    // User is eligible to purchase promotional offer
  }
}
```

You may also check eligibility of multiple offers using just one SDK method: `checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: ApphudEligibilityCallback)` or `checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: ApphudEligibilityCallback)`

## Integrations

See the full set up guide if you need to add integrations with mobile analytics and messengers.

https://docs.apphud.com/getting-started/sdk-integration#user-identifier

https://docs.apphud.com/integrations/parameters-and-properties

## Pricing

Apphud is absolutely free unless you make $10K per month. You can check our pricing [here](https://apphud.com/pricing).

## Having troubles?

If you have any questions or troubles with SDK integration feel free to contact us. We are online.

https://apphud.com/contacts



*Like Apphud? Place a star at the top 😊*
