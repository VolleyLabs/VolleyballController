import Foundation
import Speech
import AVFoundation

class AudioProcessingService {
    static let shared = AudioProcessingService()

    private init() {}

    func dataToAudioBuffer(_ data: Data) -> AVAudioPCMBuffer {
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

    func configureRecognitionRequest(_ request: SFSpeechAudioBufferRecognitionRequest) {
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = true

        // Set context strings to help recognition
        if #available(iOS 16.0, *) {
            request.addsPunctuation = false
            request.contextualStrings = ["left", "right", "cancel", "undo"]
        }
    }
}
