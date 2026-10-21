import Foundation

/// Runtime coordination of the SK1/SK2 twins, separate from persisted backend acknowledgement.
/// Owned purchases and acknowledgements from another session must never become observed events.
internal struct ApphudObservedTransactions {
    private struct Entry {
        var sdkOwned = false
        var sdkPending = false
        var acknowledgedIdentity: ApphudIdentity?
        var delivery: UUID?
        var deliveryIdentity: ApphudIdentity?
        var notified = false
        var finishClaimed = false
    }
    private var entries: [UInt64: Entry] = [:]
    private var order: [UInt64] = []
    private let limit: Int
    private(set) var generation = UUID()

    init(limit: Int = 200) { self.limit = max(1, limit) }

    mutating func reset() {
        entries.removeAll()
        order.removeAll()
        generation = UUID()
    }

    func isSDKPurchase(_ id: UInt64) -> Bool { entries[id]?.sdkOwned == true }
    func hasAcknowledgement(_ id: UInt64, identity: ApphudIdentity) -> Bool {
        entries[id]?.acknowledgedIdentity?.hasSameIDs(as: identity) == true
    }

    mutating func recordSDKPurchase(_ id: UInt64) {
        var entry = entries[id] ?? Entry()
        entry.sdkOwned = true
        entry.sdkPending = true
        store(id, entry)
    }

    mutating func processingEnded(_ id: UInt64, generation: UUID) {
        guard generation == self.generation, var entry = entries[id] else { return }
        entry.sdkPending = false
        store(id, entry)
    }

    mutating func acknowledge(_ id: UInt64, identity: ApphudIdentity) {
        var entry = entries[id] ?? Entry()
        entry.acknowledgedIdentity = identity
        store(id, entry)
    }

    mutating func beginObservation(_ id: UInt64, identity: ApphudIdentity) -> UUID? {
        var entry = entries[id] ?? Entry()
        guard !entry.sdkOwned, !entry.notified, entry.delivery == nil else { return nil }
        if let acknowledged = entry.acknowledgedIdentity, !acknowledged.hasSameIDs(as: identity) { return nil }
        let ticket = UUID()
        entry.delivery = ticket
        entry.deliveryIdentity = identity
        store(id, entry)
        return ticket
    }

    mutating func completeObservation(_ id: UInt64, ticket: UUID, success: Bool) -> Bool {
        guard var entry = entries[id], entry.delivery == ticket else { return false }
        let sameIdentity = entry.deliveryIdentity.map { requested in
            entry.acknowledgedIdentity?.hasSameIDs(as: requested) == true
        } == true
        entry.delivery = nil
        entry.deliveryIdentity = nil
        // The native purchase may have returned to the SDK caller while its legacy twin waited.
        let notify = !entry.sdkOwned && (!success || sameIdentity)
        if notify && success { entry.notified = true }
        store(id, entry)
        return notify
    }

    mutating func cancelObservation(_ id: UInt64, ticket: UUID) {
        guard var entry = entries[id], entry.delivery == ticket else { return }
        entry.delivery = nil
        entry.deliveryIdentity = nil
        store(id, entry)
    }

    /// Reserve finishing before calling StoreKit: callbacks can synchronously re-enter the SDK.
    mutating func claimFinish(_ id: UInt64, generation: UUID) -> Bool {
        guard generation == self.generation else { return false }
        var entry = entries[id] ?? Entry()
        guard !entry.finishClaimed else { return false }
        entry.finishClaimed = true
        store(id, entry)
        return true
    }

    private mutating func store(_ id: UInt64, _ entry: Entry) {
        if entries[id] == nil { order.append(id) }
        entries[id] = entry
        // Like lastUploadedTransactions, retain recent completed work. Active deliveries stay.
        while entries.count > limit,
              let index = order.firstIndex(where: { key in
                  key != id && entries[key]?.delivery == nil && entries[key]?.sdkPending != true
              }) {
            entries.removeValue(forKey: order.remove(at: index))
        }
    }
}
