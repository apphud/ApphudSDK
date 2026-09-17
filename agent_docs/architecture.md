# Architecture Details

Describes the code at tag `4.4.9` (the local checkout). Upstream `master` has since
moved to 4.5.0 with a StoreKit 2-only purchase engine; nothing below applies to that.

## Shape

One SPM target (`ApphudSDK`, path `Sources/`) with three folders that are conventions,
not modules: `Public/` (API surface + Codable models), `Internal/` (the engine),
`ApphudUI/` (iOS-only web-view screens, every file wrapped in `#if os(iOS)`).

Everything hangs off singletons:

- `ApphudInternal.shared` — the engine (`Internal/ApphudInternal.swift` + one
  `ApphudInternal+*.swift` extension per concern). Owns `currentUser`, `paywalls`,
  `placements`, `permissionGroups`, both delegates, all retry counters.
- `ApphudHttpClient.shared` — request builder + retry + host fallback.
- `ApphudStoreKitWrapper.shared` — StoreKit 1: `SKPaymentTransactionObserver`,
  `SKProductsRequest`, receipt refresh, payment swizzle.
- `ApphudAsyncStoreKit.shared` — StoreKit 2: `Product` cache, `product.purchase`,
  `Transaction.updates` listener.
- `ApphudDataActor.shared` — global actor that owns the Caches-directory files and the
  pending user-property queue.
- `ApphudScreensManager.shared` (iOS) — Rules screens and preloaded paywall screens.
- `ApphudLoggerService.shared` — paywall analytics events + load-time metrics.

## Public entry point

`Public/Apphud.swift` is a `final class Apphud: NSObject` of static methods; it never
holds state, every call forwards to `ApphudInternal.shared`.

- `start(apiKey:userID:observerMode:callback:deeplinkHandler:)` and
  `startManually(apiKey:userID:deviceID:observerMode:callback:deeplinkHandler:)` — the
  only difference is the explicit `deviceID`. Both are `@MainActor`.
- `ApphudDelegate` (`Public/ApphudDelegate.swift`) — subscriptions/purchases updated,
  `apphudDidChangeUserID`, `userDidLoad`, `paywallsDidFullyLoad`, `placementsDidFullyLoad`,
  App Store direct purchase, observed purchase, deferred transaction. All have empty
  default implementations. Stored **strongly** on `ApphudInternal.delegate`.
- `ApphudUIDelegate` (`Public/ApphudUIDelegate.swift`) — `@MainActor @objc`, all
  optional; Rules/Screens hooks (should perform rule, should show screen, parent VC,
  presentation style, purchase/dismiss/survey callbacks). Stored **weakly**.
- `ApphudUtils` (`Public/ApphudUtils.swift`) — log level, `useStoreKitV2()` flag,
  `optOutOfTracking`, log-to-file, `sdkVersion()`. `apphud_sdk_version` is the constant
  at the top of `Apphud.swift`.

## Initialization and user registration

```
Apphud.start(apiKey:userID:observerMode:)                 // Public/Apphud.swift
  └─> ApphudInternal.initialize(...)                       // Internal/ApphudInternal.swift
      ├─> iOS/tvOS: if Keychain unusable AND no UserDefaults ids AND app not active
      │     → park params in delayedInitilizationParams, retry on didBecomeActive
      ├─> ApphudStoreKitWrapper.setupObserver()   (SKPaymentQueue.add(self), once)
      ├─> httpClient = ApphudHttpClient.shared; apiKey set
      ├─> guard allowIdentifyUser (false after first start until logout())
      └─> identify(inputUserID:inputDeviceID:observerMode:)
          ├─> resolve deviceID / userID (see Identity)
          ├─> currentUser = ApphudUser.fromCacheV2()      (Caches/ApphudUser, 90-day TTL)
          ├─> load cached paywalls / placements / groups  (Caches/Apphud{Paywalls,Placements,ProductGroups})
          ├─> fetchCurrencyIfNeeded()                      // Internal/ApphudInternal+Currency.swift
          └─> continueToRegisteringUser(skipRegistration:)
              └─> registerUser()  → createOrGetUser(initialCall: true)   // Internal/ApphudInternal+UserUpdate.swift
                  ├─> skipRegistration == true → use cache, resubmit receipt if flagged, done
                  └─> updateUser(fields: [user_id, initial_call]) → POST /v1/customers
                      ├─> parseUser(data:) → currentUser, paywalls/placements, cache, checkUserID
                      ├─> success → performAllUserRegisteredBlocks, checkForUnreadNotifications
                      └─> failure → scheduleUserRegistering(errorCode:)   (see Retry)
```

