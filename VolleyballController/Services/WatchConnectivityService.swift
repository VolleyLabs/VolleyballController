import Foundation
import WatchConnectivity

protocol WatchConnectivityDelegate: AnyObject {
    func didReceiveAudioData(_ data: Data)
    func didUpdateConnectionStatus(_ status: String, isConnected: Bool)
}

class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    weak var delegate: WatchConnectivityDelegate?
    @Published var isWatchConnected = false
    @Published var connectionStatus = "Initializing..."

    private override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendCommandToWatch(_ command: String) {
        print("WatchConnectivityService: 📤 Attempting to send command '\(command)' to watch")
        let session = WCSession.default

        guard session.activationState == .activated else {
            print("WatchConnectivityService: ❌ WCSession not activated: " +
                  "\(session.activationState.rawValue)")
            return
        }

        guard session.isReachable else {
            print("WatchConnectivityService: ❌ Watch not reachable")
            return
        }

        let message = ["speechCommand": command]
        print("WatchConnectivityService: 📨 Sending message: \(message)")

        // Try sendMessage first (requires watch to be active)
        session.sendMessage(
            message,
            replyHandler: { response in
                print("WatchConnectivityService: ✅ Watch responded to sendMessage: \(response)")
            },
            errorHandler: { error in
                print("WatchConnectivityService: ⚠️ sendMessage failed: \(error), " +
                      "trying updateApplicationContext...")

                // Fallback to updateApplicationContext for background delivery
                do {
                    try session.updateApplicationContext(message)
                    print("WatchConnectivityService: ✅ Command sent via updateApplicationContext")
                } catch {
                    print("WatchConnectivityService: ❌ updateApplicationContext also failed: \(error)")
                }
            }
        )
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated && session.isPaired)

            switch activationState {
            case .activated:
                self.connectionStatus = session.isPaired
                    ? "Connected to Watch"
                    : "Activated (Watch not paired)"
            case .inactive:
                self.connectionStatus = "Inactive"
            case .notActivated:
                self.connectionStatus = "Not activated"
            @unknown default:
                self.connectionStatus = "Unknown state"
            }

            self.delegate?.didUpdateConnectionStatus(self.connectionStatus, isConnected: self.isWatchConnected)
        }

        if let error = error {
            print("iPhone WCSession activation failed: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Activation failed: \(error.localizedDescription)"
                self.delegate?.didUpdateConnectionStatus(self.connectionStatus, isConnected: false)
            }
        } else {
            print("iPhone WCSession activated: \(activationState.rawValue)")
            print("iPhone WCSession isPaired: \(session.isPaired)")
            print("iPhone WCSession isWatchAppInstalled: " +
                  "\(session.isWatchAppInstalled)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("iPhone WCSession became inactive")
        DispatchQueue.main.async {
            self.connectionStatus = "Session inactive"
            self.delegate?.didUpdateConnectionStatus(self.connectionStatus, isConnected: false)
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("iPhone WCSession deactivated")
        DispatchQueue.main.async {
            self.connectionStatus = "Session deactivated"
            self.delegate?.didUpdateConnectionStatus(self.connectionStatus, isConnected: false)
        }
        WCSession.default.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        print("iPhone: Received message from Watch: \(message)")

        if message["test"] as? String == "ping" {
            let response: [String: Any] = ["test": "pong", "timestamp": Date().timeIntervalSince1970]
            replyHandler(response)
            print("iPhone: Sent pong response")
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        delegate?.didReceiveAudioData(messageData)
        replyHandler(Data()) // Acknowledge receipt
    }
}
