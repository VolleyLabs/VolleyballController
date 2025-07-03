import Foundation
import Speech
import AVFoundation
import WatchConnectivity

struct CommandHistoryItem: Identifiable {
    let id = UUID()
    let command: String
    let transcription: String
    let timestamp: Date
    let success: Bool
}

class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isListening = false
    @Published var hasPermission = false
    @Published var isWatchConnected = false
    @Published var lastDataReceived: Date?
    @Published var connectionStatus = "Initializing..."
    @Published var commandHistory: [CommandHistoryItem] = []

    private override init() {
        super.init()
        setupWatchConnectivity()
        requestPermissions()
    }

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.hasPermission = true
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self?.hasPermission = false
                    print("Speech recognition not authorized: \(authStatus)")
                @unknown default:
                    self?.hasPermission = false
                    print("Unknown speech recognition status")
                }
            }
        }
    }

    /// Appends incoming audio data from the Watch to the (streaming) speech
    /// recognizer. The first chunk sets up the recognition request / task and
    /// subsequent chunks are simply appended – enabling true streaming
    /// recognition instead of starting a brand-new request for every single
    /// message received via `WCSession`.
    private func transcribeAudioData(_ data: Data) {
        guard hasPermission else {
            print("SpeechRecognitionService: ❌ No speech recognition permission")
            return
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("SpeechRecognitionService: ❌ Speech recognizer not available")
            return
        }

        // Lazily create a streaming recognition request / task on the very
        // first audio chunk. We **do not** recreate them for every single chunk
        // otherwise the recognizer would never accumulate enough context to
        // properly decode speech which was the root-cause of the "partial only"
        // recognition that motivated this change.
        if recognitionRequest == nil {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            guard let recognitionRequest = recognitionRequest else {
                print("SpeechRecognitionService: ❌ Could not create recognition request")
                return
            }

            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.taskHint = .dictation
            recognitionRequest.requiresOnDeviceRecognition = true

            // Set context strings to help recognition
            if #available(iOS 16.0, *) {
                recognitionRequest.addsPunctuation = false
                recognitionRequest.contextualStrings = ["left", "right", "cancel", "undo"]
            }

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString.lowercased()
                    print("SpeechRecognitionService: Transcription → \(transcription) (isFinal: \(result.isFinal))")

                    // Process both partial and final results immediately
                    self.processTranscription(transcription, isFinal: result.isFinal)

                    // If the recognition is final, we can consider resetting the stream
                    // to prepare for the next utterance. This prevents old audio
                    // from lingering if the user pauses and then speaks again.
                    if result.isFinal {
                        self.resetRecognitionStream()
                    }
                }

                if let error = error {
                    print("SpeechRecognitionService: ❌ Recognition error – \(error.localizedDescription)")
                    self.stopRecognition()
                }
            }

            guard recognitionTask != nil else {
                print("SpeechRecognitionService: ❌ Failed to create recognition task")
                return
            }
        }

        guard let recognitionRequest = recognitionRequest else {
            return
        }

        let audioBuffer = dataToAudioBuffer(data)
        recognitionRequest.append(audioBuffer)

        audioDataCount += 1
        lastAudioTimestamp = Date()

        // Try to trigger recognition results by ending audio after accumulating some data
        if audioDataCount >= 10 { // After ~10 chunks of audio (about 1 second)
            recognitionRequest.endAudio()

            // Reset counter and create new stream for next batch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.audioDataCount = 0
                // Don't reset the full stream here, just the counter
            }
        }
    }

    /// Ends the current request and clears the related state so the next audio
    /// chunk will create a brand-new streaming request.
    private func resetRecognitionStream() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Clear command tracking to allow new commands
        lastCommandSent = nil
        commandSentTimestamp = nil
        audioDataCount = 0
        lastAudioTimestamp = nil
    }

    private func dataToAudioBuffer(_ data: Data) -> AVAudioPCMBuffer {
        // The Watch captures microphone input using the device's default
        // format (typically 44.1 kHz / mono). We reconstruct the same format on
        // the iPhone side so that the raw bytes line-up exactly with the
        // `AVAudioPCMBuffer` we hand to `SFSpeechRecognizer`. Using a mismatched
        // sample-rate was causing garbled / partial transcripts.

        let sampleRate: Double = 44_100
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                        sampleRate: sampleRate,
                                        channels: 1,
                                        interleaved: false)!
        let frameCount = UInt32(data.count / 2)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            fatalError("Failed to create audio buffer")
        }
        audioBuffer.frameLength = frameCount

        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let int16Pointer = buffer.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                return
            }
            audioBuffer.int16ChannelData![0].initialize(from: int16Pointer, count: Int(frameCount))
        }

        return audioBuffer
    }

    private var lastCommandSent: String?
    private var commandSentTimestamp: Date?
    private var audioDataCount = 0
    private var lastAudioTimestamp: Date?

    private func processTranscription(_ transcription: String, isFinal: Bool = false) {
        let lowercasedTranscription = transcription.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty transcriptions
        guard !lowercasedTranscription.isEmpty else {
            return
        }

        print("SpeechRecognitionService: Processing transcription: '\(lowercasedTranscription)' (isFinal: \(isFinal))")

        let words = lowercasedTranscription.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Check for command words with priority order
        var detectedCommand: String?

        // Check for exact word matches first (most reliable)
        for word in words {
            switch word {
            case "left":
                detectedCommand = "left"
                case "right":
                detectedCommand = "right"
                case "cancel", "undo":
                detectedCommand = "cancel"
                case "no":  // Special case: "no" often misheard as "left"
                detectedCommand = "left"
            default:
                continue
            }
        }

        // If no exact matches, check for partial matches in the full transcription
        if detectedCommand == nil {
            if lowercasedTranscription.contains("left") {
                detectedCommand = "left"
            } else if lowercasedTranscription.contains("right") {
                detectedCommand = "right"
            } else if lowercasedTranscription.contains("cancel") || lowercasedTranscription.contains("undo") {
                detectedCommand = "cancel"
            } else if lowercasedTranscription.contains("no") {
                detectedCommand = "left"  // "no" -> "left" mapping
            }
        }

        // Send command immediately if detected
        if let command = detectedCommand {
            let now = Date()
            let timeSinceLastCommand = commandSentTimestamp.map { now.timeIntervalSince($0) } ?? Double.infinity
            let shouldSend = lastCommandSent != command || timeSinceLastCommand > 0.5 // Reduced cooldown to 0.5 seconds

            if shouldSend {
                print("SpeechRecognitionService: ✅ SENDING COMMAND: '\(command)' from transcription: '\(transcription)'")
                sendCommandToWatch(command)
                lastCommandSent = command
                commandSentTimestamp = now

                // Add to history
                addToHistory(command: command, transcription: transcription, success: true)

                // Reset the stream after sending a command to prepare for the next command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.resetRecognitionStream()
                }
            } else {
                print("SpeechRecognitionService: ⏸️ Skipping duplicate command '\(command)' (last sent: \(timeSinceLastCommand)s ago)")
            }
        } else {
            print("SpeechRecognitionService: 🔍 No command detected in: '\(transcription)'")
            // Add failed recognition to history for debugging
            if !transcription.isEmpty {
                addToHistory(command: "(not recognized)", transcription: transcription, success: false)
            }
        }
    }

    private func sendCommandToWatch(_ command: String) {
        print("SpeechRecognitionService: 📤 Attempting to send command '\(command)' to watch")
        let session = WCSession.default

        guard session.activationState == .activated else {
            print("SpeechRecognitionService: ❌ WCSession not activated: \(session.activationState.rawValue)")
            return
        }

        guard session.isReachable else {
            print("SpeechRecognitionService: ❌ Watch not reachable")
            return
        }

        let message = ["speechCommand": command]
        print("SpeechRecognitionService: 📨 Sending message: \(message)")

        // Try sendMessage first (requires watch to be active)
        session.sendMessage(message, replyHandler: { response in
            print("SpeechRecognitionService: ✅ Watch responded to sendMessage: \(response)")
        }) { error in
            print("SpeechRecognitionService: ⚠️ sendMessage failed: \(error), trying updateApplicationContext...")

            // Fallback to updateApplicationContext for background delivery
            do {
                try session.updateApplicationContext(message)
                print("SpeechRecognitionService: ✅ Command sent via updateApplicationContext")
            } catch {
                print("SpeechRecognitionService: ❌ updateApplicationContext also failed: \(error)")
            }
        }
    }

    private func stopRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func addToHistory(command: String, transcription: String, success: Bool) {
        DispatchQueue.main.async {
            let item = CommandHistoryItem(
                command: command,
                transcription: transcription,
                timestamp: Date(),
                success: success
            )

            self.commandHistory.insert(item, at: 0)

            // Keep only last 10 items
            if self.commandHistory.count > 10 {
                self.commandHistory = Array(self.commandHistory.prefix(10))
            }
        }
    }
}