`skipRegistration` is true only when the user id did not change, a cached user exists,
cached paywalls are not expired, `lastUserUpdatedAt` is within `cacheTimeout`
(5 s in sandbox, 90 000 s in production, overridable via `setPaywallsCacheTimeout`) and
the user has **no** subscriptions or purchases. Paid users always re-register.

`POST /v1/customers` body (`updateUser`, `Internal/ApphudInternal+UserUpdate.swift`)
carries device params from `apphudCurrentDeviceiOSParameters()` (locale, time zone,
device model, os/app/sdk versions, idfa/idfv when set and not opted out), plus
`device_id`, `is_debug`, `is_new`, `need_placements`, `opt_out`, `reinstall` (once),
`first_seen` (Documents-folder creation date), `bundle_id`, storefront currency fields.
`user_id` is sent only on the initial call, on `updateUserID`, and on web2web attribution.
HTTP 401 sets `invalidAPiKey`, 403 sets `unauthorized` + `suspended`; both stop retries.

**`performWhenUserRegistered(allowFailure:callback:)`** is the gate every feature sits
behind. If `currentUser` is nil the block is appended to `userRegisteredCallbacks`
(in-memory, `@MainActor`) and run after the first successful registration;
`allowFailure: true` blocks also run when registration gives up (`performAllUserFailedBlocks`).

## Identity

Files: `Internal/ApphudInternal.swift` (`identify`, `logout`), `Internal/ApphudKeychain.swift`,
`Internal/ApphudInternal+UserUpdate.swift` (`checkUserID`, `updateUserID`), `Public/ApphudUser.swift`.

### Storage

`ApphudKeychain` writes each id to **two** places: `UserDefaults.standard`
(`com.apphud.device_id`, `com.apphud.user_id`) and a Keychain generic-password item
(service `ApphudDeviceID` / `ApphudUserID`, account `ApphudUser`,
`kSecAttrAccessibleAfterFirstUnlock`, no access group). Reads prefer UserDefaults and
fall back to Keychain only when `canUseKeychain` (iOS/tvOS: `isProtectedDataAvailable`;
macOS: always false; other platforms: always true). Empty strings count as "not set".

### Resolution at `identify` (`ApphudInternal.swift`)

```
deviceID = ApphudKeychain.loadDeviceID()          // UserDefaults → Keychain
isFreshInstall = (deviceID == nil)
isRedownload   = deviceID != nil && UserDefaults["ApphudReinstallFlag"] == nil
if inputDeviceID non-empty  → deviceID = inputDeviceID
generatedUUID = NSUUID().uuidString               // UPPERCASE, one value reused below
if deviceID == nil          → deviceID = generatedUUID; saveDeviceID

userID = inputUserID                              // 1. explicit
      ?? cachedUser.userId                        // 2. Caches/ApphudUser
      ?? ApphudKeychain.loadUserID()              // 3. UserDefaults → Keychain
      ?? generatedUUID                            // 4. SAME value as a fresh deviceID
```

Consequences worth knowing:

- On a clean install with no `userID` passed, **userID == deviceID byte-for-byte**, and
  both are uppercase UUID strings (`NSUUID().uuidString`).
- `inputDeviceID` overrides the stored device id but is never itself persisted unless the
  stored one was nil — `saveDeviceID` runs only in the `deviceID == nil` branch.
- The user id is written to Keychain/UserDefaults only when it differs from what the
  Keychain already had (`isIdenticalUserIds` check in `identify`).
- `currentCustomerID` mirrors `currentUser.internalId` (the backend `id`) and is added as
  `customer_id` to every request body / query (`ApphudHttpClient.makeRequest`). It is
  distinct from `userId`; `ApphudUser.internalId` is documented "should not be used in analytics".

### Server-driven changes (`checkUserID`, `+UserUpdate.swift`)

Every `parseUser` ends with `checkUserID(tellDelegate: true)`: if the response `user_id`
differs from `currentUserID`, the SDK adopts the server value, saves it to
Keychain/UserDefaults and calls `ApphudDelegate.apphudDidChangeUserID`. This is how a
backend merge (same receipt seen under another user) renames the local user. It also fires
after `updateUserID` and after web2web attribution.

### `updateUserID(_:callback:)` (`+UserUpdate.swift`)

Waits for registration, no-ops if the id is unchanged, otherwise
`POST /v1/customers` with `user_id` (plus the usual device params) → `parseUser` →
`checkUserID` → delegate. `deviceID` is untouched. The callback receives `currentUser`
(possibly the old one if the request failed).

### `logout()` (`ApphudInternal.swift`, `async`)

