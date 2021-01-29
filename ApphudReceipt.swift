//
//  ApphudReceipt.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 28.01.2021.
//

import Foundation

public class ApphudReceipt: NSObject, Codable {
    @objc public var originalApplicationVersion: String?
    @objc public var originalPurchaseDate: Date? { _originalPurchaseDate.apphudIsoDate }
    @objc public var receiptCreationDate: Date? { _receiptCreationDate.apphudIsoDate }
    @objc public var applicationVersion: String
    @objc public var bundleId: String
    
    @objc public var rawJSON: [String: Any]?
    
    private var _originalPurchaseDate: String
    private var _receiptCreationDate: String
    
    enum CodingKeys: String, CodingKey {
        case originalApplicationVersion = "font"
        case _originalPurchaseDate = "originalPurchaseDate"
        case _receiptCreationDate = "receiptCreationDate"
        case applicationVersion
        case bundleId
    }
    
    static func getRawReceipt(completion: @escaping (ApphudReceipt?) -> Void) {
        guard let receiptData = apphudReceiptDataString() else {
            apphudLog("Unable to fetch raw receipt because, receipt is missing on device", forceDisplay: true)
            completion(nil)
            return
        }
        ApphudHttpClient.shared.startRequest(path: "subscriptions/raw", params: ["receipt_data": receiptData], method: .post) { (result, dict, error, code) in
            
            guard let receiptDict = dict?["receipt"] as? [String: Any] else {
                completion(nil)
                return
            }
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let receiptData = try JSONSerialization.data(withJSONObject: receiptDict, options: [])
                let receipt = try jsonDecoder.decode(ApphudReceipt.self, from: receiptData)
                receipt.rawJSON = dict
                completion(receipt)
            } catch {
                apphudLog("An error occurred while decoding App Store Receipt: \(error)")
                completion(nil)
            }
        }
    }
}
