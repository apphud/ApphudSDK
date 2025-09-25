import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
/// A SwiftUI wrapper for ApphudPaywallScreenController that displays the paywall fullscreen.
/// Automatically handles dismissal through SwiftUI mechanisms instead of UIKit.
public struct ApphudPaywallView: UIViewControllerRepresentable {
        
    public let controller: ApphudPaywallScreenController
    public let onDismiss: (() -> Void)?
    
    public init(controller: ApphudPaywallScreenController, onDismiss: (() -> Void)? = nil) {
        self.controller = controller
        self.onDismiss = onDismiss
    }
    
    public func makeUIViewController(context: Context) -> UIViewController {
        let wrapper = ApphudPaywallViewControllerWrapper(
            paywallController: controller,
            onDismiss: onDismiss ?? {
                if #available(iOS 15.0, *) {
                    context.environment.dismiss.callAsFunction()
                } else {
                    if let presentingVC = context.coordinator.presentingViewController {
                        presentingVC.dismiss(animated: true)
                    }
                }
            }
        )
        return wrapper
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let wrapper = uiViewController as? ApphudPaywallViewControllerWrapper {
            wrapper.updateDismissCallback(onDismiss ?? {
                if #available(iOS 15.0, *) {
                    context.environment.dismiss.callAsFunction()
                } else {
                    if let presentingVC = context.coordinator.presentingViewController {
                        presentingVC.dismiss(animated: true)
                    }
                }
            })
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject {
        weak var presentingViewController: UIViewController?
    }
}

class ApphudPaywallViewControllerWrapper: UIViewController {
    
    private let paywallController: ApphudPaywallScreenController
    private var onDismiss: (() -> Void)?
    private var originalShouldAutoDismiss: Bool = true
    
    init(paywallController: ApphudPaywallScreenController, onDismiss: @escaping () -> Void) {
        self.paywallController = paywallController
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        loadViewIfNeeded()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateDismissCallback(_ onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPaywallController()
        setupDismissalHandling()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if paywallController.parent == nil {
            setupPaywallController()
        }
        paywallController.viewWillAppear(animated)
    }
    
    private func setupPaywallController() {
        guard paywallController.parent == nil else { return }
        
        addChild(paywallController)
        view.addSubview(paywallController.view)
        paywallController.didMove(toParent: self)
        
        paywallController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            paywallController.view.topAnchor.constraint(equalTo: view.topAnchor),
            paywallController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paywallController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            paywallController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    private func setupDismissalHandling() {
        originalShouldAutoDismiss = paywallController.shouldAutoDismiss
        paywallController.shouldAutoDismiss = false
        
        let originalOnCloseButtonTapped = paywallController.onCloseButtonTapped
        paywallController.onCloseButtonTapped = { [weak self] in
            originalOnCloseButtonTapped?()
            if self?.originalShouldAutoDismiss == true {
                self?.handleDismissal()
            }
        }
        
        let originalOnTransactionCompleted = paywallController.onTransactionCompleted
        paywallController.onTransactionCompleted = { [weak self] result in
            originalOnTransactionCompleted?(result)
            if result.success && self?.originalShouldAutoDismiss == true {
                self?.handleDismissal()
            }
        }
    }
    
    private func handleDismissal() {
        onDismiss?()
    }
       
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        paywallController.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        paywallController.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        paywallController.viewDidDisappear(animated)
    }
    
    deinit {
        cleanupPaywallController()
        restoreOriginalSettings()
    }
    
    private func cleanupPaywallController() {
        guard paywallController.parent == self else { return }
        paywallController.willMove(toParent: nil)
        paywallController.view.removeFromSuperview()
        paywallController.removeFromParent()
    }
    
    private func restoreOriginalSettings() {
        paywallController.shouldAutoDismiss = originalShouldAutoDismiss
    }
}

// MARK: - SwiftUI Convenience Extensions

public extension ApphudPaywallView {
    func fullscreen() -> some View {
        self
            .ignoresSafeArea(.all)
            .navigationBarHidden(true)
    }
    
    @available(iOS 16.0, *)
    func fullscreenSheet() -> some View {
        self
            .ignoresSafeArea(.all)
            .navigationBarHidden(true)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
    }
}

#else
// Fallback for non-iOS platforms
public struct ApphudPaywallView: View {
    public init(controller: Any) {
        // Placeholder for non-iOS platforms
    }
    
    public var body: some View {
        Text("ApphudPaywallView is only available on iOS")
    }
}
#endif
