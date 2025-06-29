import WatchConnectivity
import AVFoundation

class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var isConnected = false
    @Published var connectionStatus = "Initializing..."
    @Published var lastDataSent: Date?
    @Published var audioLevel: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isRecording = false
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupAudioEngine()
    }
    
    private func setupWatchConnectivity() {
        DispatchQueue.main.async {
            self.connectionStatus = "Setting up..."
        }
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            
            DispatchQueue.main.async {
                self.connectionStatus = "Activating..."
            }
            print("WatchConnectivity: Setting up session")
        } else {
            DispatchQueue.main.async {
                self.connectionStatus = "Not supported"
            }
            print("WatchConnectivity: Not supported on this device")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            print("Failed to setup audio engine")
            return
        }
        
        // Use the hardware's native format to avoid format mismatch errors
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        print("WatchConnectivity: Hardware audio format: \(hardwareFormat)")
        print("WatchConnectivity: HW Sample rate: \(hardwareFormat.sampleRate), Channels: \(hardwareFormat.channelCount)")
        
        // Install tap using the hardware format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        print("WatchConnectivity: Audio tap installed successfully with hardware format")
    }
    
    func startListening() {
        let session = WCSession.default
        
        print("WatchConnectivity: Attempting to start listening")
        print("WatchConnectivity: isSupported=\(WCSession.isSupported())")
        print("WatchConnectivity: activationState=\(session.activationState.rawValue)")
        print("WatchConnectivity: isReachable=\(session.isReachable)")
        
        guard !isRecording else {
            print("WatchConnectivity: Already recording")
            return
        }
        
        guard let audioEngine = audioEngine else {
            print("WatchConnectivity: Audio engine not available")
            return
        }
        
        guard session.activationState == .activated else {
            print("WatchConnectivity: Session not activated: \(session.activationState.rawValue)")
            DispatchQueue.main.async {
                self.connectionStatus = "Session not activated"
            }
            return
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            print("WatchConnectivity: Started audio recording")
            DispatchQueue.main.async {
                self.connectionStatus = session.isReachable ? "Recording & Connected" : "Recording (iPhone not reachable)"
            }
        } catch {
            print("WatchConnectivity: Failed to start audio engine: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Audio engine failed"
            }
        }
    }
    
    func stopListening() {
        guard isRecording, let audioEngine = audioEngine else { return }
        
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        isRecording = false
        print("Stopped audio recording")
        
        setupAudioEngine()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let session = WCSession.default
        
        // Calculate audio level for UI display (simplified)
        var avgLevel: Float = 0
        if let channelData = buffer.floatChannelData?[0] {
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) {
                sum += abs(channelData[i])
            }
            avgLevel = sum / Float(buffer.frameLength)
        } else if let int16Data = buffer.int16ChannelData?[0] {
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) {
                sum += abs(Float(int16Data[i]) / 32767.0)
            }
            avgLevel = sum / Float(buffer.frameLength)
        }
        
        DispatchQueue.main.async {
            self.audioLevel = avgLevel
        }
        
        guard session.isReachable else {
            return
        }
        
        let audioData = bufferToData(buffer)
        guard !audioData.isEmpty else {
            return
        }
        
        session.sendMessageData(audioData, replyHandler: { responseData in
            // Silent success
        }) { error in
            print("WatchConnectivity: ❌ Failed to send audio data: \(error)")
        }
        
        DispatchQueue.main.async {
            self.lastDataSent = Date()
        }
    }
    
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let inputSampleRate = buffer.format.sampleRate
        let targetSampleRate: Double = 44_100
        let channelCount = Int(buffer.format.channelCount)
        let inputLength = Int(buffer.frameLength)
        
        // Calculate resampling ratio
        let resampleRatio = targetSampleRate / inputSampleRate
        let outputLength = Int(Double(inputLength) * resampleRatio)
        
        var data = Data()
        data.reserveCapacity(outputLength * channelCount * 2) // 2 bytes per Int16 sample
        
        // Handle Float32 input (most common)
        if let floatData = buffer.floatChannelData {
            // Simple linear interpolation resampling
            for outputFrame in 0..<outputLength {
                let inputFrameFloat = Double(outputFrame) / resampleRatio
                let inputFrame = Int(inputFrameFloat)
                let fraction = inputFrameFloat - Double(inputFrame)
                
                for channel in 0..<channelCount {
                    var sample: Float
                    
                    if inputFrame < inputLength - 1 {
                        // Linear interpolation between adjacent samples
                        let sample1 = floatData[channel][inputFrame]
                        let sample2 = floatData[channel][inputFrame + 1]
                        sample = sample1 + Float(fraction) * (sample2 - sample1)
                    } else if inputFrame < inputLength {
                        // Use the last sample if we're at the end
                        sample = floatData[channel][inputFrame]
                    } else {
                        // Beyond input data, use silence
                        sample = 0.0
                    }
                    
                    // Clamp and convert to Int16
                    let clampedSample = max(-1.0, min(1.0, sample))
                    let intSample = Int16(clampedSample * 32767.0)
                    data.append(contentsOf: withUnsafeBytes(of: intSample) { Array($0) })
                }
            }
            
            return data
        }
        // Handle Int16 input (if hardware format is already Int16)
        else if let int16Data = buffer.int16ChannelData {
            // Similar resampling for Int16 data
            for outputFrame in 0..<outputLength {
                let inputFrameFloat = Double(outputFrame) / resampleRatio
                let inputFrame = Int(inputFrameFloat)
                let fraction = inputFrameFloat - Double(inputFrame)
                
                for channel in 0..<channelCount {
                    var sample: Int16
                    
                    if inputFrame < inputLength - 1 {
                        let sample1 = Float(int16Data[channel][inputFrame]) / 32767.0
                        let sample2 = Float(int16Data[channel][inputFrame + 1]) / 32767.0
                        let interpolated = sample1 + Float(fraction) * (sample2 - sample1)
                        sample = Int16(interpolated * 32767.0)
                    } else if inputFrame < inputLength {
                        sample = int16Data[channel][inputFrame]
                    } else {
                        sample = 0
                    }
                    
                    data.append(contentsOf: withUnsafeBytes(of: sample) { Array($0) })
                }
            }
            
            return data
        }
        
        print("WatchConnectivity: ❌ No audio data available in buffer")
        return Data()
    }
    
    func sendSpeechCommand(_ command: String) {
        guard WCSession.default.isReachable else { return }
        
        let message = ["command": command]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send command: \(error)")
        }
    }
    
    func sendTestMessage() {
        let session = WCSession.default
        
        print("WatchConnectivity: Testing connection")
        print("WatchConnectivity: Session state: activated=\(session.activationState == .activated), reachable=\(session.isReachable)")
        
        guard session.activationState == .activated else {
            DispatchQueue.main.async {
                self.connectionStatus = "Session not activated"
            }
            return
        }
        
        guard session.isReachable else {
            DispatchQueue.main.async {
                self.connectionStatus = "iPhone not reachable"
            }
            return
        }
        
        let testMessage: [String: Any] = ["test": "ping", "timestamp": Date().timeIntervalSince1970]
        
        session.sendMessage(testMessage, replyHandler: { response in
            print("WatchConnectivity: Received response: \(response)")
            DispatchQueue.main.async {
                self.connectionStatus = "Connected & Tested"
            }
        }) { error in
            print("WatchConnectivity: Test message failed: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Test failed: \(error.localizedDescription)"
            }
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated)
            
            switch activationState {
            case .activated:
                self.connectionStatus = session.isReachable ? "Connected" : "Activated (iPhone not reachable)"
            case .inactive:
                self.connectionStatus = "Inactive"
            case .notActivated:
                self.connectionStatus = "Not activated"
            @unknown default:
                self.connectionStatus = "Unknown state"
            }
        }
        
        if let error = error {
            print("WatchConnectivity: Session activation failed: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Activation failed: \(error.localizedDescription)"
            }
        } else {
            print("WatchConnectivity: Session activated with state: \(activationState.rawValue)")
            print("WatchConnectivity: isReachable=\(session.isReachable)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WatchConnectivity: Reachability changed - isReachable=\(session.isReachable)")
        DispatchQueue.main.async {
            if session.activationState == .activated {
                self.connectionStatus = session.isReachable ? "Connected" : "Activated (iPhone not reachable)"
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("WatchConnectivity: 📨 Received message from iPhone: \(message)")
        if let command = message["speechCommand"] as? String {
            print("WatchConnectivity: 🎯 Found speechCommand: '\(command)'")
            DispatchQueue.main.async {
                print("WatchConnectivity: 🔄 Dispatching to main queue...")
                self.handleSpeechCommand(command)
            }
        } else {
            print("WatchConnectivity: ❌ No 'speechCommand' key found in message")
            print("WatchConnectivity: 🔍 Available keys: \(Array(message.keys))")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("WatchConnectivity: 📨 Received message with reply handler from iPhone: \(message)")
        if let command = message["speechCommand"] as? String {
            print("WatchConnectivity: 🎯 Found speechCommand: '\(command)'")
            DispatchQueue.main.async {
                print("WatchConnectivity: 🔄 Dispatching to main queue...")
                self.handleSpeechCommand(command)
                
                // Send reply to confirm receipt
                let reply = ["status": "received", "command": command]
                replyHandler(reply)
                print("WatchConnectivity: ✅ Sent reply: \(reply)")
            }
        } else {
            print("WatchConnectivity: ❌ No 'speechCommand' key found in message")
            print("WatchConnectivity: 🔍 Available keys: \(Array(message.keys))")
            
            // Send error reply
            let reply = ["status": "error", "message": "No speechCommand found"]
            replyHandler(reply)
            print("WatchConnectivity: ❌ Sent error reply: \(reply)")
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("WatchConnectivity: 📨 Received application context from iPhone: \(applicationContext)")
        if let command = applicationContext["speechCommand"] as? String {
            print("WatchConnectivity: 🎯 Found speechCommand in context: '\(command)'")
            DispatchQueue.main.async {
                print("WatchConnectivity: 🔄 Dispatching context to main queue...")
                self.handleSpeechCommand(command)
            }
        } else {
            print("WatchConnectivity: ❌ No 'speechCommand' key found in application context")
            print("WatchConnectivity: 🔍 Available context keys: \(Array(applicationContext.keys))")
        }
    }
    
    private func handleSpeechCommand(_ command: String) {
        print("WatchConnectivity: 🎯 Processing speech command: '\(command)'")
        let lowercased = command.lowercased()
        
        switch lowercased {
        case "left":
            print("WatchConnectivity: 📢 Posting 'left' notification")
            NotificationCenter.default.post(name: .speechCommandReceived, object: "left")
            print("WatchConnectivity: ✅ 'left' notification posted")
        case "right":
            print("WatchConnectivity: 📢 Posting 'right' notification")
            NotificationCenter.default.post(name: .speechCommandReceived, object: "right")
            print("WatchConnectivity: ✅ 'right' notification posted")
        case "cancel", "undo":
            print("WatchConnectivity: 📢 Posting 'cancel' notification")
            NotificationCenter.default.post(name: .speechCommandReceived, object: "cancel")
            print("WatchConnectivity: ✅ 'cancel' notification posted")
        default:
            print("WatchConnectivity: ❓ Unknown speech command: '\(command)'")
        }
    }
}

extension Notification.Name {
    static let speechCommandReceived = Notification.Name("speechCommandReceived")
}