Clears, in order: `ApphudDataActor` (AF/Adjust attribution caches, user-properties
cache), Keychain + UserDefaults ids (`resetValues` writes `""` to both — **only if
`canUseKeychain`**, otherwise nothing is reset), the cached user file (v2 and legacy),
`currentUserID`/`currentDeviceID` = `""`, paywalls/placements caches and in-memory
arrays, `currentUser`, premium flags, all pending callback arrays,
`lastUploadedTransactions`, pending user properties, retry counters, attribution
"submitted" flags, push token, `observerModePurchaseIdentifiers`; then
`allowIdentifyUser = true`. **Not cleared:** `permissionGroups` and its cache (comment:
"never change"), `ApphudReinstallFlag`, `lastUserUpdatedAt`, `requiresReceiptSubmissionKey`,
`ApphudKnownProductTypes`, IDFA/IDFV `submittedDeviceIdentifiers`, `swizzlePaymentDisabledKey`,
the `Transaction.updates` listener, and the `ApphudDelegate`/`ApphudUIDelegate` references.

The next `start` therefore behaves like a fresh install: `loadDeviceID()` returns nil
(empty string is filtered), so a **new device id is minted** and `isFreshInstall = true`
(`isRedownload` is false because the device id is nil). The doc comment on
`Apphud.logout()` states that if the previous user had an active subscription, the new
user's restore will merge both under the subscriber's account.

### Identity on the StoreKit side

`ApphudStoreKitWrapper.appropriateApplicationUsername()` returns `currentUserID` when it
parses as a `UUID`, otherwise `currentDeviceID`, and only when the payment queue has been
swizzled. That value goes into `SKMutablePayment.applicationUsername` (swizzle, SK1),
`Product.PurchaseOption.appAccountToken(UUID)` (SK2), and `application_username` in the
`/v1/sign_offer` request. A non-UUID user id silently falls back to the device id.

## Paywalls, placements, products

Files: `Internal/ApphudInternal+Product.swift`, `Internal/ApphudStoreKitWrapper.swift`,
`Internal/ApphudAsyncStoreKit.swift`, `Internal/ApphudProductsStorage.swift`,
`Public/ApphudPaywall.swift`, `Public/ApphudPlacement.swift`, `Public/ApphudProduct.swift`,
`Public/ApphudGroup.swift`.

```
POST /v1/customers response → ApphudUser.paywalls / .placements (Codable)
  └─> parseUser → preparePaywalls(pwls:writeToCache:)          // +Product.swift
      ├─> enableSwizzle() unless swizzle_disabled (server) or Flutter+observer
      ├─> self.paywalls / self.placements; cache to Caches/ (Task.detached)
      ├─> first time: delegate.userDidLoad(user:)
      └─> performWhenStoreKitProductFetched(maxAttempts:)
          └─> continueToFetchStoreKitProducts
              ├─> ids = allAvailableProductIDs() (paywalls ∪ placements ∪ permissionGroups)
              ├─> ApphudStoreKitWrapper.fetchAllProducts → SKProductsRequest (3 in-fetcher retries)
              └─> handleDidFetchAllProducts → updatePaywallsAndPlacements()
                  ├─> ApphudPaywall.update(placementId:) sets product.skProduct,
                  │     paywallId/placementId/experimentId/variationIdentifier
                  └─> delegate.paywallsDidFullyLoad / placementsDidFullyLoad
```

- `Apphud.placements()` / `fetchPlacements` / `preloadPaywallScreens` all go through
  `fetchOfferingsFull(maxAttempts:)`, which waits for registration then for SKProducts.
  `deferPlacements()` makes the initial `/customers` call send `need_placements: false`;
  the next `fetchOfferingsFull` re-registers with placements.
- Permission groups come from `GET /v3/products` (`fetchPermissionGroups`), cached to
  `Caches/ApphudProductGroups`; used to widen the SKProduct id set and for `ApphudGroup.hasAccess`.
- Single paywall by identifier: `GET /v2/paywall_configs/{id}` (`fetchPaywall`), used by Rules.
- Product macros (`ApphudProduct.properties`, per locale) are rendered server-side via
  `POST /v2/paywall_configs/items/render_properties` (`getRenderedProperties`) when a
  value contains `{`.
- SK2 `Product`s live in `ApphudProductsStorage` (actor, `Set<Product>`), fetched via
  `Product.products(for:)`; `Apphud.fetchProducts()` and `ApphudProduct.product()` read it.
- Fallback (`Internal/ApphudInternal+Fallback.swift`): when registration keeps failing
  (`serverIsUnreachable` and attempts ≥ max or > `APPHUD_MAX_INITIAL_LOAD_TIME` 10 s)
  `executeFallback` synthesises an `ApphudUser(userID:)`, releases the registration
  queue, and loads paywalls from cache or from `apphud_paywalls_fallback.json` in the
  app bundle. In `fallbackMode` a failed receipt upload becomes `stubPurchase` — a
  1-hour stub subscription/purchase (`groupId == "apphud_stub"`) cached as the user.

