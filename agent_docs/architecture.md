# Architecture Details

Describes the code at tag `4.5.0` (the local checkout). 4.5.0 made StoreKit 2 the only
purchase engine; StoreKit 1 remains for observer-mode tracking of the host app's own
payments, the payment swizzle, receipt refresh and the deprecated `SKProduct` surface.

## Shape

One SPM target (`ApphudSDK`, path `Sources/`) with three folders that are conventions,
not modules: `Public/` (API surface + Codable models), `Internal/` (the engine),
`ApphudUI/` (iOS-only web-view screens behind `#if os(iOS)`; per-file guards are listed
in structure.md).

Everything hangs off singletons:

- `ApphudInternal.shared` — the engine (`Internal/ApphudInternal.swift` + one
  `ApphudInternal+*.swift` extension per concern). Owns `currentUser`, `paywalls`,
  `placements`, `permissionGroups`, both delegates, all retry counters.
- `ApphudHttpClient.shared` — request builder + retry + host fallback.
- `ApphudStoreKitWrapper.shared` — StoreKit 1 compatibility: `SKPaymentTransactionObserver`
  for transactions the SDK did not start, `SKProductsRequest` "feeder" that fills the
  deprecated `ApphudProduct.skProduct`, receipt refresh, payment swizzle. It no longer
  initiates purchases.
