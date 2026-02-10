import UIKit

// MARK: - Haptic Feedback Service (Fix #7)
final class HapticService {
    static let shared = HapticService()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }
    
    func tap() {
        lightImpact.impactOccurred()
    }
    
    func button() {
        mediumImpact.impactOccurred()
    }
    
    func connect() {
        notification.notificationOccurred(.success)
    }
    
    func disconnect() {
        notification.notificationOccurred(.warning)
    }
    
    func messageReceived() {
        lightImpact.impactOccurred(intensity: 0.6)
    }
    
    func messageSent() {
        lightImpact.impactOccurred(intensity: 0.4)
    }
    
    func error() {
        notification.notificationOccurred(.error)
    }
    
    func selection() {
        self.selection.selectionChanged()
    }
}
