//
//  ApphudIdentityVersion.swift
//  ApphudSDK
//

import Foundation

/**
 The identity model the SDK runs, passed to `Apphud.start(...)`. It is read once per launch: a change takes effect on the next launch.

 Switching keeps the customer:
 - `.v1` → `.v2`: `.v2` sends the old device ID until a registration succeeds, and the backend keeps the customer.
 - `.v2` → `.v1`: `.v1` sends the old device ID (or the installation ID when the install started on `.v2`) and the current user ID (or the anonymous ID), and the backend finds the customer by that user ID. This adds a device record to the customer; apps that disabled the search by user ID may get a new customer; purchases follow the `.v1` rules again. After a logout on `.v2`, `.v1` starts with a new device ID, as its own logout does.
 */
@objc public enum ApphudIdentityVersion: Int {
    /// One device ID for the install and, until your app sets a user ID, for the user. The behaviour of SDK 4.6 and earlier. The default.
    case v1 = 1
    /// The installation ID, the anonymous ID and your app's user ID as separate IDs. Purchases sent automatically never move a subscription that another logged-in user owns: only a restore does.
    case v2 = 2
}
