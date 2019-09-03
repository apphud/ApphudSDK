//
//  ApphudRule.swift
//  apphud
//
//  Created by Renat on 30/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit

enum ApphudRuleCondition: String {
    case trialCanceled = "trial_canceled"
    case subscriptionCanceled = "subscription_canceled"
    case billingIssue = "billing_issue"
}

enum ApphudRuleOptionAction: String{
    case presentFeedback = "present_feedback_screen"
    case presentPurchase = "present_purchase_screen"
}

struct ApphudRule {
    
    var id: String
    var question: String
    var condition: ApphudRuleCondition
    var options = [ApphudRuleOption]()
    init(dictionary: [String : Any], ruleID: String) {
        question = dictionary["question"] as? String ?? ""
        id = ruleID
        condition = ApphudRuleCondition(rawValue: dictionary["rule_condition"] as? String ?? "") ?? .subscriptionCanceled
        for subdict in (dictionary["options"] as? [[String : Any]]) ?? [] {
            let ruleOption = ApphudRuleOption(dictionary: subdict)
            options.append(ruleOption)
        }
    }
    
}

struct ApphudRuleOption {
    var id: String
    var feedbackQuestion: String
    var optionAction: ApphudRuleOptionAction
    var screenID: String?
    var title: String
    
    init(dictionary: [String : Any]) {
        feedbackQuestion = dictionary["feedback_question"] as? String ?? ""
        id = dictionary["id"] as? String ?? ""
        optionAction = ApphudRuleOptionAction(rawValue: dictionary["option_action"] as? String ?? "") ?? .presentFeedback
        screenID = dictionary["screen_id"] as? String
        title = dictionary["title"] as? String ?? ""
    }
}