## Purchase paths

Files: `Internal/ApphudInternal+Purchase.swift`, `Internal/ApphudStoreKitWrapper.swift`,
`Internal/ApphudAsyncStoreKit.swift`.

### StoreKit 1 (default)

```
Apphud.purchase(ApphudProduct, callback:)                    // Public/Apphud.swift
  └─> ApphudInternal.purchase(productId:product:validate:purchasingFromScreen:)
      ├─> skProduct = product.skProduct ?? wrapper.products[...] ?? re-fetch by id
      └─> purchase(product:apphudProduct:validate:fromScreen:)        (private)
          ├─> LoggerService.paywallCheckoutInitiated  (event paywall_checkout_initiated)
          ├─> purchasingProduct = apphudProduct
          ├─> if apphudProduct.isCommitmentPlanPreferred() || ApphudUtils.useStoreKitV2
          │     → purchaseAsync(...) (StoreKit 2 path below), return
          └─> ApphudStoreKitWrapper.purchase(product:value:callback:)
              ├─> storeKitObserverMode = false; finishCompletedTransactions(for: id)
              ├─> paymentCallback = callback; purchasingProductID = id
              └─> SKPaymentQueue.default().add(SKMutablePayment)   ← swizzled add
                  └─> paymentQueue(_:updatedTransactions:)  (hops to MainActor)
                      .purchased/.failed → handleTransactionIfStarted → paymentCallback
                        └─> ApphudInternal.handleTransaction(product:transaction:error:)
                            ├─> .purchased or failedWithUnknownReason → submitReceipt(...)
                            │     → callback(ApphudPurchaseResult); finishTransaction
                            └─> else callback(purchaseResult(...)); finishTransaction
```

`ApphudPurchaseResult` (`Public/ApphudPurchaseResult.swift`) is built by
`purchaseResult(productId:transaction:error:)`: the subscription is looked up by product
id, then by `subscriptionGroupIdentifier`; `success` = no error and an active
subscription/purchase.

Promo offers: `purchasePromo` → `POST /v1/sign_offer` (`signPromoOffer`) →
`SKPaymentDiscount` → same wrapper path with `payment.paymentDiscount`.

### StoreKit 2

```
Apphud.purchase(Product, prefersCommitmentPlan:isPurchasing:) async     // Public/Apphud.swift
  └─> ApphudAsyncStoreKit.purchaseResult(product:commitmentPlan:apphudProduct:fromScreen:)
      ├─> options: .appAccountToken(UUID from appropriateApplicationUsername()),
      │            .billingPlanType(.monthly) on iOS 26.4+ when commitment plan supported
      ├─> product.purchase(options:)  (visionOS: confirmIn: scene)
      ├─> .success(.verified|.unverified) → processTransaction
      │     ├─> ApphudInternal.handleTransaction(Transaction)   → submitReceipt(...)
      │     └─> transaction.finish()  (consumables: after a 3 s sleep)
      ├─> .userCancelled → event paywall_payment_cancelled, StoreKitError.userCancelled
      └─> asyncPurchaseResult(product:transaction:error:) → ApphudAsyncPurchaseResult
```

`handleTransaction(_ transaction: StoreKit.Transaction)` de-duplicates against the
current user's known transactions (`isAlreadyTracked`: same product and purchase date
within 2 s, or same original transaction id) and against
`lastUploadedTransactions` (UserDefaults `ApphudLastUploadedTransactions`), submits only
active transactions, and passes `transactionState: .purchased` only when the purchase is
less than one hour old.

`ApphudAsyncTransactionObserver` (created with `ApphudAsyncStoreKit.shared`) iterates
`Transaction.updates` on a background Task. Outside observer mode it ignores the product
currently being bought through SK1 and otherwise runs `processTransaction`; in observer
mode it calls `handleTransaction` (no finish). Unverified transactions trigger
`setNeedToCheckTransactions`. `checkTransactionsNow` (on app active, debounced 0.5 s)
fetches the latest verified transaction from `Transaction.all` and submits it.

### Observer mode

Purchases not started by the SDK reach `handleTransactionIfStarted`'s else-branch:
`.purchased` → `submitReceiptAutomaticPurchaseTracking` → `ApphudDelegate.apphudDidObservePurchase(result:)`
decides whether the SDK finishes the transaction (also finished when observer mode is
off and the upload succeeded). `Apphud.willPurchaseProductFrom(paywallIdentifier:placementIdentifier:)`
stores `observerModePurchaseIdentifiers`, which `submitReceipt` uses to attach
`paywall_id`/`placement_id`/`experiment_id` to the upload. If the wrapper sees a
`.purchasing` transaction it did not start while observer mode is off, it force-enables
observer mode. `setCustomPurchaseValue` attaches `custom_purchase_value` to `product_info`.

