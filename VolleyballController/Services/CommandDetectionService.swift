import Foundation

class CommandDetectionService {
    static let shared = CommandDetectionService()

    private init() {}

    func detectCommand(from transcription: String) -> String? {
        let words = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Check for exact word matches first (most reliable)
        if let exactMatch = findExactWordMatch(in: words) {
            return exactMatch
        }

        // If no exact matches, check for partial matches
        return findPartialMatch(in: transcription)
    }

    private func findExactWordMatch(in words: [String]) -> String? {
        for word in words {
            switch word {
            case "left":
                return "left"
            case "right":
                return "right"
            case "cancel", "undo":
                return "cancel"
            case "no":  // Special case: "no" often misheard as "left"
                return "left"
            default:
                continue
            }
        }
        return nil
    }

    private func findPartialMatch(in transcription: String) -> String? {
        if transcription.contains("left") {
            return "left"
        } else if transcription.contains("right") {
            return "right"
        } else if transcription.contains("cancel") || transcription.contains("undo") {
            return "cancel"
        } else if transcription.contains("no") {
            return "left"  // "no" -> "left" mapping
        }
        return nil
    }
}
