//
//  ApphudReceipt.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 28.01.2021.
//

import Foundation

public class ApphudReceipt: NSObject, Codable {
    
    /**
        For more information about receipt fields check following documentation:
        https://developer.apple.com/documentation/appstorereceipts/responsebody/receipt
     */
    
    /**
     The version of the app that the user originally purchased. This value does not change, and corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in macOS) in the Info.plist file of the original purchase. In the sandbox environment, the value is always "1.0".
     Value is `nil` in StoreKit Testing generated receipts.
     */
    @objc public var originalApplicationVersion: String?
    
    /**
     The time of the original app purchase. Value is `nil` in StoreKit Testing generated receipts.
     */
    @objc public var originalPurchaseDate: Date? { _originalPurchaseDate?.appleReceiptDate }
    
    /**
     The time the App Store generated the receipt.
     */
    @objc public var receiptCreationDate: Date? { _receiptCreationDate?.appleReceiptDate ?? _creationDate?.appleReceiptDate }
    
    /**
     The app’s version number. The app's version number corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in macOS) in the Info.plist. In production, this value is the current version of the app on the device based on the receipt_creation_date_ms. In the sandbox, the value is always "1.0".
     */
    @objc public var applicationVersion: String
    
    /**
     The bundle identifier for the app to which the receipt belongs.
     */
    @objc public var bundleId: String
    
    /**
     Raw receipt JSON
     */
    @objc public var rawJSON: [String: Any]?
    
    
    // MARK: - Private
    private var _originalPurchaseDate: String?
    private var _receiptCreationDate: String?
    private var _creationDate: String?
    
    enum CodingKeys: String, CodingKey {
        case originalApplicationVersion
        case _originalPurchaseDate = "originalPurchaseDate"
        case _receiptCreationDate = "receiptCreationDate"
        case _creationDate = "creationDate"
        case applicationVersion
        case bundleId
    }
    
    static func getRawReceipt(completion: @escaping (ApphudReceipt?) -> Void) {
        guard let receiptData = apphudReceiptDataString() else {
            apphudLog("Unable to fetch raw receipt because, receipt is missing on device", forceDisplay: true)
            completion(nil)
            return
        }
        ApphudHttpClient.shared.startRequest(path: "subscriptions/raw", params: ["receipt_data": receiptData], method: .post) { (result, dict, _, error, code) in
            
            guard let receiptDict = (dict?["receipt"] as? [String: Any]) ?? dict else {
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
                let message = "An error occurred while decoding App Store Receipt: \(error)"
                apphudLog(message)
                ApphudLoggerService.logError(message)
                completion(nil)
            }
        }
    }
}
