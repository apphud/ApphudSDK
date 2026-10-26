# Changelog

## 4.7.2

- Deferred deep link attribution (`requestDeferredDeeplinkAttribution()`) no longer creates a hidden web view. This fixes a rare crash on first launch on iOS 27 (`NSInternalInconsistencyException` in Screen Time's `webBrowserSettings.hasPasscode` observer).

## 4.7.1

- Fix subscription purchases being skipped when the device clock is set ahead.
