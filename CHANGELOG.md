# Changelog

## 4.7.2

- Deferred deep link attribution (`requestDeferredDeeplinkAttribution()`) no longer creates a hidden web view or sends `visitor_id`. This avoids a rare crash on first launch on iOS 27 (`NSInternalInconsistencyException` in Screen Time's `webBrowserSettings.hasPasscode` observer).
- The deferred result now arrives right after registration. If no deep link handler is set yet, the SDK keeps the result and delivers it when one is set; calls made while a request is in flight are ignored.

## 4.7.1

- Fix subscription purchases being skipped when the device clock is set ahead.
