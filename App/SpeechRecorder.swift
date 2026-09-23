import AVFoundation
import Foundation
import Observation
import Speech

/// On-device dictation into the composer. Audio never leaves the phone.
/// Speech finalizes a segment after every pause; segments are accumulated and recognition is restarted
/// so the user can keep dictating until they tap stop.
@MainActor
@Observable
final class SpeechRecorder {
    private(set) var isRecording = false
    private(set) var transcript = ""
    var errorMessage: String?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Text from segments that Speech already finalized or silently restarted.
    private var committed = ""
    /// The partial transcript of the segment currently being recognized.
    private var current = ""

    static func isAvailable(for language: Language) -> Bool {
        SFSpeechRecognizer(locale: Locale(identifier: language.code))?.isAvailable ?? false
    }

    func start(language: Language) async {
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""
        committed = ""
        current = ""

        guard await requestPermissions() else {
            errorMessage = String(localized: "Allow microphone and speech recognition in Settings to dictate.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.code)), recognizer.isAvailable else {
            errorMessage = String(localized: "Dictation is not available for \(language.name) on this device.")
            return
        }
        self.recognizer = recognizer

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            engine.prepare()
            try engine.start()
        } catch {
            errorMessage = error.localizedDescription
            cleanup()
            return
        }

        isRecording = true
        startSegment()
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        request?.endAudio()
        task?.finish()
        cleanup()
    }

    private func startSegment() {
        guard let recognizer, isRecording else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.request === request else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    // After a pause the recognizer may start a fresh transcription without marking the previous
                    // one final; a text that no longer continues the previous partial means exactly that.
                    if !self.current.isEmpty, !Self.continues(previous: self.current, next: text) {
                        self.committed = self.join(self.committed, self.current)
                    }
                    self.current = text
                    self.transcript = self.join(self.committed, self.current)
                    if result.isFinal {
                        self.committed = self.transcript
                        self.current = ""
                        if self.isRecording { self.startSegment() }
                    }
                } else if error != nil, self.isRecording {
                    // A segment can end without a result (silence); keep listening.
                    self.startSegment()
                }
            }
        }
    }

    /// True when `next` looks like a revision of `previous` (same opening words) rather than a restart.
    private static func continues(previous: String, next: String) -> Bool {
        let head = previous.split(separator: " ").prefix(2).joined(separator: " ").lowercased()
        let nextLower = next.lowercased()
        if next.count >= previous.count { return nextLower.hasPrefix(head) || head.count < 4 }
        return nextLower.hasPrefix(head)
    }

    private func join(_ a: String, _ b: String) -> String {
        let b = b.trimmingCharacters(in: .whitespaces)
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + " " + b
    }

    private func cleanup() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
