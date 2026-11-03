# Changelog

## 4.7.3

- A purchase of the subscription that is already active on the device (for example a promotional offer on the same product after the user turned off auto-renew) is no longer reported as successful when StoreKit 2 returns the existing transaction without contacting the App Store. It now fails with `APPHUD_SUBSCRIPTION_ALREADY_ACTIVE` (-990) and the transaction is not submitted again. StoreKit 2 answers this way in the same app session that bought the product; in a later session the purchase reaches the App Store.
- When the App Store does apply such a purchase (a new transaction, auto-renew turned back on, or the promotional offer scheduled for the next renewal), it is reported as successful once the device reflects the change, up to 10 seconds after the payment sheet closes.

## 4.7.2

- Deferred deep link attribution (`requestDeferredDeeplinkAttribution()`) no longer creates a hidden web view or sends `visitor_id`. This avoids a rare crash on first launch on iOS 27 (`NSInternalInconsistencyException` in Screen Time's `webBrowserSettings.hasPasscode` observer).
- The deferred result now arrives right after registration, without the web view's delay. Set the deep link handler (in `start(...)` or with `setDeeplinkHandler(_:)`) before calling `requestDeferredDeeplinkAttribution()`: a result that arrives while no handler is set is not delivered.

## 4.7.1

- Fix subscription purchases being skipped when the device clock is set ahead.
