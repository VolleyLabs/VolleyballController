import WatchKit

class HapticService {
    static let shared = HapticService()

    private init() {}

    func playLeftHaptic() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    func playRightHaptic() {
        WKInterfaceDevice.current().play(.success)
    }

    func playCancelHaptic() {
        WKInterfaceDevice.current().play(.failure)
    }
}
