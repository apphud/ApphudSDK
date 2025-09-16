//
//  ApphudLoadingView.swift
//  Pods
//
//  Created by Renat Kurbanov on 26.05.2025.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

@MainActor
class ApphudLoadingView: UIView {

    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .regular)
        let blur = UIVisualEffectView(effect: effect)
        blur.translatesAutoresizingMaskIntoConstraints = false
        return blur
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .label
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private var autoDismissTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.translatesAutoresizingMaskIntoConstraints = false
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.addSubview(blurView)
        self.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: self.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }

    /// Adds the loading view to the given parent view, starts animating, and sets an auto-dismiss timeout.
    ///
    /// - Parameters:
    ///   - parentView: The view in which to display the loading indicator.
    ///   - timeout: Duration in seconds after which the loading view will automatically disappear. Default is 30 seconds.
    func startLoading(in parentView: UIView, timeout: TimeInterval = 30.0) {
        Task { @MainActor in
            parentView.addSubview(self)
            NSLayoutConstraint.activate([
                self.topAnchor.constraint(equalTo: parentView.topAnchor),
                self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
                self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
                self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
            ])
            activityIndicator.startAnimating()

            autoDismissTimer?.invalidate()
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                self?.finishLoading()
            }
        }
    }

    /// Stops the animation, removes the loading view from its superview, and invalidates the timer.
    func finishLoading() {
        Task { @MainActor in
            autoDismissTimer?.invalidate()
            autoDismissTimer = nil
            activityIndicator.stopAnimating()
            self.removeFromSuperview()
        }
    }
}
#endif
