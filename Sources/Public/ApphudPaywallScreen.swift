//
//  ApphudPaywallScreen.swift
//  Pods
//
//  Created by Renat Kurbanov on 19.06.2025.
//

internal struct ApphudPaywallScreen: Codable {
    public var id: String
    public var urls: [String: String]
    
    internal var paywallURL: URL? {
        var langCode: String = ""
        if #available(iOS 16, *) {
            langCode = Locale.current.language.languageCode?.identifier ?? "default"
        } else {
            langCode = Locale.current.languageCode ?? "default"
        }
        
        if langCode.isEmpty {
            langCode = "default"
        }
        
        guard let finalURLString = urls[langCode] ?? urls["default"] ?? urls["en"], var url = URL(string: finalURLString) else {
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
}
