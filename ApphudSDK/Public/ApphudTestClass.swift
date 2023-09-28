//
//  ApphudTestClass.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 28.09.2023.
//

import Foundation

class ApphudTestClass {
    let foo: Int
    let bar: String

    enum ApphudTestCodingKeys: String, CodingKey {
        case foo
        case bar
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ApphudTestCodingKeys.self)
        self.foo = try values.decode(Int.self, forKey: .foo)
        self.bar = try values.decode(String.self, forKey: .bar)
    }

    internal init(with values: KeyedDecodingContainer<ApphudTestCodingKeys>) throws {
        self.foo = try values.decode(Int.self, forKey: .foo)
        self.bar = try values.decode(String.self, forKey: .bar)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ApphudTestCodingKeys.self)
        try container.encode(foo, forKey: .foo)
        try container.encode(bar, forKey: .bar)
    }
}
