//
//  ApphudSurveyController.swift
//  apphud
//
//  Created by Renat on 30/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit

internal class ApphudInquiryController: UIViewController {

    private var rule: ApphudRule
    
    private var container = UIView()
    
    private var screenControllers = [UIViewController]()
    
    private lazy var titleLabel : UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textColor = UIColor.black
        label.textAlignment = .center
        label.numberOfLines = 5
        label.translatesAutoresizingMaskIntoConstraints = false
        self.container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 0),
            ])
        return label
    }()
    
    private lazy var subtitleLabel : UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = UIColor.black
        label.textAlignment = .center
        label.numberOfLines = 5
        label.translatesAutoresizingMaskIntoConstraints = false
        self.container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 10),
            ])
        return label
    }()
    
    private init(rule: ApphudRule) {
        self.rule = rule
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
    
    internal class func show(rule: ApphudRule){
        
        let visibleViewController = apphudVisibleViewController()
        if visibleViewController is ApphudNavigationController {
            return
        }
        
        let controller = ApphudInquiryController(rule: rule)
        let nc = ApphudNavigationController(rootViewController: controller)
        
        if let style = ApphudInternal.shared.delegate?.apphudScreenPresentationStyle?(){
            nc.modalPresentationStyle = style
        }
                
        nc.setNavigationBarHidden(true, animated: false)
        visibleViewController?.present(nc, animated: true, completion: nil)
        controller.constructView()
        
        ApphudInternal.shared.trackRuleEvent(ruleID: rule.id, params: ["kind" : "enquiry_presented"], callback: {})
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0),
            container.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: 0),            
            container.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor, constant: 0)
            ])
        self.view.backgroundColor = UIColor.white
        
        let dismissButton = UIButton(type: .system)
        dismissButton.setTitleColor(UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1), for: .normal)
        dismissButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.setTitle("╳", for: .normal)
        self.view.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
            ])
    }
    
    private func constructView(){
        if self.rule.condition == .billingIssue {
            self.constructBillingIssue()              
        } else {
            self.constructInquiry()
        }
    }
    
    private func constructBillingIssue(){
        let question = "Subscription couldn't be renewed" //
        self.titleLabel.text = question
        self.subtitleLabel.text = "Please update payment information in your App Store account"
        let action = "Update payment info"
        let button = actionButton(title: action)
        button.addTarget(self, action: #selector(handleOpenBilling), for: .touchUpInside)
        button.topAnchor.constraint(equalTo: self.subtitleLabel.bottomAnchor, constant: 20).isActive = true
        button.bottomAnchor.constraint(equalTo: self.container.bottomAnchor, constant: 0).isActive = true
    }
    
    private func constructInquiry(){
        self.titleLabel.text = self.rule.question
        var prevButton : UIButton? = nil
        for option in self.rule.options {
            let button = actionButton(title: option.title)
            button.option = option
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            if prevButton != nil {
                button.topAnchor.constraint(equalTo: prevButton!.bottomAnchor, constant: 10).isActive = true
            } else {
                button.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 20).isActive = true
            }
            prevButton = button
        }
        
        if prevButton != nil {
            prevButton?.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 0).isActive = true
        }
        
        self.loadScreensInAdvance()
    }     
    
    private func actionButton(title: String) -> ApphudInquiryButton {
        let button = ApphudInquiryButton(type: .system)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        button.setTitleColor(UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1), for: .normal)
        button.setTitle(title, for: .normal)
        container.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.97, alpha: 1).cgColor
        button.clipsToBounds = true
        button.layer.cornerRadius = 10
        
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10).isActive = true
        button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10).isActive = true
        return button
    }
        
    @objc private func buttonTapped(sender: ApphudInquiryButton){
        apphudLog("option selected: \(String(describing: sender.option))")
        if let option = sender.option {
            ApphudInternal.shared.trackRuleEvent(ruleID: self.rule.id, params: ["kind" : "option_selected", "option_id" : option.id]){}
            switch option.optionAction {
            case .presentFeedback:                
                let controller = ApphudFeedbackController(rule: self.rule, option: option)
                self.navigationController?.pushViewController(controller, animated: true)                            
            case .presentPurchase:
                if #available(iOS 12.2, *) {
                    if let controller = screenControllers.first(where: {$0.title == option.id}) {
                        self.navigationController?.pushViewController(controller, animated: true)
                    }
                }
            }
        }
    }
    
    @objc private func dismissTapped(){
        apphudLog("dismiss tapped")
        self.dismiss()
    }
    
    @objc private func handleOpenBilling(sender: ApphudInquiryButton){
        if let url = URL(string: "https://apps.apple.com/account/billing"), UIApplication.shared.canOpenURL(url){
            sender.isEnabled = false
            ApphudInternal.shared.trackRuleEvent(ruleID: self.rule.id, params: ["kind" : "update_payment_tapped"]) { 
                self.dismiss()
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func dismiss(){
        ApphudInternal.shared.delegate?.apphudWillDismissScreen?()
        (self.navigationController ?? self).dismiss(animated: true) { 
            ApphudInternal.shared.delegate?.apphudDidDismissScreen?()
        }
    }
    
    private func loadScreensInAdvance(){
        for option in self.rule.options {
            if option.optionAction == .presentPurchase {
                if #available(iOS 12.2, *) {
                    let controller = ApphudScreenController(rule: self.rule, option: option)
                    _ = controller.view
                    controller.title = option.id
                    screenControllers.append(controller)
                }
            }
        }
    }
}


class ApphudInquiryButton: UIButton {
    var option: ApphudRuleOption?
}

class ApphudNavigationController: UINavigationController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get{
            return .portrait
        }
    }
}