### Restore

```
Apphud.restorePurchases(callback:)
  └─> ApphudInternal.restorePurchases → restorePurchasesCallback stored
      └─> submitReceiptRestore(allowsReceiptRefresh: true, transaction: nil)
          ├─> receipt present → submitReceipt(receipt only, id "Restoration")
          ├─> receipt missing → SKReceiptRefreshRequest → requestDidFinish/didFail
          │     → submitReceiptRestore(allowsReceiptRefresh: false)  (unrefreshed receipt is fine)
          └─> callback error != nil → SKPaymentQueue.restoreCompletedTransactions()
                → .restored transactions → submitReceiptRestore(transaction: trx.original ?? trx)
```

The result is an `ApphudPurchaseResult` with `isRestoreResult = true` carrying the first
active subscription/purchase. `migrateiOS14PurchasesIfNeeded` runs a restore once on
pre-iOS 15 only.

## Receipt / transaction submission

`submitReceipt(product:apphudProduct:transactionIdentifier:transactionProductIdentifier:transactionState:receiptString:notifyDelegate:eligibilityCheck:fromScreen:callback:)`
(`Internal/ApphudInternal+Purchase.swift`) is the single upload:

- `POST /v1/subscriptions` with `device_id`, `user_id`, `environment`, `observer_mode`,
  `bundle_id`, `receipt_data` (base64 `appStoreReceiptURL`; omitted when
  `useStoreKitV2` and a transaction id exists), `transaction_id`, `product_info`
  (`SKProduct.apphudSubmittableParameters` — price, currency, period, intro, promo offers),
  and for real purchases `product_bundle_id`, `paywall_id`, `placement_id`,
  `variation_identifier`, `experiment_id`, `screen_id` (from screen), `rule_id`.
- Serialised by `submittingTransaction`: a second call while one is in flight only
  appends its callback to `submitReceiptCallbacks` (all callbacks fire on completion).
- On success → `parseUser` → delegates. On failure → `lastUploadedTransactions = []`,
  `scheduleSubmitReceiptRetry` (delay = attempt count in seconds, via
  `perform(afterDelay:)`, unbounded while `canRetry`).
- `requiresReceiptSubmission` (UserDefaults `requiresReceiptSubmissionKey`) is set to
  true before the request and false on success; `createOrGetUser` re-submits the receipt
  on every registration while it is true — the only persistence of "upload pending".

## HTTP layer

`Internal/ApphudHttpClient.swift`, `Internal/ApphudURLSession.swift`,
`Internal/ApphudInternal+Fallback.swift` (gateway host fallback).

- Base `https://gateway.apphud.com` (`domainUrlString`, public, mutable). Path
  `/{v1|v2|v3}/{endpoint}`; `ApphudEndpoint` enumerates every route.
- Headers: `APPHUD-API-KEY`, `X-Platform` (`ios`/`macos`), `X-SDK` (`sdkType`, default
  `swift`; `flutter` changes behaviour), `X-SDK-VERSION`, `User-Agent`,
  `Idempotency-Key` (fresh UUID per request; the initial `/customers` call reuses
  `initialRequestID` across retries). The response's `idempotency-key` must echo the
  request's or the response is rejected as "Invalid HTTP Response".
- `api_key` and `customer_id` are also placed in every body (POST/PUT) or query (GET).
- Timeouts: GET 7 s, POST 20 s, `POST /customers` 7 s (`POST_CUSTOMERS_TIMEOUT`, public).
- `URLSession` with caching disabled; `useDecoder: true` skips the `[String: Any]`
  parse in production so Codable models read `Data` directly.
- **Retry** (`URLSession.data(for:retries:delay:)`): only for calls passing
  `retry: true`; `retries = customRegistrationAttemptsCount ?? 3`, 1 s fixed delay, on
  5xx or network-unreachable/unknown errors. 422 bodies are parsed into `ApphudError`
  (`errors[0].id + title`).
- **No persistent request queue.** Nothing is written to disk for replay. Durable retry
  exists only as flags (`requiresReceiptSubmissionKey`) and the in-memory registration
  loop: `scheduleUserRegistering` re-runs `registerUser` via `perform(afterDelay:)` with
  0.5 s / 1 s / 0.5·n delays (×2 in fallback mode), up to `APPHUD_INFINITE_RETRIES`.
- **Gateway host fallback**: when `.customers`, `.subscriptions` or `.attribution` fail
  with a host-unreachable code, `loadFallbackHostIfNeeded` downloads
  `https://apphud.blob.core.windows.net/apphud-gateway/fallback.txt` and swaps
  `domainUrlString` for the session (not persisted; skipped if the developer overrode the host).
