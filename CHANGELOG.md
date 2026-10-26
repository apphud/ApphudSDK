# Changelog

## 4.7.2

- Deferred deep link attribution (`requestDeferredDeeplinkAttribution()`) no longer creates a hidden web view or sends `visitor_id`. This avoids a rare crash on first launch on iOS 27 (`NSInternalInconsistencyException` in Screen Time's `webBrowserSettings.hasPasscode` observer).
- The deferred result now arrives right after registration, without the web view's delay. Set the deep link handler (in `start(...)` or with `setDeeplinkHandler(_:)`) before calling `requestDeferredDeeplinkAttribution()`: a result that arrives while no handler is set is not delivered.

## 4.7.1

- Fix subscription purchases being skipped when the device clock is set ahead.
