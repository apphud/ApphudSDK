//
//  ApphudPaywallScreen.swift
//  Pods
//
//  Created by Renat Kurbanov on 19.06.2025.
//
import Foundation

public class ApphudPaywallScreen: Codable {

    public var id: String
    public var defaultURL: String?
    public var urls: [String: String]

    internal var paywallURL: URL? {

        let langCode: String?
        if #available(iOS 16, *) {
            langCode = Locale.current.language.languageCode?.identifier
        } else {
            langCode = Locale.current.languageCode
        }

        var finalURLString: String?

        if let langCode {
            finalURLString = urls[langCode]
        }

        if finalURLString == nil {
            finalURLString = defaultURL ?? urls["en"] ?? urls.first?.value
        }

        guard let finalURLString, var url = URL(string: finalURLString) else {
            return nil
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "live", value: "true"))
        components?.queryItems = queryItems

        if let newURL = components?.url {
            url = newURL
        }

        return url
    }
    
    init(id: String) {
        self.id = id
        self.urls = [:]
    }
}