- `connectDomainUrl` (default `https://connect.aphd.cc`, updated from `meta.connect_url`
  in the `/customers` response, persisted in UserDefaults) is used by web-to-app only.
- Screen HTML (`/preview_screen/{id}`) is fetched separately and cached as
  `Caches/{id}.html` with the paywalls `cacheTimeout`.

## Persistence map

| Where | Key / file | Written by |
| --- | --- | --- |
| Keychain + UserDefaults | `ApphudDeviceID`/`com.apphud.device_id`, `ApphudUserID`/`com.apphud.user_id` | `ApphudKeychain` |
| Caches/ (via `ApphudDataActor`) | `ApphudUser` (90 d), `ApphudPaywalls`, `ApphudPlacements`, `ApphudProductGroups` (`cacheTimeout`), `ApphudUserPropertiesCache`, `submittedAFDataKey`, `submittedAdjustDataKey` (7 d), `{screenId}.html` | `+Product`, `ApphudUser.toCacheV2`, `+UserUpdate`, `+Attribution`, `ApphudHttpClient` |
| UserDefaults | `ApphudReinstallFlag`, `lastUserUpdatedAt`, `requiresReceiptSubmissionKey`, `ApphudLastUploadedTransactions`, `ApphudKnownProductTypes`, `swizzlePaymentDisabledKey`, `submittedDeviceIdentifiersKey`, `submittedPushTokenKey`, `submittedFirebaseIdKey`, `submittedFacebookAnonIdKey`, `didSubmit{AppsFlyer,Adjust,AppleAds}AttributionKey`, `ReceiptForIntroSent`, `ReceiptForPromoSent`, `ApphudSubscriptionsMigrated`, `ApphudMigrateCachesKey`, `ApphudConnectDomainUrl`, `apphud_installation_date` (read-only override) | various |
| Bundle | `apphud_paywalls_fallback.json` (read only) | host app |

Legacy user cache (`ApphudUser.data`, NSKeyedArchiver, Application Support or Caches)
is migrated once to `Caches/ApphudUser` (`ApphudMigrateCachesKey`).

## SKPaymentQueue observation and swizzling

`ApphudStoreKitWrapper` (`Internal/ApphudStoreKitWrapper.swift`):

- Added as `SKPaymentTransactionObserver` in `initialize` (once per process).
  `updatedTransactions` sorts `.purchased` first and processes on the main actor.
  `.restored` transactions are always uploaded and finished unless observer mode is on.
  `removedTransactions` posts `_ApphudDidFinishTransactionNotification`; `finishTransaction`
  posts `_ApphudWillFinishTransactionNotification` before `SKPaymentQueue.finishTransaction`.
- `shouldAddStorePayment` (App Store promoted IAP, iOS only) returns `false` and, if the
  delegate returns a callback from `apphudShouldStartAppStoreDirectPurchase`, starts the
  purchase through the SDK.
- **Swizzle**: `SKPaymentQueue.doSwizzle()` exchanges `add(_:)` with `apphudAdd(_:)`
  (`method_exchangeImplementations`, guarded by a process-wide flag). `apphudAdd` copies
  the payment to `SKMutablePayment` and sets `applicationUsername` to
  `appropriateApplicationUsername()` unless the host already set a UUID there. Enabled
  from `preparePaywalls`, i.e. after the first user load, unless the server sent
  `swizzle_disabled: true` or the SDK is Flutter in observer mode.
- Receipt refresh: `SKReceiptRefreshRequest`; with no explicit callback the request
  delegate re-enters `submitReceiptRestore(allowsReceiptRefresh: false)`.
- SK1 products are cached in `products` behind a concurrent `DispatchQueue` with barrier
  writes; per-request `ApphudProductsFetcher` objects retry 3 times and are kept alive in
  an `ApphudSafeSet`.

## Attribution, device identifiers, user properties, web-to-app

`Internal/ApphudInternal+Attribution.swift`, `Internal/ApphudInternal+UserUpdate.swift`,
`Internal/ApphudWebController.swift`.

- `setAttribution(data:from:identifer:)` → `POST /v2/customers/attribution` with
  `provider`, `raw_data` and the normalised `attribution` dict from `ApphudAttributionData`.
  Per-provider de-duplication: AppsFlyer/Adjust compare the whole payload to a 7-day file
  cache and rate-limit re-sends (5 s / 1 s); Firebase/Facebook remember the last id;
  Apple Ads resolves the token against `https://api-adservices.apple.com/api/v1/`
  (5 retries, 7 s delay) and sends once. A 1 s sleep precedes every attribution request.
