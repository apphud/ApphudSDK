import Foundation

/// A response belongs to a person and a logout boundary, even when supplied ids are reused.
internal struct ApphudIdentityContext {
    let identity: ApphudIdentity
    let generation: UUID
    let version: UInt64
}

/// Cache jobs may reach the data actor out of order. A previous person can never overwrite
/// a newer response or repopulate a cache cleared by logout.
internal final class ApphudIdentityResponseCache {
    private var version: UInt64 = 0

    func write(_ values: [String: Data], version: UInt64, on actor: isolated ApphudDataActor = .shared) {
        guard version >= self.version else { return }
        self.version = version
        for (key, data) in values {
            actor.apphudDataToCache(data: data, key: key)
        }
    }

    func clear(version: UInt64, on actor: isolated ApphudDataActor = .shared) {
        guard version > self.version else { return }
        self.version = version
        for key in [ApphudUserCacheKey, ApphudPaywallsCacheKey, ApphudPlacementsCacheKey] {
            actor.apphudDataClearCache(key: key)
        }
    }
}

extension ApphudInternal {
    @MainActor
    internal func userResponseContext() -> ApphudIdentityContext? {
        guard !isIdentityV1 else { return nil }
        if responseContext?.generation != receiptSessionGeneration ||
            responseContext?.identity.hasSameIDs(as: identity) != true {
            responseContextVersion += 1
            responseContext = ApphudIdentityContext(identity: identity, generation: receiptSessionGeneration,
                                                    version: responseContextVersion)
        }
        return responseContext
    }

    @MainActor
    internal func isCurrentUserResponse(_ context: ApphudIdentityContext?) -> Bool {
        guard let context else { return true } // V1 keeps its original response handling.
        return !isIdentityV1 && context.generation == receiptSessionGeneration &&
            context.identity.hasSameIDs(as: identity) && context.version == userResponseContext()?.version
    }

    @MainActor
    internal func cacheUserResponse(_ user: ApphudUser, context: ApphudIdentityContext?) async {
        guard let context else {
            await user.toCacheV2()
            return
        }
        guard isCurrentUserResponse(context), let data = try? JSONEncoder().encode(user) else { return }
        await identityResponseCache.write([ApphudUserCacheKey: data], version: context.version)
    }
}
