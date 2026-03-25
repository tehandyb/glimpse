import Foundation

enum AppPhase {
    case idle           // Listening for voice
    case processing     // Utterance captured, calling Claude
    case responding     // Claude speaking answer
    case error(String)
}

@Observable
final class GlimpseViewModel {

    var phase: AppPhase = .idle
    var transcript: String = ""          // Current or last user utterance
    var lastResponse: String = ""        // Last Claude response
    var showSettings: Bool = false

    let glasses = GlassesManager()
    let recognizer = SpeechRecognizer()
    let speaker = Speaker()
    let claude = ClaudeClient.shared

    // MARK: - Setup

    func setup() async {
        // Request STT + mic permissions
        let granted = await recognizer.requestPermissions()
        guard granted else {
            phase = .error("Microphone or speech recognition permission denied.")
            return
        }

        // Wire up recognizer callback
        recognizer.onUtteranceComplete = { [weak self] utterance in
            Task { await self?.handleUtterance(utterance) }
        }

        // Wire up speaker callback: resume listening after response
        speaker.onSpeakingFinished = { [weak self] in
            self?.resumeListening()
        }

        // Start glasses connection + listening
        glasses.start()
        recognizer.startListening()
    }

    func teardown() {
        recognizer.stopListening()
        glasses.stop()
        speaker.stopSpeaking()
    }

    // MARK: - Pipeline

    private func handleUtterance(_ text: String) async {
        await MainActor.run {
            transcript = text
            phase = .processing
        }

        // Capture the latest camera frame
        let frameData = glasses.captureCurrentFrame()

        do {
            let response = try await claude.query(text: text, frame: frameData)
            await MainActor.run {
                lastResponse = response
                phase = .responding
            }
            speaker.speak(response)
        } catch {
            await MainActor.run {
                phase = .error(error.localizedDescription)
                lastResponse = error.localizedDescription
            }
            speaker.speak(error.localizedDescription)
        }
    }

    private func resumeListening() {
        phase = .idle
        recognizer.resumeListening()
    }

    // MARK: - Settings

    func saveAPIKey(_ key: String) {
        claude.apiKey = key.trimmingCharacters(in: .whitespaces)
    }
}
