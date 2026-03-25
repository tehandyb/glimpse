import Foundation
import Speech
import AVFoundation

enum RecognizerState {
    case idle
    case listening
    case processing  // Utterance complete, waiting for Claude
}

@Observable
final class SpeechRecognizer {

    var state: RecognizerState = .idle
    var partialTranscript: String = ""

    // Called when the user finishes speaking — provides final transcript
    var onUtteranceComplete: ((String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Silence detection: fire after 1.5s of no new partial results
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let micAuth = await AVAudioApplication.requestRecordPermission()
        return speechAuth && micAuth
    }

    // MARK: - Start / Stop

    func startListening() {
        guard state == .idle else { return }
        do {
            try beginRecognition()
            state = .listening
        } catch {
            print("[SpeechRecognizer] Failed to start: \(error)")
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        silenceTimer?.invalidate()
        silenceTimer = nil
        state = .idle
        partialTranscript = ""
    }

    func resumeListening() {
        stopListening()
        startListening()
    }

    // MARK: - Recognition

    private func beginRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.partialTranscript = text
                    self.resetSilenceTimer(transcript: text)
                }

                if result.isFinal {
                    self.finalizeUtterance(transcript: text)
                }
            }

            if let error {
                // Ignore cancellation errors (happen on normal stop)
                let nsError = error as NSError
                if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                    print("[SpeechRecognizer] Recognition error: \(error)")
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Silence Detection

    private func resetSilenceTimer(transcript: String) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self, !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            self.finalizeUtterance(transcript: transcript)
        }
    }

    private func finalizeUtterance(transcript: String) {
        silenceTimer?.invalidate()
        silenceTimer = nil

        let trimmed = transcript.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Stop engine so we don't capture audio during Claude's response
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        DispatchQueue.main.async {
            self.state = .processing
            self.partialTranscript = trimmed
            self.onUtteranceComplete?(trimmed)
        }
    }
}