- `setDeviceIdentifiers(idfa:idfv:)` stores the pair in memory, remembers the last
  submitted pair in UserDefaults, and when changed flips `setNeedsToUpdateUser` →
  `POST /v1/customers` after a 3 s debounce. The same debounce is used by storefront
  currency changes and the "paid user, cache expired" refresh on app active.
- User properties: `setUserProperty`/`incrementUserProperty` queue an
  `ApphudUserProperty` in `ApphudDataActor.pendingUserProps` (last write per key wins),
  then after 2 s `flushUserProperties` → `POST /v1/customers/properties`. A cached copy
  of the last successful payload suppresses unchanged uploads; increments bypass the cache.
  `forceFlushUserProperties` sends immediately with `force: true`.
- Push: `submitPushNotificationsToken` → `PUT /v1/customers/push_token`, de-duplicated by
  the last token in UserDefaults.
- Web-to-app: `attributeFromWeb(data:)` (`tryWebAttribution`) reads `aph_user_id`/
  `apphud_user_id`/`email` and re-registers with `from_web2web: true` and that `user_id`
  (→ `checkUserID` → `apphudDidChangeUserID`). Deep-link attribution:
  `handleOpen(url:)`/`handleLaunchOptions`/`continueUserActivity` →
  `POST /v2/customers/deeplink_attribution` with `url` (kind `.direct`);
  `requestDeferredDeeplinkAttribution` presents a hidden 1×1 `WKWebView`
  (`ApphudWebController`, iOS 15+, app must be active with a visible controller, 10 s
  timeout, 3 readiness retries) that loads `connectDomainUrl?api_key&device_id&host`,
  evaluates `getConnectId()` and posts the `visitor_id` to the same endpoint (kind
  `.deferred`). Results reach the `ApphudDeeplinkHandler` set in `start`/`setDeeplinkHandler`.
- Eligibility (`+Eligibility.swift`): intro via SK2 `subscription.isEligibleForIntroOffer`;
  promo via user subscriptions or `Transaction.all` group match. If the user has no
  subscriptions the receipt is uploaded once first (`ReceiptForIntroSent`/`ReceiptForPromoSent`).
- Currency (`+Currency.swift`): `Storefront.current` (0.3 s timeout) → `store_id` +
  `country_code_alpha3` on the next `/customers` call; legacy fallback reads
  `SKProduct.priceLocale`.

## ApphudUI: Rules screens and paywall screens (iOS only)

`Sources/ApphudUI/` plus `Public/ApphudPaywallScreenController.swift`,
`Public/ApphudRule.swift`, `Public/ApphudRuleScreen.swift`, `Public/ApphudPaywallScreen.swift`.
Not a separate SPM target — same module, `#if os(iOS)`.

### Rules

```
registerUser success / app active (≥60 s apart) / ApphudUtils.checkRules()
  └─> checkForUnreadNotifications → GET /v2/notifications           // ApphudInternal.swift
      └─> ApphudRule(dictionary:) → ApphudScreensManager.handleRule(rule:)   // ApphudUI/ApphudScreensManager.swift
          ├─> uiDelegate.apphudShouldPerformRule? == false → readAllNotifications, stop
          ├─> rule has paywall_id/paywall_identifier (new style)
          │     → fetchPaywall(identifier:) → hasVisualPaywall()
          │         ├─> no screen → uiDelegate.apphudRuleWithoutPaywallScreen
          │         └─> Apphud.fetchPaywallScreen → ApphudPaywallScreenController(rule:)
          └─> legacy: ApphudScreenController(rule:screenID:) inside ApphudNavigationController
                → loadScreenPage → GET /preview_screen/{id} HTML
          → pendingController; uiDelegate.apphudShouldShowScreen? → showPendingScreen()
             (parent from apphudParentViewController? or apphudVisibleViewController())
```

Push: `Apphud.handlePushNotification(apsInfo:)` with `rule_id` (+ `screen_id` /
`paywall_id` / `paywall_identifier`) → event `$push_opened` → `handleRule`; deferred
until the app is active. Legacy screens replace `{{"product_id" | price:offer}}` macros
with localised `SKProduct` prices (`ApphudScreenController+Macros.swift`), route in-page
URLs by last path component (`action` purchase/restore/dismiss/post_feedback/billing_issue,
`screen` push, `link` → `SFSafariViewController`), and post `$screen_presented`,
`$purchase`, `$survey_answer`, `$feedback`, `$billing_issue` to `POST /v2/events`.
`readAllNotifications` (`POST /v2/notifications/read`) marks the rule consumed.

### Paywall screens (Figma paywalls)

