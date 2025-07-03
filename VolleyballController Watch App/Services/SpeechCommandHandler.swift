import Foundation

protocol SpeechCommandHandlerDelegate: AnyObject {
    func requestScoreAdjustment(isLeft: Bool, delta: Int, player: String?)
    func undoLastAction()
    func triggerLeftTap()
    func triggerRightTap()
}

class SpeechCommandHandler {
    weak var delegate: SpeechCommandHandlerDelegate?

    init(delegate: SpeechCommandHandlerDelegate? = nil) {
        self.delegate = delegate
    }

    func handleSpeechCommand(_ command: String) {
        print("SpeechCommandHandler: 🎯 Handling speech command: '\(command)'")
        switch command {
        case "left":
            print("SpeechCommandHandler: ⬅️ Processing LEFT command")
            delegate?.requestScoreAdjustment(isLeft: true, delta: 1, player: nil)
            HapticService.shared.playLeftHaptic()
            delegate?.triggerLeftTap()
            print("SpeechCommandHandler: ✅ LEFT score adjustment requested")
        case "right":
            print("SpeechCommandHandler: ➡️ Processing RIGHT command")
            delegate?.requestScoreAdjustment(isLeft: false, delta: 1, player: nil)
            HapticService.shared.playRightHaptic()
            delegate?.triggerRightTap()
            print("SpeechCommandHandler: ✅ RIGHT score adjustment requested")
        case "cancel":
            print("SpeechCommandHandler: ❌ Processing CANCEL command")
            delegate?.undoLastAction()
            HapticService.shared.playCancelHaptic()
            print("SpeechCommandHandler: ✅ CANCEL action completed")
        default:
            print("SpeechCommandHandler: ❓ Unknown command: '\(command)'")
        }
    }
}
