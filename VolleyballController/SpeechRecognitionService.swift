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

class SpeechRecognitionService: NSObject, ObservableObject, WatchConnectivityDelegate {
    static let shared = SpeechRecognitionService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let commandDetectionService = CommandDetectionService.shared
    private let audioProcessingService = AudioProcessingService.shared
    private let watchConnectivityService = WatchConnectivityService.shared

    @Published var isListening = false
    @Published var hasPermission = false
    @Published var isWatchConnected = false
    @Published var lastDataReceived: Date?
    @Published var connectionStatus = "Initializing..."
    @Published var commandHistory: [CommandHistoryItem] = []

    private var lastCommandSent: String?
    private var commandSentTimestamp: Date?
    private var audioDataCount = 0
    private var lastAudioTimestamp: Date?

    private override init() {
        super.init()
        watchConnectivityService.delegate = self
        requestPermissions()
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

    // MARK: - WatchConnectivityDelegate
    func didReceiveAudioData(_ data: Data) {
        DispatchQueue.main.async {
            self.lastDataReceived = Date()
        }
        transcribeAudioData(data)
    }

    func didUpdateConnectionStatus(_ status: String, isConnected: Bool) {
        DispatchQueue.main.async {
            self.connectionStatus = status
            self.isWatchConnected = isConnected
        }
    }

    private func transcribeAudioData(_ data: Data) {
        guard hasPermission else {
            print("SpeechRecognitionService: ❌ No speech recognition permission")
            return
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("SpeechRecognitionService: ❌ Speech recognizer not available")
            return
        }

        if recognitionRequest == nil {
            setupRecognitionRequest()
        }

        processAudioData(data)
    }

    private func setupRecognitionRequest() {
        guard let speechRecognizer = speechRecognizer else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("SpeechRecognitionService: ❌ Could not create recognition request")
            return
        }

        audioProcessingService.configureRecognitionRequest(recognitionRequest)
        createRecognitionTask(with: recognitionRequest)
    }

    private func createRecognitionTask(with request: SFSpeechAudioBufferRecognitionRequest) {
        guard let speechRecognizer = speechRecognizer else { return }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }

        guard recognitionTask != nil else {
            print("SpeechRecognitionService: ❌ Failed to create recognition task")
            return
        }
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let transcription = result.bestTranscription.formattedString.lowercased()
            print("SpeechRecognitionService: Transcription → \(transcription) (isFinal: \(result.isFinal))")

            processTranscription(transcription, isFinal: result.isFinal)

            if result.isFinal {
                resetRecognitionStream()
            }
        }

        if let error = error {
            print("SpeechRecognitionService: ❌ Recognition error – \(error.localizedDescription)")
            stopRecognition()
        }
    }

    private func processAudioData(_ data: Data) {
        guard let recognitionRequest = recognitionRequest else { return }

        let audioBuffer = audioProcessingService.dataToAudioBuffer(data)
        recognitionRequest.append(audioBuffer)

        audioDataCount += 1
        lastAudioTimestamp = Date()

        if audioDataCount >= 10 {
            recognitionRequest.endAudio()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.audioDataCount = 0
            }
        }
    }

    private func resetRecognitionStream() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        lastCommandSent = nil
        commandSentTimestamp = nil
        audioDataCount = 0
        lastAudioTimestamp = nil
    }

    private func processTranscription(_ transcription: String, isFinal: Bool = false) {
        let lowercasedTranscription = transcription.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !lowercasedTranscription.isEmpty else {
            return
        }

        print("SpeechRecognitionService: Processing transcription: '\(lowercasedTranscription)' (isFinal: \(isFinal))")

        if let command = commandDetectionService.detectCommand(from: lowercasedTranscription) {
            handleDetectedCommand(command, transcription: transcription)
        } else {
            handleUnrecognizedTranscription(transcription)
        }
    }

    private func handleDetectedCommand(_ command: String, transcription: String) {
        let now = Date()
        let timeSinceLastCommand = commandSentTimestamp.map { now.timeIntervalSince($0) }
                                  ?? Double.infinity
        let shouldSend = lastCommandSent != command || timeSinceLastCommand > 0.5

        if shouldSend {
            sendCommandAndUpdateState(command, transcription: transcription, timestamp: now)
        } else {
            print("SpeechRecognitionService: ⏸️ Skipping duplicate command '\(command)' " +
                  "(last sent: \(timeSinceLastCommand)s ago)")
        }
    }

    private func sendCommandAndUpdateState(_ command: String, transcription: String, timestamp: Date) {
        print("SpeechRecognitionService: ✅ SENDING COMMAND: '\(command)' " +
              "from transcription: '\(transcription)'")
        watchConnectivityService.sendCommandToWatch(command)
        lastCommandSent = command
        commandSentTimestamp = timestamp

        addToHistory(command: command, transcription: transcription, success: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.resetRecognitionStream()
        }
    }

    private func handleUnrecognizedTranscription(_ transcription: String) {
        print("SpeechRecognitionService: 🔍 No command detected in: '\(transcription)'")
        if !transcription.isEmpty {
            addToHistory(command: "(not recognized)", transcription: transcription, success: false)
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

            if self.commandHistory.count > 10 {
                self.commandHistory = Array(self.commandHistory.prefix(10))
            }
        }
    }
}
