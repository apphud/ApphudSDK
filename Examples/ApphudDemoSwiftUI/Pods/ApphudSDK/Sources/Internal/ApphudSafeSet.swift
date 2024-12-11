//
//  ApphudSafeSet.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.11.2023.
//

import Foundation

class ApphudSafeSet<Element: Hashable> {
    private var internalSet = Set<Element>()
    private let queue = DispatchQueue(label: "com.apphud.ThreadSafeSetQueue", attributes: .concurrent)

    // Insert an element in a thread-safe manner
    func insert(_ element: Element) {
        queue.async(flags: .barrier) {
            self.internalSet.insert(element)
        }
    }

    // Remove an element in a thread-safe manner
    func remove(_ element: Element) {
        queue.async(flags: .barrier) {
            self.internalSet.remove(element)
        }
    }

    // Thread-safe getter for the elements
    var elements: Set<Element> {
        return queue.sync {
            internalSet
        }
    }
}