- `ApphudAsyncStoreKit.shared` — StoreKit 2, the only purchase engine: `Product` cache,
  `product.purchase(options:)`, per-transaction submission single-flight,
  `Transaction.updates` and `PurchaseIntent.intents` listeners.
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
  App Store direct purchase (`apphudShouldStartAppStoreDirectPurchase(product: Product)`,
  iOS 16.4+/macOS 14.4+; the `SKProduct` overload is deprecated and only used as a
  fallback), observed purchase, deferred transaction (deprecated — only fires for the host
  app's own StoreKit 1 transactions). All have empty default implementations. Stored
  **strongly** on `ApphudInternal.delegate`.
- `ApphudUIDelegate` (`Public/ApphudUIDelegate.swift`) — `@MainActor @objc`, all
  optional; Rules/Screens hooks (should perform rule, should show screen, parent VC,
  presentation style, purchase/dismiss/survey callbacks). The purchase callbacks exist
  twice: deprecated `SKProduct`-based variants (called only when the SK1 feeder has the
  product) and `productId:`-based variants (always called). Stored **weakly**.
- `ApphudUtils` (`Public/ApphudUtils.swift`) — log level, `optOutOfTracking`,
  log-to-file, `sdkVersion()`. `useStoreKitV2()` is a deprecated no-op.
  `apphud_sdk_version` is the constant at the top of `Apphud.swift`.
- Result types: `ApphudPurchaseResult.transaction` (`SKPaymentTransaction`) is deprecated
  and always nil for SDK purchases; `transactionV2` (`StoreKit.Transaction`) and
  `isPending` (Ask to Buy / SCA) carry the outcome. `ApphudAsyncPurchaseResult` has the
  same `isPending`.
- Deprecated `SKProduct` surface, still functional through the feeder:
  `fetchSKProducts`, `fetchProducts(maxAttempts:_:)`, `Apphud.products`,
  `product(productIdentifier:)`, `purchasePromo(_ skProduct:...)`, the `SKProduct`-based
  eligibility checks. Their StoreKit 2 replacements are `fetchProducts() async throws ->
  [Product]`, `ApphudProduct.product()`, `purchasePromo(_ product: Product, discountID:)`
  and the `productIds:` eligibility methods.

## Initialization and user registration

```
Apphud.start(apiKey:userID:observerMode:)                 // Public/Apphud.swift
  └─> ApphudInternal.initialize(...)                       // Internal/ApphudInternal.swift
      ├─> iOS/tvOS: if Keychain unusable AND no UserDefaults ids AND app not active
      │     → park params in delayedInitilizationParams, retry on didBecomeActive
      ├─> ApphudStoreKitWrapper.setupObserver()   (SKPaymentQueue.add(self), once)
      ├─> httpClient = ApphudHttpClient.shared; apiKey set
      ├─> ApphudAsyncStoreKit.shared.startObserving()   (starts Transaction.updates +
      │     PurchaseIntent.intents listeners with the SDK, once)
      ├─> guard allowIdentifyUser (false after first start until logout())
      └─> identify(inputUserID:inputDeviceID:observerMode:)
          ├─> resolve deviceID / userID (see Identity)
          ├─> currentUser = ApphudUser.fromCacheV2()      (Caches/ApphudUser; expiry is not checked)
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
`user_id` is passed explicitly on the initial call, on `updateUserID` and on web2web
attribution when the payload carries a user id; every other `updateUser` call adds `currentUser.userId` once a user exists, so
only a non-initial call made before the first user load goes without it.
HTTP 401 sets `invalidAPiKey`, 403 sets `unauthorized` + `suspended`; both stop retries.

**`performWhenUserRegistered(allowFailure:callback:)`** is the gate every feature sits
behind. If `currentUser` is nil the block is appended to `userRegisteredCallbacks`
(in-memory, `@MainActor`) and run after the first successful registration;
`allowFailure: true` blocks also run when registration gives up (`performAllUserFailedBlocks`,
now also called from `scheduleUserRegistering` when `!canRetry` or the retry cap is hit)
and run immediately if the client already cannot retry (invalid key / unauthorized).
`logout()` runs every pending `allowFailure` block too, so nobody awaits forever.

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
- `inputDeviceID` overrides the stored device id but is never persisted: the override runs
  before the nil check, so `identify` only ever saves a generated id (the other
  `saveDeviceID` caller, `resetValues`, writes `""`).
- The user id is written to Keychain/UserDefaults only when it differs from what the
  Keychain already had (`isIdenticalUserIds` check in `identify`).
- `currentCustomerID` mirrors `currentUser.internalId` (the backend `id`) and is added as
  `customer_id` to request bodies / queries whenever it is non-empty
  (`ApphudHttpClient.makeRequest`). It follows `currentUser`, including the cached user
  loaded in `identify`, so requests made before any user is loaded — e.g. a `/customers`
  call with no cached user — carry none. It is
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

Clears, in order: `ApphudDataActor.clear()` (effectively the user-properties cache only —
see "Not cleared"), Keychain + UserDefaults ids (`resetValues` writes `""` to both — **only if
`canUseKeychain`**, otherwise nothing is reset), the cached user file (v2 and legacy),
`currentUserID`/`currentDeviceID` = `""`, paywalls/placements caches and in-memory
arrays, `currentUser`, premium flags, all pending callback arrays (each waiting callback
is first answered with an "Apphud SDK was logged out" error — `allowFailure`
registration blocks, products-fetched, submit-receipt and restore callbacks),
`lastUploadedTransactions`, `submittingTransaction`, pending user properties, retry
counters, attribution "submitted" flags, push token, `observerModePurchaseIdentifiers`;
then `allowIdentifyUser = true`. **Not cleared:** `permissionGroups` and its cache
(comment: "never change"), `ApphudReinstallFlag`, `lastUserUpdatedAt`,
`requiresReceiptSubmissionKey`, `ApphudKnownProductTypes`, IDFA/IDFV
`submittedDeviceIdentifiers`, `swizzlePaymentDisabledKey`, the AF/Adjust attribution cache
files (`clear()` assigns nil, but the `submittedAFData` / `submittedAdjustData` setters ignore
nil, so the cached payloads survive logout and are ignored only once older than 7 days),
the `Transaction.updates` /
`PurchaseIntent.intents` listeners, and the `ApphudDelegate`/`ApphudUIDelegate` references.

The next `start` therefore behaves like a fresh install: `loadDeviceID()` returns nil
(empty string is filtered), so a **new device id is minted** and `isFreshInstall = true`
(`isRedownload` is false because the device id is nil). The doc comment on
`Apphud.logout()` states that if the previous user had an active subscription, the new
user's restore will merge both under the subscriber's account.

### Identity on the StoreKit side

`ApphudStoreKitWrapper.appropriateApplicationUsername()` returns `currentUserID` when it
parses as a `UUID`, otherwise `currentDeviceID`, and only when the payment queue has been
swizzled (`hasSwizzledPaymentQueue`, set from `preparePaywalls` after the first user
load). That value goes into `Product.PurchaseOption.appAccountToken(UUID)` on every SDK
purchase (`ApphudAsyncStoreKit.purchaseResult`), into `SKMutablePayment.applicationUsername`
for the host app's own StoreKit 1 payments (swizzle), and into `application_username` in
the `/v1/sign_offer` request. A non-UUID user id silently falls back to the device id; a
purchase made before the swizzle is enabled carries no `appAccountToken`.

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
              ├─> wrapper.status = .loading
              ├─> skProductsFeederTask = Task.detached { wrapper.fetchAllProductsFeeder(ids) }
              │     (SKProductsRequest, 3 in-fetcher retries; fills ApphudProduct.skProduct and
              │      re-runs updatePaywallsAndPlacements when done — readiness does NOT wait for it)
              ├─> loop ≤ maxAttempts: ApphudAsyncStoreKit.fetchProducts(ids, isLoadingAllAvailable: true)
              │     → Product.products(for:) into ApphudProductsStorage
              ├─> wrapper.status = .fetched / .error(lastError)  (keyed to the SK2 result)
              └─> handleDidFetchAllProducts(error:) → updatePaywallsAndPlacements()
                  ├─> ApphudPaywall.update(placementId:placementIdentifier:) sets product.skProduct (if fed),
                  │     paywallId/placementId/experimentId/variationIdentifier
                  └─> delegate.paywallsDidFullyLoad / placementsDidFullyLoad
```

The deprecated `SKProduct` callback API (`refreshStoreKitProductsWithCallback`) awaits
`skProductsFeederTask` before returning `wrapper.products`.

- `Apphud.placements()` / `fetchPlacements` / `preloadPaywallScreens` all go through
  `fetchOfferingsFull(maxAttempts:)`, which waits for registration then for the StoreKit 2
  product fetch; only its `deferPlacements` branch (re-register, then
  `refreshStoreKitProductsOnly`) also awaits the `SKProduct` feeder.
  `deferPlacements()` makes the initial `/customers` call send `need_placements: false`;
  the next `fetchOfferingsFull` re-registers with placements.
- Permission groups come from `GET /v3/products` (`fetchPermissionGroups`), cached to
  `Caches/ApphudProductGroups`; used to widen the SKProduct id set and for `ApphudGroup.hasAccess`.
- Single paywall by identifier: `GET /v2/paywall_configs/{id}` (`fetchPaywall`), used by Rules.
- Product macros (`ApphudProduct.properties`, per locale) are rendered server-side via
  `POST /v2/paywall_configs/items/render_properties` (`getRenderedProperties`) when a
  value contains `{`.
- SK2 `Product`s are the primary product model: they live in `ApphudProductsStorage`
  (actor, `Set<Product>` + in-flight ids), fetched via `Product.products(for:)`;
  `Apphud.fetchProducts()`, `ApphudProduct.product()`, the purchase path, eligibility,
  currency fallback and the paywall-screen `productsInfo()` all read it. `SKProduct`s are
  a best-effort side cache.
- Fallback (`Internal/ApphudInternal+Fallback.swift`): when registration keeps failing
  (`serverIsUnreachable` and attempts ≥ max or > `APPHUD_MAX_INITIAL_LOAD_TIME` 10 s)
  `executeFallback` runs. After a no-op exit when paywalls are already prepared and no
  callback was passed, it requires `apphud_paywalls_fallback.json` in the app bundle:
  without the file it returns (error to the callback) before setting `fallbackMode` or
  creating a user. With it, it exits again if already in `fallbackMode` with no callback;
  otherwise it sets `fallbackMode` and, when there is no current user, synthesises an
  `ApphudUser(userID:)` and releases the registration queue; then it uses the already
  loaded paywalls when there are any and `allAvailableProductIDs()` is non-empty, otherwise
  the paywalls decoded from that JSON. In `fallbackMode` a failed transaction upload becomes
  `stubPurchase(productId:)` — a 1-hour stub subscription/purchase
  (`groupId == "apphud_stub"`) built from the SK2 `Product`
  (`ApphudSubscription(product:)` / `ApphudNonRenewingPurchase(product:)`), falling back
  to the `SKProduct` stub initialisers, and cached as the user.

## Purchase paths

Files: `Internal/ApphudInternal+Purchase.swift`, `Internal/ApphudAsyncStoreKit.swift`,
`Internal/ApphudStoreKit2Extensions.swift`, `Internal/ApphudStoreKitWrapper.swift`
(observer-mode tracking only).

### Every SDK purchase goes through StoreKit 2

```
Apphud.purchase(ApphudProduct, callback:) / purchase(productId, callback:)          // Public/Apphud.swift
Apphud.purchase(ApphudProduct) async / purchase(ApphudProduct, value:)
  └─> ApphudInternal.purchase(productId:product:validate:purchasingFromScreen:value:callback:)   @MainActor
      ├─> purchasingProduct = product; commitmentPlan = product.isCommitmentPlanPreferred()
      └─> purchaseAsync(apphudProduct:productId:commitmentPlan:fromScreen:value:extraOptions:)   (private)
          ├─> product = apphudProduct.product() ?? ApphudAsyncStoreKit.fetchProduct(id)   (Product.products(for:))
          │     nil → callback(ApphudPurchaseResult(error: "product identifier is invalid"))
          ├─> wrapper.purchasingValue = (id, value) or nil          (setCustomPurchaseValue / value:)
          ├─> visionOS: resolve the foreground UIScene (error if none)
          └─> ApphudAsyncStoreKit.purchase(product:commitmentPlan:apphudProduct:fromScreen:extraOptions:)
              └─> ApphudAsyncPurchaseResult → ApphudPurchaseResult(subscription, purchase, nil, error,
                    transactionV2: trx) with isPending copied; callback(resultV2)

Apphud.purchase(Product, prefersCommitmentPlan:isPurchasing:) async                 // direct SK2 entry
  └─> ApphudAsyncStoreKit.purchase(product:commitmentPlan:apphudProduct: apphudProductFor(product))
```

`ApphudAsyncStoreKit.purchaseResult(...)` (`@MainActor`):

```
isPurchasing = true; productsStorage.append(product)
options = extraOptions ∪ .appAccountToken(UUID from appropriateApplicationUsername())
        ∪ .billingPlanType(.monthly) on iOS 26.4+ when commitmentPlan && isCommitmentPlanSupported()
LoggerService.paywallCheckoutInitiated → event paywall_checkout_initiated
product.purchase(options:)   (visionOS: purchase(confirmIn: scene, options:))
  ├─> .success(.verified(trx))   → processTransaction(trx, jws: verificationResult.jwsRepresentation)
  │       submission error (if any) becomes result.error; transaction stays unfinished for redelivery
  ├─> .success(.unverified)      → error "failed StoreKit verification", setNeedToCheckTransactions,
  │       never submitted, never finished
  ├─> .pending                   → isPending = true (Ask to Buy / SCA; transaction arrives later
  │       via Transaction.updates), no error
  ├─> .userCancelled             → event paywall_payment_cancelled, StoreKitError.userCancelled
  └─> thrown error               → event paywall_payment_error
isPurchasing = false; runDeferredTransactionCheckIfNeeded()
asyncPurchaseResult(product:transaction:error:isPending:) → ApphudAsyncPurchaseResult
```

`asyncPurchaseResult` looks the purchase/subscription up by product id, then by
`subscriptionGroupID` (comparing against the SK1 feeder's `subscriptionGroupIdentifier`
for the user's other subscriptions); `success` = `transaction != nil`.
`ApphudPurchaseResult.success` = no error and an active subscription/purchase.

Promo offers: `purchasePromo(productId:apphudProduct:discountID:fromScreen:)` →
`POST /v1/sign_offer` (`signPromoOffer`, with `application_username`) →
`ApphudSignedPromoOffer` → `Product.PurchaseOption.promotionalOffer(offerID:keyID:nonce:signature:timestamp:)`
passed as `extraOptions` into the same `purchaseAsync` path. No `SKPaymentDiscount`.

### Transaction handling (single-flight per transaction id)

`ApphudAsyncStoreKit.processTransaction(_:jws:fromScreen:)` (static, `@MainActor`) keeps
`processingTransactions: [UInt64: Task<Error?, Never>]`. The first arrival of a
transaction (direct purchase call or `Transaction.updates`) owns it: it runs
`ApphudInternal.handleTransactionResult` and calls `transaction.finish()` **only when the
submission returned no error**; any later arrival for the same id awaits that task
instead of duplicating the upload. `isProcessing(transactionID:)` lets the SK1 observer
see an in-flight id.

`handleTransactionResult(_ transaction: StoreKit.Transaction, jws:fromScreen:) -> Error?`
(`+Purchase.swift`; `handleTransaction` is the `Bool` wrapper) returns nil when nothing
more needs to happen and an error when the transaction must stay unfinished:

- error if `submittingTransaction == String(transaction.id)` (already in flight);
- nil if `isAlreadyTracked` (the current user already has the same product id with either
  a purchase date within 2 s or the same original transaction id — the product id must
  match in both cases) or the id is in
  `lastUploadedTransactions` (UserDefaults `ApphudLastUploadedTransactionsSK2`);
- nil if inactive (auto-renewable: expired, revoked or upgraded; others: revoked);
- otherwise fetch the SK2 `Product` for `product_info`, `appStoreReceipt()` (refreshes
  via `SKReceiptRefreshRequest` when missing, then proceeds even without one),
  `performWhenUserRegistered(allowFailure: true)` (error if still no user) →
  `submitReceipt(... transactionJws: jws, ownsTransaction: true)`; `transactionState:
  .purchased` only when the purchase is less than one hour old.

`ApphudAsyncTransactionObserver` (created with `ApphudAsyncStoreKit.shared`, started from
`initialize`) iterates `Transaction.updates` on a background Task. Outside observer mode
each verified transaction goes through `processTransaction` (deduplicated by id against
the purchase in flight); in observer mode it calls `handleTransaction` (submit only, never
finishes). Unverified transactions trigger `setNeedToCheckTransactions`.
`checkTransactionsNow` (called directly on app active and from `submitAppStoreReceipt` —
the pending-upload resubmit and its retries; the 0.5 s debounce applies only to `setNeedToCheckTransactions`) defers itself
(`deferredTransactionCheck`) while either engine reports `isPurchasing` and is re-run by
`runDeferredTransactionCheckIfNeeded` when the purchase ends; otherwise it submits the
latest verified transaction from `Transaction.all` without finishing it.

`ApphudPurchaseIntentsObserver` (iOS 16.4+ / macOS 14.4+, same lifetime) iterates
`PurchaseIntent.intents` (promoted in-app purchases, win-back offers): if
`ApphudDelegate.apphudShouldStartAppStoreDirectPurchase(product:)` returns a callback the
SDK purchases through `ApphudInternal.purchase`; otherwise it fetches the `SKProduct`
through the wrapper and offers it to the deprecated `SKProduct` overload. This replaced
`paymentQueue(_:shouldAddStorePayment:for:)`, which is gone.

### Observer mode (host app's own StoreKit 1 payments)

`ApphudStoreKitWrapper.paymentQueue(_:updatedTransactions:)` is the only remaining SK1
transaction path. `.purchasing` transactions force-enable observer mode when observer mode
is off **and** `ApphudAsyncStoreKit.shared.isPurchasing` is false (SDK purchases also
surface in the legacy queue). `.purchased` → `handleTransactionIfStarted`: skipped while an
SDK SK2 purchase is in flight; if `ApphudAsyncStoreKit.isProcessing(transactionID:)` →
`setNeedToCheckTransactions` and leave it; if the id is already in
`lastUploadedTransactions` (the "legacy twin" of an acknowledged SK2 transaction) → finish
unless observer mode; else `submitReceiptAutomaticPurchaseTracking(transaction:)`
(`ownsTransaction: true`) → `ApphudDelegate.apphudDidObservePurchase(result:)` decides
whether the SDK finishes it (also finished when observer mode is off and the upload
succeeded). `.failed` transactions are finished by the SDK unless observer mode
(`failedWithUnknownReason` → `setNeedToCheckTransactions`). `.deferred` →
`ApphudDelegate.handleDeferredTransaction`. `Apphud.willPurchaseProductFrom(paywallIdentifier:placementIdentifier:)`
stores `observerModePurchaseIdentifiers`, which `submitReceipt` uses to attach
`paywall_id`/`placement_id`/`experiment_id` to the upload. `setCustomPurchaseValue`
sets `wrapper.purchasingValue`, read by both `SKProduct` and `Product`
`apphudSubmittableParameters(true)` as `custom_purchase_value`.

### Restore

```
Apphud.restorePurchases(callback:) / restorePurchases() async
  └─> ApphudInternal.restorePurchases → restorePurchasesCallback stored
      └─> restoreUsingStoreKit2()  (async; pre-iOS 15 branch → submitReceiptRestore, unreachable)
          ├─> latest verified entitlement from Transaction.currentEntitlements (newest purchaseDate)
          ├─> none AND no receipt on device → AppStore.sync() once (system sheet; errors are logged), walk again
          ├─> receiptString = appStoreReceipt()   (refresh if missing)
          ├─> neither entitlement nor receipt → callback(error), no request
          └─> performWhenUserRegistered(allowFailure: true)   (no user → callback(error))
              └─> submitReceipt(transactionIdentifier: trx.id, transactionProductIdentifier:,
                    transactionState: nil, receiptString:, transactionJws: jws, notifyDelegate: true)
                  → callback(currentUser.subscriptions, purchases, error)
```

The result is an `ApphudPurchaseResult` with `isRestoreResult = true` carrying the first
active subscription/purchase. `SKPaymentQueue.restoreCompletedTransactions()` is never
called; `.restored` transactions that the host app's own restore produces are still
uploaded through `submitReceiptRestore(transaction:)` (receipt or transaction id, no JWS)
and finished unless observer mode. `migrateiOS14PurchasesIfNeeded` runs a restore once on
pre-iOS 15 only.

## Receipt / transaction submission

`submitReceipt(productInfo:apphudProduct:transactionIdentifier:transactionProductIdentifier:transactionState:receiptString:transactionJws:notifyDelegate:eligibilityCheck:ownsTransaction:fromScreen:callback:) async`
(`Internal/ApphudInternal+Purchase.swift`) is the single upload; the `SKProduct`-based
overload builds `productInfo` from `SKProduct.apphudSubmittableParameters` (fetching the
product first if the feeder lacks it) and is used by the observer-mode and `.restored`
paths.

- `POST /v1/subscriptions` with `device_id`, `user_id`, `environment`, `observer_mode`,
  `bundle_id`, `receipt_data` (base64 `appStoreReceiptURL`, sent whenever readable),
  `transaction_id`, `jws` (signed StoreKit 2 transaction, `VerificationResult.jwsRepresentation`),
  `product_info` (`Product.apphudSubmittableParameters` in
  `Internal/ApphudStoreKit2Extensions.swift` — same field set as the `SKProduct` version:
  price, currency/country from `priceFormatStyle` on iOS 16+ with SK1-feeder fallback,
  period, intro offer, promo offers, `custom_purchase_value`), and for real purchases
  `product_bundle_id`, `paywall_id`, `placement_id`, `variation_identifier`,
  `experiment_id`, `screen_id` (from screen), `rule_id`.
- Single-flight slot `submittingTransaction` (`@MainActor`), claimed atomically with the
  transaction id / product id / `"Restoration"`. A non-owning caller (restore,
  eligibility, observer tracking) piggybacks: its callback joins `submitReceiptCallbacks`
  and fires with the in-flight result. An owning caller (`ownsTransaction: true`) whose
  transaction differs from the one in flight gets an immediate error plus
  `setNeedToCheckTransactions` — its transaction must never be finished on a foreign
  result. Slot release and callback hand-off happen in one main-actor step.
- On success → `lastUploadedTransactions` records the id (only after backend
  acknowledgement, kept to the last 200) → `parseUser` → delegates. On failure the
  callback always receives a non-nil error, `scheduleSubmitReceiptRetry` (delay = attempt
  count in seconds, via `perform(afterDelay:)`, unbounded while `canRetry`) →
  `submitAppStoreReceipt` → `checkTransactionsNow` (retries the newest transaction only;
  older failed ones wait for StoreKit redelivery). In `fallbackMode` a failed purchase
  upload becomes `stubPurchase(productId:)`.
- `requiresReceiptSubmission` (UserDefaults `requiresReceiptSubmissionKey`) is set to
  true before the request and false on success; `createOrGetUser` re-submits the receipt
  on every registration while it is true — the only persistence of "upload pending".
- Eligibility checks no longer upload a receipt first (the `ReceiptForIntroSent` /
  `ReceiptForPromoSent` flags are gone); see the Eligibility bullet below.

## HTTP layer

`Internal/ApphudHttpClient.swift`, `Internal/ApphudURLSession.swift`,
`Internal/ApphudInternal+Fallback.swift` (gateway host fallback).

- Base `https://gateway.apphud.com` (`domainUrlString`, public, mutable). Path
  `/{v1|v2|v3}/{endpoint}`; `ApphudEndpoint` enumerates every route.
- Headers: `APPHUD-API-KEY`, `X-Platform` (`ios`/`macos`), `X-SDK` (`sdkType`, default
  `swift`; `flutter` changes behaviour), `X-SDK-VERSION`, `User-Agent`,
  `Idempotency-Key` (fresh UUID per request; the initial `/customers` call reuses
  `initialRequestID` across retries). A response whose `idempotency-key` header is present
  and differs from the request's is rejected as "Invalid HTTP Response"; a response
  without the header is accepted.
- `api_key` is also placed in every body (POST/PUT) or query (GET), and `customer_id` too
  whenever it is non-empty (requests made before any user is loaded carry none).
- Timeouts: GET 7 s, POST 20 s, `POST /customers` 7 s (`POST_CUSTOMERS_TIMEOUT`, public).
- `useDecoder: true` skips the `[String: Any]` parse in production so Codable models read
  `Data` directly. `startRequest` traffic goes through `URLSession.shared`; the client's
  private session with caching disabled serves the screen HTML loads. The Apple Ads lookup
  (`getAppleAttribution`) and the `fallback.txt` download (`loadFallbackHostIfNeeded`) call
  `URLSession.shared` directly, bypassing `startRequest` and the test seam. That seam is
  `ApphudHttpClient.testURLSessionConfiguration` (must be set before the first access to
  `shared`; routes `startRequest` traffic and the screen HTML loads through a session built
  from that configuration so `URLProtocol` stubs apply; always nil in production).
- **Every `startRequest` answers its callback.** A suspended account or a request that
  could not be built delivers `ApphudError` on the main actor instead of dropping the
  callback; `parseError` never returns nil (non-422 bodies become
  `ApphudError("HTTP Request Failed", code: 422)`), because callers treat a nil error as
  backend acknowledgement and may finish a paid transaction on it.
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
| Caches/ (via `ApphudDataActor`) | `ApphudUser` (a 90 d timeout is passed, but expiry is not checked on load), `ApphudPaywalls`, `ApphudPlacements`, `ApphudProductGroups` (`cacheTimeout`), `ApphudUserPropertiesCache`, `submittedAFDataKey`, `submittedAdjustDataKey` (7 d), `{screenId}.html` | `+Product`, `ApphudUser.toCacheV2`, `+UserUpdate`, `+Attribution`, `ApphudHttpClient` |
| UserDefaults | `ApphudReinstallFlag`, `lastUserUpdatedAt`, `requiresReceiptSubmissionKey`, `ApphudLastUploadedTransactionsSK2` (ids acknowledged by the backend; the pre-4.5.0 `ApphudLastUploadedTransactions` key is deliberately never read because it was written before acknowledgement), `ApphudKnownProductTypes`, `swizzlePaymentDisabledKey`, `submittedDeviceIdentifiersKey`, `submittedPushTokenKey`, `submittedFirebaseIdKey`, `submittedFacebookAnonIdKey`, `didSubmit{AppsFlyer,Adjust,AppleAds}AttributionKey`, `ApphudSubscriptionsMigrated`, `ApphudMigrateCachesKey`, `ApphudConnectDomainUrl`, `apphud_installation_date` (read-only override) | various |
| Bundle | `apphud_paywalls_fallback.json` (read only) | host app |

Legacy user cache (`ApphudUser.data`, NSKeyedArchiver, Application Support or Caches)
is migrated once to `Caches/ApphudUser` (`ApphudMigrateCachesKey`).

## SKPaymentQueue observation and swizzling

`ApphudStoreKitWrapper` (`Internal/ApphudStoreKitWrapper.swift`) is StoreKit 1
compatibility only; it never starts a payment.

- Added as `SKPaymentTransactionObserver` in `initialize` (once per process).
  `updatedTransactions` sorts `.purchased` first and processes on the main actor (see
  "Observer mode" above for the per-state rules). `removedTransactions` posts
  `_ApphudDidFinishTransactionNotification`; `finishTransaction` posts
  `_ApphudWillFinishTransactionNotification` before `SKPaymentQueue.finishTransaction`.
  Both notifications are deprecated and only fire for these host-app transactions.
  `finishTransaction(_:clearsPurchasingValue:)` keeps `purchasingValue` when finishing a
  transaction that is not the SDK's own purchase.
- `paymentQueue(_:shouldAddStorePayment:for:)` is **not** implemented: promoted purchases
  come through `PurchaseIntent.intents` (`ApphudPurchaseIntentsObserver`), and Apple
  forbids using both.
- **Swizzle**: `SKPaymentQueue.doSwizzle()` exchanges `add(_:)` with `apphudAdd(_:)`
  (`method_exchangeImplementations`, guarded by a process-wide flag). `apphudAdd` copies
  the payment to `SKMutablePayment` and sets `applicationUsername` to
  `appropriateApplicationUsername()` unless the host already set a UUID there. Enabled
  from `preparePaywalls`, i.e. after the first user load, unless the server sent
  `swizzle_disabled: true` or the SDK is Flutter in observer mode. The same flag gates
  `appropriateApplicationUsername()`, so it also decides whether SK2 purchases get an
  `appAccountToken`.
- Receipt refresh: `refreshReceipt(_:)` queues callbacks behind a single in-flight
  `SKReceiptRefreshRequest` (`makeReceiptRefreshRequest` is a test seam); finish, failure
  or the `receiptRefreshTimeout` watchdog (15 s, `DispatchWorkItem` on main) releases
  every waiting caller, which then re-reads the (possibly still missing) receipt and
  proceeds. Used by `appStoreReceipt()` in the purchase and restore paths.
- SK1 products: `fetchAllProductsFeeder(identifiers:)` appends new `SKProduct`s to
  `products` (concurrent `DispatchQueue` with barrier writes) and re-runs
  `updatePaywallsAndPlacements`; `fetchProduct(_:)` / `fetchProducts(productIds:)` fetch
  on demand for the deprecated `SKProduct` APIs, the legacy Rule screens and the
  `SKProduct` delegate fallbacks. Per-request `ApphudProductsFetcher` objects retry 3
  times and are kept alive in an `ApphudSafeSet`. `status`
  (`ApphudStoreKitProductsFetchStatus`) is driven by the SK2 fetch, not by the feeder.

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
  `apphud_user_id` and `email`/`apphud_user_email`. With neither it fails; with only a user
  id equal to the current one it returns success without a request; otherwise it
  re-registers with `from_web2web: true` plus `user_id` and/or `email`, whichever was found
  (→ `checkUserID` → `apphudDidChangeUserID`). Deep-link attribution:
  `handleOpen(url:)`/`handleLaunchOptions`/`continueUserActivity` →
  `POST /v2/customers/deeplink_attribution` with `url` (kind `.direct`);
  `requestDeferredDeeplinkAttribution` presents a hidden 1×1 `WKWebView`
  (`ApphudWebController`, iOS 15+, app must be active with a visible controller, 10 s
  timeout, 3 readiness retries) that loads `connectDomainUrl?api_key&device_id&host`,
  evaluates `getConnectId()` and posts the `visitor_id` to the same endpoint (kind
  `.deferred`). Results reach the `ApphudDeeplinkHandler` set in `start`/`setDeeplinkHandler`.
- Eligibility (`+Eligibility.swift`): `checkIntroEligibilitiesSK2(productIds:)` — true
  by default, false for non-subscriptions or products with no configured intro offer,
  otherwise SK2 `subscription.isEligibleForIntroOffer`; `checkPromoEligibilitiesSK2(productIds:)`
  — true when the user already has that subscription, otherwise whether any verified
  transaction in `Transaction.all` belongs to the same `subscriptionGroupID`. Both are
  purely local (products come from `ApphudAsyncStoreKit.fetchProduct`); nothing is
  uploaded first. The deprecated `SKProduct` overloads wait for registration and then
  run the same logic.
- Currency (`+Currency.swift`): `Storefront.current` (0.3 s timeout) → `store_id` +
  `country_code_alpha3` on the next `/customers` call; fallback
  `fetchCurrencyFromProducts` reads `apphudCountryCode()`/`apphudCurrencyCode()` off the
  first SK2 `Product` (`priceFormatStyle` on iOS 16+, SK1 feeder `priceLocale` below).

## ApphudUI: Rules screens and paywall screens (iOS only)

`Sources/ApphudUI/` plus `Public/ApphudPaywallScreenController.swift`,
`Public/ApphudRule.swift`, `Public/ApphudRuleScreen.swift`, `Public/ApphudPaywallScreen.swift`.
Not a separate SPM target — same module; the UIKit/WebKit code is behind `#if os(iOS)`
(per-file exceptions are listed in structure.md; the three model files `ApphudRule`, `ApphudRuleScreen`, `ApphudPaywallScreen` are unguarded).

### Rules

```
registerUser success / app active (≥60 s apart) / ApphudUtils.checkRules()
  └─> checkForUnreadNotifications → GET /v2/notifications           // ApphudInternal.swift
      └─> ApphudRule(dictionary:) → ApphudScreensManager.handleRule(rule:)   // ApphudUI/ApphudScreensManager.swift
          ├─> uiDelegate.apphudShouldPerformRule? == false → readAllNotifications, stop
          ├─> rule has paywall_id/paywall_identifier (new style)
          │     → fetchPaywall(identifier:) → hasVisualPaywall()
          │         ├─> no screen → uiDelegate.apphudRuleWithoutPaywallScreen
          │         └─> Apphud.fetchPaywallScreen → ApphudPaywallScreenController(paywall:), then controller.rule = rule
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
A legacy-screen purchase still needs an `SKProduct`: if the feeder has not delivered it,
`purchaseProduct` fetches it once via `wrapper.fetchProduct` and then calls
`ApphudInternal.purchase(productId:...)` / `purchasePromo(productId:...)` (StoreKit 2
underneath). `handlePurchaseResult` treats `result.isPending` as "neither success nor
failure" (button re-enabled, screen stays), success = `result.success ||
transactionV2 != nil || SK1 .purchased`, and calls both `SKProduct` and `productId`
UI-delegate variants.

### Paywall screens (Figma paywalls)

```
Apphud.preloadPaywallScreens(placementIdentifiers:)  /  Apphud.fetchPaywallScreen(paywall)
  └─> ApphudScreensManager.requestPaywallController(paywall:cachePolicy:)
      ├─> reuse pendingPaywallControllers[paywall.identifier] if loading/ready
      ├─> guard paywall.screen?.paywallURL (locale-specific URL + live=true)
      └─> ApphudPaywallScreenController(paywall:).load()                // Public/ + ApphudUI/…+I.swift
          ├─> ApphudView (WKWebView) loads paywallURL with cachePolicy
          ├─> productsInfo(): wait for products, renderPropertiesIfNeeded, merge
          │     Product.apphudSubmittableParameters (SK2; skProduct fallback) + jsonProperties
          ├─> on both loaded: PaywallSDK.shared().processDomMacros(json) + applyCustomInsets
          └─> state .ready / .error (timeout APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT 10 s)
```

The web page talks back through navigation to host `pay.apphud.com`:
`/purchase/{index}` → `startPaywallPurchase` → `ApphudInternal.purchase(... purchasingFromScreen: true)`
(for Rule-opened screens the `SKProduct` is fetched on demand first so the deprecated
`SKProduct` UI-delegate callbacks still fire; the `productId` variants always fire; an
`isPending` result skips did-purchase/did-fail/dismiss and waits for `Transaction.updates`),
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
  `placements`, `permissionGroups`, the callback arrays, `submittingTransaction`,
  `deferredTransactionCheck`, `skProductsFeederTask`, `lastUploadedTransactions`,
  `initialize`/`identify`, `updateUser`, `preparePaywalls`,
  `performWhenStoreKitProductFetched`, `ApphudAsyncStoreKit.purchaseResult` /
  `processTransaction` (and its `processingTransactions` map), all of
  `ApphudScreensManager` and the public `start`/`purchase`/`placements` APIs are
  `@MainActor`. Non-isolated properties on `ApphudInternal` (`currentUserID`,
  `currentDeviceID`, `currentCustomerID`, retry counters, flags) are plain `var`s read
  from any thread; `currentCustomerID` exists precisely so `ApphudHttpClient` can read
  the customer id off the main actor.
- **HTTP callbacks always land on the main actor**: `ApphudHttpClient.startRequest`
  runs the request in a `Task(priority: .userInitiated)` and delivers the result with
  `Task { @MainActor in callback(...) }` (also for the suspended / request-build-failure
  early exits). Delegate methods and public callbacks are therefore called on main.
- **Off-main state is actor-owned**: `ApphudDataActor` (global actor: Caches files,
  pending user properties, attribution caches, known product types),
  `ApphudProductsStorage` (SK2 products + in-flight ids). Two `DispatchQueue`-with-barrier
  containers remain for the SK1 feeder: `ApphudStoreKitWrapper.products` and `ApphudSafeSet`.
- **StoreKit callbacks** (`SKPaymentTransactionObserver`, `SKRequestDelegate`,
  `SKProductsRequestDelegate`) arrive on StoreKit's thread and immediately hop:
  `Task { @MainActor in }` for transactions, `DispatchQueue.main.async` for receipt
  refresh bookkeeping (callback queue, watchdog). `Transaction.updates` and
  `PurchaseIntent.intents` are consumed on `Task(priority: .background)` and hop to main;
  `checkTransactionsNow` walks `Transaction.all` on a background Task.
- **Scheduling is run-loop based**: debounces and retries use
  `NSObject.perform(#selector, afterDelay:)` / `cancelPreviousPerformRequests` on main
  (`updateCurrentUser` 3 s, `updateUserProperties` 2 s, `checkTransactionsNow` 0.5 s,
  `registerUser` and `submitAppStoreReceipt` retries, `forceSendAttributionDataIfNeeded`
  10 s — a no-op since 3.2.8). `performWhenUserRegistered` and
  `performAllUserRegisteredBlocks` use `Task.detached { @MainActor in }` to defer to
  the next run-loop turn. `ApphudLoggerService` batches metrics with a 5 s `Timer`; the
  receipt-refresh watchdog is a `DispatchWorkItem` (15 s).
- Async/await bridges: `withUnsafeContinuation` wraps the callback engine for the
  `async` public API and for `handleTransactionResult` → `submitReceipt`;
  `withCheckedContinuation` for `purchasePromo(_ product: Product, discountID:)` and the
  purchase-intent `SKProduct` bridge; `Task.detached(priority: .userInitiated)` starts
  registration.
