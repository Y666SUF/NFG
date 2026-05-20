import Combine
import SwiftUI
import UIKit

/// Publishes on-screen keyboard height for shifting content above the keyboard.
final class KeyboardLiftObserver: ObservableObject {
    @Published var height: CGFloat = 0
    @Published var animationDuration: Double = 0.25

    private var cancellables = Set<AnyCancellable>()

    init() {
        let show = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        let hide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        let change = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)

        show.merge(with: change)
            .compactMap { KeyboardLiftObserver.keyboardMetrics(from: $0) }
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                self?.height = metrics.height
                self?.animationDuration = metrics.duration
            }
            .store(in: &cancellables)

        hide
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.height = 0
                self?.animationDuration = 0.25
            }
            .store(in: &cancellables)
    }

    private static func keyboardMetrics(from notification: Notification) -> (height: CGFloat, duration: Double)? {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return nil
        }
        let screen = UIScreen.main.bounds
        let overlap = max(0, screen.maxY - frame.minY)
        guard overlap > 0 else { return nil }
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        return (overlap, duration)
    }
}