extension SpeechRecognitionService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated && session.isPaired)

            switch activationState {
            case .activated:
                self.connectionStatus = session.isPaired ? "Connected to Watch" : "Activated (Watch not paired)"
            case .inactive:
                self.connectionStatus = "Inactive"
            case .notActivated:
                self.connectionStatus = "Not activated"
            @unknown default:
                self.connectionStatus = "Unknown state"
            }
        }

        if let error = error {
            print("iPhone WCSession activation failed: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Activation failed: \(error.localizedDescription)"
            }
        } else {
            print("iPhone WCSession activated: \(activationState.rawValue)")
            print("iPhone WCSession isPaired: \(session.isPaired)")
            print("iPhone WCSession isWatchAppInstalled: \(session.isWatchAppInstalled)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("iPhone WCSession became inactive")
        DispatchQueue.main.async {
            self.connectionStatus = "Session inactive"
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("iPhone WCSession deactivated")
        DispatchQueue.main.async {
            self.connectionStatus = "Session deactivated"
        }
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("iPhone: Received message from Watch: \(message)")

        if message["test"] as? String == "ping" {
            let response: [String: Any] = ["test": "pong", "timestamp": Date().timeIntervalSince1970]
            replyHandler(response)
            print("iPhone: Sent pong response")
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        DispatchQueue.main.async {
            self.lastDataReceived = Date()
        }
        transcribeAudioData(messageData)
        replyHandler(Data()) // Acknowledge receipt
    }
}
