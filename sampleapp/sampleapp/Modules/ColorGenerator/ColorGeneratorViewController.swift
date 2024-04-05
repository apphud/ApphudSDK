//
//  ColorGeneratorViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

class ColorGeneratorViewController: UIViewController {
    
    let generationLimitCount:Int = 5
    
    @IBOutlet weak var leftGenerationsLabel: UILabel!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var colorLabel: UILabel!
    
    var createdColor:String = ""
    
    let paramsService = ParamsService()
    let router = Router.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.updateUI()
    }
    
    func updateUI() {
        guard !Apphud.hasPremiumAccess() else {
            self.leftGenerationsLabel.text = "You have unlimited generations"
            return
        }
        
        self.leftGenerationsLabel.text = "You have \(generationLimitCount - paramsService.generationCount) generations left"
    }
    
    @IBAction func generateAction(_ sender: Any) {
        guard self.paramsService.generationCount >= generationLimitCount || Apphud.hasPremiumAccess() else {
            self.generateColor()
            return
        }
        
        router.showInAppPaywall { [self] purchased in
            if purchased {
                updateUI()
            }
        }
    }
    
    @IBAction func copyColorAction(_ sender: Any) {
        guard self.createdColor != "" else {
            return
        }
        
        Apphud.setUserProperty(key: .init("copied_color"), value: self.createdColor)
        Apphud.incrementUserProperty(key: .init("generations_count"), by: 1)
        
        UIPasteboard.general.string = self.createdColor
        
        let alert = UIAlertController(title: "Done", message: "Color #\(self.createdColor) was copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { (_) in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func generateColor() {
        let currentValue = self.paramsService.generationCount
        self.paramsService.generationCount = currentValue + 1
        
        let randomHexColor = self.generateRandomColor()
        self.colorView.backgroundColor = UIColor(hex: randomHexColor)
        self.colorLabel.textColor = UIColor(hex: randomHexColor)
        self.colorLabel.text = "Your color is: #\(randomHexColor)"
        
        self.createdColor = randomHexColor
        
        self.updateUI()
    }
    
    /* Randomly choose if number of letter, then randomly give
     back a value */
    private func randomCharacter() -> String? {
        let numbers = [0,1,2,3,4,5,6, 7, 8, 9]
        let letters = ["A","B","C","D","E","F"]
        
        let numberOrLetter = arc4random_uniform(2)
        
        switch numberOrLetter {
        case 0: return String(numbers[Int(arc4random_uniform(10))])
        case 1: return letters[Int(arc4random_uniform(6))]
        default: return nil
        }
    }
    
    /* Translate a character array of a color to a string
     representing a HEX*/
    private func characterArrayToHexString(array: [String]) -> String {
        var hexString = ""
        for character in array {
            hexString += character
        }
        return hexString
    }
    
    // Generate a random color in HEX
    private func generateRandomColor() -> String {
        var characterArray: [String] = []
        for _ in 0...5 {
            characterArray.append(randomCharacter()!)
        }
        return characterArrayToHexString(array: characterArray)
    }
}
