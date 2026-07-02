//
//  ApphudInternal+Fallback.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 01.09.2023.
//

import Foundation

import StoreKit

extension ApphudInternal {

    @MainActor func executeFallback(callback: (([ApphudPaywall]?, ApphudError?) -> Void)?) {

        if didPreparePaywalls && callback == nil {
            apphudLog("No need for fallback", logLevel: .debug)
            return
        }

        guard let url = Bundle.main.url(forResource: "apphud_paywalls_fallback", withExtension: "json") else {
            let message = "Fallback JSON file not found"
            apphudLog(message, logLevel: .all)
            callback?(nil, ApphudError(message: message))
            return
        }

        if fallbackMode && callback == nil {
            apphudLog("Already in fallback mode")
            return
        }

        fallbackMode = true

        if self.currentUser == nil {
            self.currentUser = ApphudUser(userID: currentUserID)
            self.performAllUserRegisteredBlocks()
        }

        if self.paywalls.count > 0 && self.allAvailableProductIDs().count > 0 {
            preparePaywalls(pwls: self.paywalls, writeToCache: false, completionBlock: nil)
            apphudLog("fallback mode with cached paywalls", logLevel: .all)

            if callback != nil {
                self.performWhenStoreKitProductFetched(maxAttempts: APPHUD_DEFAULT_RETRIES) { error in
                    callback?(self.paywalls, error)
                }
            }

            return
        }

        do {
            let jsonData = try Data(contentsOf: url)

            typealias ApphudArrayResponse = ApphudAPIDataResponse<ApphudAPIArrayResponse <ApphudPaywall> >

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let pwlsResponse = try decoder.decode(ApphudArrayResponse.self, from: jsonData)
            let pwls = pwlsResponse.data.results

            preparePaywalls(pwls: pwls, writeToCache: false, completionBlock: nil)
            apphudLog("Fallback mode is active", logLevel: .all)
            if callback != nil {
                self.performWhenStoreKitProductFetched(maxAttempts: APPHUD_DEFAULT_RETRIES) { error in
                    callback?(self.paywalls, error)
                }
            }
        } catch {
            let message = "Invalid Paywalls Fallback File: \(error.localizedDescription)"
            apphudLog(message)
            if callback != nil {
                callback?(nil, ApphudError(message: message))
            }
        }
    }

    @MainActor func stubPurchase(product: SKProduct?) -> HasPurchasesChanges {
        guard let product = product, !Apphud.hasPremiumAccess() else {
            apphudLog("No need to stub purchase because already has premium access")
            return HasPurchasesChanges(false, false)
        }

        if product.subscriptionGroupIdentifier != nil {
            let subscription = ApphudSubscription(product: product)
            self.currentUser = ApphudUser(userID: currentUserID, subscriptions: [subscription], paywalls: paywalls)

            apphudLog("Creating stub subscription with 1 hour expiration..")

            Task {
                await self.currentUser?.toCacheV2()
            }

            return HasPurchasesChanges(true, false)
        } else {
            let purchase = ApphudNonRenewingPurchase(product: product)
            self.currentUser = ApphudUser(userID: currentUserID, purchases: [purchase], paywalls: paywalls)
            Task {
                await self.currentUser?.toCacheV2()
            }

            return HasPurchasesChanges(false, true)
        }
    }
}

// MARK: - Gateway Host Fallback

extension ApphudHttpClient {

    // Remote file containing an alternative gateway host for regions where the
    // main gateway is unreachable. Expected to contain a single URL, e.g. https://some-alternative-gateway.apphud.com
    private static var fallbackHostFileURLString: String { "https://apphud.blob.core.windows.net/apphud-gateway/fallback.txt" }

    /// The fallback mechanism only applies to the default production gateway (or a host the SDK itself
    /// switched to). If a developer overrode `domainUrlString` with a custom host, we leave it untouched.
    @MainActor private var canUseFallbackHost: Bool {
        domainUrlString == Self.productionEndpoint || didSwitchToApphudFallbackHost
    }

    private static func isValidHost(_ string: String) -> Bool {
        string.hasPrefix("https://") && URL(string: string) != nil
    }

    /// Downloads an alternative gateway host from the remote fallback file and switches all
    /// subsequent requests to it. Used when the main gateway host is unreachable (e.g. blocked
    /// in certain regions). Returns `true` if a new host was applied.
    @MainActor
    @discardableResult
    internal func loadFallbackHostIfNeeded() async -> Bool {
        guard canUseFallbackHost else { return false }
        guard !isLoadingFallbackHost else { return false }
        guard let url = URL(string: Self.fallbackHostFileURLString) else { return false }

        isLoadingFallbackHost = true
        defer { isLoadingFallbackHost = false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300,
                  let contents = String(data: data, encoding: .utf8) else {
                apphudLog("Unable to read gateway fallback host file")
                return false
            }

            let newHost = contents
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? ""

            guard Self.isValidHost(newHost) else {
                apphudLog("Invalid gateway fallback host: \(newHost)")
                return false
            }

            guard newHost != domainUrlString else {
                return false
            }

            // Switch for the current session only; the fallback host is not persisted, so each
            // launch starts from the production gateway and re-evaluates reachability.
            domainUrlString = newHost
            didSwitchToApphudFallbackHost = true
            apphudLog("Main gateway is unreachable, switched to fallback host: \(newHost)", forceDisplay: true)
            return true
        } catch {
            apphudLog("Failed to download gateway fallback host: \(error.localizedDescription)")
            return false
        }
    }
}