```
Apphud.preloadPaywallScreens(placementIdentifiers:)  /  Apphud.fetchPaywallScreen(paywall)
  └─> ApphudScreensManager.requestPaywallController(paywall:cachePolicy:)
      ├─> reuse pendingPaywallControllers[paywall.identifier] if loading/ready
      ├─> guard paywall.screen?.paywallURL (locale-specific URL + live=true)
      └─> ApphudPaywallScreenController(paywall:).load()                // Public/ + ApphudUI/…+I.swift
          ├─> ApphudView (WKWebView) loads paywallURL with cachePolicy
          ├─> productsInfo(): wait for SKProducts, renderPropertiesIfNeeded, merge
          │     apphudSubmittableParameters + jsonProperties per product
          ├─> on both loaded: PaywallSDK.shared().processDomMacros(json) + applyCustomInsets
          └─> state .ready / .error (timeout APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT 10 s)
```

The web page talks back through navigation to host `pay.apphud.com`:
`/purchase/{index}` → `ApphudInternal.purchase(... purchasingFromScreen: true)`,
`/restore` → `Apphud.restorePurchases`, `/close` → `onCloseButtonTapped` + dismiss.
Other hosts open in `SFSafariViewController` unless `onShouldOpenURL` returns false.
Callbacks: `onTransactionStarted`, `onTransactionCompleted`, `onCloseButtonTapped`;
flags `shouldAutoDismiss`, `shouldPopOnDismiss`, `useSystemLoadingIndicator`
(`ApphudLoadingView`, 30 s auto-hide). `viewDidAppear` logs `paywall_shown` (unless a
Rule opened it) and evicts the preloaded entry; `viewWillDisappear` re-preloads the same
paywall if the user is still not premium; a successful purchase unloads all preloads.
`ApphudPaywallView` wraps the controller for SwiftUI (`Apphud.fetchPaywallView`).

## Analytics events

`ApphudLoggerService` (`Internal/ApphudLoggerService.swift`) sends paywall events through
`ApphudInternal.trackPaywallEvent` → `POST /v2/events` (with `retry: true`, duplicate
suppression within 2 s): `paywall_shown`, `paywall_closed`, `paywall_checkout_initiated`,
`paywall_payment_cancelled`, `paywall_payment_error`, and once per fresh install/redownload
`paywall_products_loaded` with load-time metrics (`launched_at`, `user_load_time`,
`products_load_time`, `total_load_time`, `products_count`, `result`).
`trackDurationLogs` (`POST /v3/logs`) is defined but has no callers.

## Threading model

- **Main actor is the home of SDK state.** `ApphudInternal.currentUser`, `paywalls`,
  `placements`, `permissionGroups`, the callback arrays, `initialize`/`identify`,
  `updateUser`, `preparePaywalls`, `performWhenStoreKitProductFetched`, all of
  `ApphudScreensManager` and the public `start`/`purchase`/`placements` APIs are
  `@MainActor`. Non-isolated properties on `ApphudInternal` (`currentUserID`,
  `currentDeviceID`, `currentCustomerID`, retry counters, flags) are plain `var`s read
  from any thread; `currentCustomerID` exists precisely so `ApphudHttpClient` can read
  the customer id off the main actor.
- **HTTP callbacks always land on the main actor**: `ApphudHttpClient.startRequest`
  runs the request in a `Task(priority: .userInitiated)` and delivers the result with
  `Task { @MainActor in callback(...) }`. Delegate methods and public callbacks are
  therefore called on main.
- **Off-main state is actor-owned**: `ApphudDataActor` (global actor: Caches files,
  pending user properties, attribution caches, known product types),
  `ApphudProductsStorage` (SK2 products). Two `DispatchQueue`-with-barrier containers
  remain for SK1: `ApphudStoreKitWrapper.products` and `ApphudSafeSet`.
- **StoreKit callbacks** (`SKPaymentTransactionObserver`, `SKRequestDelegate`,
  `SKProductsRequestDelegate`) arrive on StoreKit's thread and immediately hop:
  `Task { @MainActor in }` for transactions, `DispatchQueue.main.async` for receipt refresh.
  `Transaction.updates` is consumed on a `Task(priority: .background)` and hops to main.
- **Scheduling is run-loop based**: debounces and retries use
  `NSObject.perform(#selector, afterDelay:)` / `cancelPreviousPerformRequests` on main
  (`updateCurrentUser` 3 s, `updateUserProperties` 2 s, `checkTransactionsNow` 0.5 s,
  `registerUser` and `submitAppStoreReceipt` retries, `forceSendAttributionDataIfNeeded`
  10 s — a no-op since 3.2.8). `performWhenUserRegistered` and
  `performAllUserRegisteredBlocks` use `Task.detached { @MainActor in }` to defer to
  the next run-loop turn. `ApphudLoggerService` batches metrics with a 5 s `Timer`.
- Async/await bridges: `withUnsafeContinuation` wraps the callback engine for the
  `async` public API; `Task.detached(priority: .userInitiated)` starts registration.
