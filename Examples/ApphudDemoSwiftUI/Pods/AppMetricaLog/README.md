# [AppMetrica SDK](https://appmetrica.io)

[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/AppMetricaCore.svg?style=for-the-badge)](https://cocoapods.org/pods/AppMetricaCore)
[![SPM Index Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fappmetrica%2Fappmetrica-sdk-ios%2Fbadge%3Ftype%3Dswift-versions&style=for-the-badge)](https://swiftpackageindex.com/appmetrica/appmetrica-sdk-ios)
[![SPM Index Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fappmetrica%2Fappmetrica-sdk-ios%2Fbadge%3Ftype%3Dplatforms&style=for-the-badge)](https://swiftpackageindex.com/appmetrica/appmetrica-sdk-ios)

AppMetrica is a one-stop marketing platform for install attribution, app analytics, and push campaigns. AppMetrica provides the three key features for assessing your app's performance: ad tracking, usage analytics, and crash analytics.

## Installation

### Swift Package Manager

#### Through Xcode:

1. Go to **File** > **Add Package Dependency**.
2. Put the GitHub link of the AppMetrica SDK: https://github.com/appmetrica/appmetrica-sdk-ios.
3. In **Add to Target**, select **None** for modules you don't want.

#### Via Package.swift Manifest:

1. Add the SDK to your project's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/appmetrica/appmetrica-sdk-ios", from: "5.0.0")
],
```

2. List the modules in your target's dependencies:

```swift
.target(
    name: "YourTargetName",
    dependencies: [
        .product(name: "AppMetricaCore", package: "appmetrica-sdk-ios"),
        // Add other modules like AppMetricaCrashes if needed.
    ]
)
```

### CocoaPods

1. If you haven't set up CocoaPods, run `pod init` in your project directory.
2. In your Podfile, add AppMetrica dependencies:

```ruby
target 'YourAppName' do
    # For all analytics features, add this umbrella module:
    pod 'AppMetricaAnalytics', '~> 5.0.0'

    # If you need specific integration, skip 'AppMetricaAnalytics' and add specific modules:
    pod 'AppMetricaCore', '~> 5.0.0'
    # Add other modules like 'AppMetricaCrashes', 'AppMetricaWebKit' or 'AppMetricaAdSupport' if needed.
end
```

3. Install the dependencies using `pod install`.
4. Open your project in Xcode with the `.xcworkspace` file.

### Optional

#### Children's Apps:

To meet Apple's App Store rules regarding children's privacy (like COPPA), add AppMetrica but leave out the `AppMetricaAdSupport` module:

- **CocoaPods**:

  ```ruby
  pod 'AppMetricaCore', '~> 5.0.0'
  pod 'AppMetricaCrashes', '~> 5.0.0'
  pod 'AppMetricaWebKit', '~> 5.0.0'
  ```

- **SPM**: Don't include `AppMetricaAdSupport`. Either choose **None** for this module when selecting packages in Xcode or specify dependencies in `Package.swift`.

### Modules Overview

- `AppMetricaCore`: Required for basic SDK use.
- `AppMetricaCrashes`: Enables crash reports.
- `AppMetricaWebKit`: Used for handling events from WebKit.
- `AppMetricaAdSupport`: Needed for IDFA collection, don't include for children's apps.

## Integration Quickstart

Here's how to add AppMetrica to your project (works for both SwiftUI and UIKit):

1. `import AppMetricaCore` in your `AppDelegate`.

2. Initialize AppMetrica with your API key in the `application(_:didFinishLaunchingWithOptions:)` method.

### For UIKit:

Put this in your `AppDelegate.swift`:

```swift
import AppMetricaCore

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    if let configuration = AppMetricaConfiguration(apiKey: "Your_API_Key") {
        AppMetrica.activate(with: configuration)
    }
    return true
}
```

### For SwiftUI:

Create a new Swift file for `AppDelegate` compatibility and use this code:

```swift
import UIKit
import AppMetricaCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let configuration = AppMetricaConfiguration(apiKey: "Your_API_Key") {
            AppMetrica.activate(with: configuration)
        }
        return true
    }
}
```

Then in your `App` struct:

```swift
@main
struct YourAppNameApp: App {
    // Use the `@UIApplicationDelegateAdaptor` property wrapper to work with AppDelegate and set up AppMetrica
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Note:** Replace `"Your_API_Key"` with your actual AppMetrica API key, which is a unique identifier for your application provided in the [AppMetrica web interface](https://appmetrica.io/application/new) under **Settings**.

## Advanced Configuration

### Configure Sending of Events, Profile Attributes, and Revenue

- **Sending Custom Events**: To capture and analyze user actions within your app, you should configure the sending of custom events. For more information, see [Events](https://appmetrica.io/docs/en/data-collection/about-events).

- **User Profiles**: To gather insights into your user base, set up the sending of profile attributes. This allows for a richer analysis of user behavior segmented by custom attributes. Remember, a profile attribute can hold only one value, and sending a new value for an attribute will overwrite the existing one. For more information, see [User profile](https://appmetrica.io/docs/en/data-collection/about-profiles).

- **In-App Purchases (Revenue Tracking)**: To monitor in-app purchases effectively, configure the sending of revenue events. This feature enables you to comprehensively track transactions within your application. For setup details, see [In-app purchases](https://appmetrica.io/docs/en/data-collection/about-revenue).

## Testing the SDK integration

Before you move on to testing, it's advisable to isolate your test data from actual app statistics. Consider using a separate API key for test data by [sending statistics to an additional API key](https://appmetrica.io/docs/en/sdk/ios/analytics/ios-operations#reporter) or adding another app instance with a new API key in the AppMetrica interface.

### Steps to Test the Library's Operation:

1. **Launch the App**: Start your application integrated with the AppMetrica SDK and interact with it for a while to generate test data.

2. **Internet Connection**: Ensure that the device running the app is connected to the internet to allow data transmission to AppMetrica.

3. **Verify data in the AppMetrica Interface**: Log into the AppMetrica interface and confirm the following:
   - A new user has appeared in the [Audience](https://appmetrica.io/docs/en/mobile-reports/audience-report) report, indicating successful user tracking.
   - An increase in the number of sessions is visible in the **Engagement → Sessions** report, showing active app usage.
   - Custom events and profile attributes you've set up are reflected in the [Events](https://appmetrica.io/docs/en/mobile-reports/events-report) and [Profiles](https://appmetrica.io/docs/en/mobile-reports/profile-report) reports, which means that event tracking and user profiling are working as intended.

If you encounter any issues, please consult the [troubleshooting section](https://appmetrica.io/docs/en/sdk/ios/analytics/quick-start#step-4-test-the-library-operation).

## Documentation

You can find comprehensive integration details and instructions for installation, configuration, testing, and more in our [full documentation](https://appmetrica.io/docs/).

## License

AppMetrica is released under the MIT License.
License agreement is available at [LICENSE](LICENSE).
