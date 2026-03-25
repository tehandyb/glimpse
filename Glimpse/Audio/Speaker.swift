import AVFoundation

@Observable
final class Speaker: NSObject {

    var isSpeaking: Bool = false
    var onSpeakingFinished: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Audio Session

    /// Call once at app startup. Routes audio to Bluetooth output (glasses speakers).
    static func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playAndRecord keeps the mic open; .allowBluetooth routes mic from glasses HFP
            // .allowBluetoothA2DP routes speaker output to glasses
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("[Speaker] Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Speak

    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52          // Slightly faster than default (0.5)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension Speaker: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onSpeakingFinished?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
