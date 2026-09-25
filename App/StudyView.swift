import AVFoundation
import SwiftUI

/// Flashcard drill: one card, tap to reveal, swipe right = remember, left = forgot.
struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var card: FlashCard?
    @State private var revealed = false
    @State private var offset: CGSize = .zero
    @State private var reviewed = 0
    @State private var recent: [UUID] = []
    @State private var graduatedWord: String?
    @State private var synthesizer = AVSpeechSynthesizer()

    private var store: CardStore { CardStore.shared }
    private var remaining: Int { store.cards.filter { !$0.isLearned }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let card {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)

                        cardFace(card)
                            .offset(offset)
                            .rotationEffect(.degrees(Double(offset.width / 24)))
                            .overlay(alignment: .top) { verdictHint }
                            .gesture(dragGesture(card))
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { revealed.toggle() } }
                            .animation(.spring(duration: 0.3), value: offset)

                        Text(revealed ? "Swipe right if you remembered it, left if not." : "Tap the card to see the translation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        HStack(spacing: 12) {
                            verdictButton("Forgot", systemImage: "arrow.uturn.backward", prominent: false) { commit(card, known: false) }
                            verdictButton("Remember", systemImage: "checkmark", prominent: true) { commit(card, known: true) }
                        }
                    }
                    .frame(maxWidth: 520)
                    .padding()
                } else {
                    ContentUnavailableView("All cards learned", systemImage: "checkmark.seal",
                                           description: Text("Add more words from your translations to keep studying."))
                }
            }
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Study").font(.headline)
                        Text("\(reviewed) reviewed · \(remaining) to learn").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let graduatedWord {
                    Label("“\(graduatedWord)” is learned", systemImage: "checkmark.seal.fill")
                        .font(.callout)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear { if card == nil { card = store.nextToStudy(excluding: []) } }
        }
    }

    private func cardFace(_ card: FlashCard) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(card.language.uppercased())
                Spacer()
                if !card.level.isEmpty { LevelBadge(level: card.level) }
                if !card.partOfSpeech.isEmpty { Text(card.partOfSpeech).italic() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            if let example = card.examples.first {
                contextLine(example.text, card: card)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Text(card.headword)
                .font(.system(size: 38, weight: .semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if !card.transcription.isEmpty {
                Text(card.transcription).font(.title3).foregroundStyle(.secondary)
            }

            // The answer fades in below the word instead of flipping the card over.
            Group {
                if revealed {
                    VStack(spacing: 6) {
                        Divider().padding(.vertical, 4)
                        Text(card.translations.joined(separator: ", "))
                            .font(.title2.weight(.medium))
                            .multilineTextAlignment(.center)
                        if let example = card.examples.first, !example.translation.isEmpty {
                            Text(example.translation)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Color.clear.frame(height: 60)
                }
            }

            Spacer()

            Button { speak(card) } label: { Image(systemName: "speaker.wave.2.fill").font(.title3) }
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 420)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    /// The example sentence with the card's word marked the way it is in translations.
    private func contextLine(_ sentence: String, card: FlashCard) -> Text {
        let forms = card.allForms
        var result = Text("")
        for (i, token) in sentence.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            let word = token.trimmingCharacters(in: .punctuationCharacters).lowercased()
            var piece = Text(String(token))
            piece = forms.contains(word) ? piece.foregroundColor(.orange).bold() : piece.foregroundColor(.secondary)
            result = result + (i == 0 ? piece : Text(" ") + piece)
        }
        return result
    }

    @ViewBuilder
    private var verdictHint: some View {
        if abs(offset.width) > 30 {
            let known = offset.width > 0
            Text(known ? "Remember" : "Forgot")
                .font(.headline)
                .foregroundStyle(known ? Color.green : Color.orange)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 16)
        }
    }

    private func verdictButton(_ title: LocalizedStringKey, systemImage: String, prominent: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(prominent ? .accentColor : .secondary)
        .controlSize(.large)
    }

    private func dragGesture(_ card: FlashCard) -> some Gesture {
        DragGesture()
            .onChanged { offset = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > 100 {
                    commit(card, known: value.translation.width > 0)
                } else {
                    offset = .zero
                }
            }
    }

    private func commit(_ card: FlashCard, known: Bool) {
        offset = CGSize(width: known ? 600 : -600, height: 0)
        let graduated = store.record(card, known: known)
        reviewed += 1
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            revealed = false
            offset = .zero
            recent = Array((recent + [card.id]).suffix(2))
            self.card = store.nextToStudy(excluding: recent)
            if graduated {
                withAnimation { graduatedWord = card.headword }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { graduatedWord = nil }
            }
        }
    }

    private func speak(_ card: FlashCard) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: card.headword)
        utterance.voice = Self.voice(for: card.language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    /// Best installed voice for a language code like "en" or "en-GB": enhanced quality first.
    private static func voice(for language: String) -> AVSpeechSynthesisVoice? {
        let code = language.lowercased()
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased() == code || $0.language.lowercased().hasPrefix(code + "-")
        }
        return candidates.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }
}
