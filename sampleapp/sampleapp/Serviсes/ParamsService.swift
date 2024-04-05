//
//  ParamsService.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import Foundation

final class ParamsService {
    var showedTutorial: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showedTutorial")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showedTutorial")
        }
    }
    
    var generationCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: "generationCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "generationCount")
        }
    }
}
