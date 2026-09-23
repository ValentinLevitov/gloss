import AVFoundation
import SwiftUI

/// Flashcard drill: one big card, tap to flip, swipe right = remember, left = forgot.
struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var card: FlashCard?
    @State private var flipped = false
    @State private var offset: CGSize = .zero
    @State private var remembered = 0
    @State private var forgot = 0
    @State private var graduatedWord: String?
    @State private var upcoming: FlashCard?
    @State private var recent: [UUID] = []
    @State private var synthesizer = AVSpeechSynthesizer()

    private var store: CardStore { CardStore.shared }
    private var remaining: Int { store.cards.filter { !$0.isLearned }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.2, green: 0.45, blue: 1), Color(red: 0.1, green: 0.24, blue: 0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                if let card {
                    VStack(spacing: 24) {
                        Text("Words you forget will come up more often.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)

                        Spacer()

                        ZStack {
                            if let next = upcoming {
                                cardFace(next, flipped: false)
                                    .scaleEffect(0.94)
                                    .offset(y: 18)
                                    .opacity(0.7)
                            }
                            cardFace(card, flipped: flipped)
                                .offset(offset)
                                .rotationEffect(.degrees(Double(offset.width / 20)))
                                .overlay(alignment: .top) { verdictHint }
                                .gesture(dragGesture(card))
                                .onTapGesture { withAnimation(.spring(duration: 0.35)) { flipped.toggle() } }
                                .animation(.spring(duration: 0.3), value: offset)
                        }

                        Spacer()

                        HStack(spacing: 16) {
                            verdictButton("Forgot", systemImage: "arrow.uturn.backward", tint: .orange) { commit(card, known: false) }
                            verdictButton("Remember", systemImage: "checkmark", tint: .green) { commit(card, known: true) }
                        }
                    }
                    .frame(maxWidth: 520)   // keeps the card a card on iPad
                    .padding()
                } else {
                    ContentUnavailableView("All cards learned", systemImage: "checkmark.seal",
                                           description: Text("Add more words from your translations to keep studying."))
                }
            }
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Study").font(.headline)
                        Text("\(remembered) · \(forgot) · \(remaining) left").font(.caption2).opacity(0.75)
                    }
                    .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .bottom) {
                if let graduatedWord {
                    Label("“\(graduatedWord)” is learned", systemImage: "checkmark.seal.fill")
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.green.opacity(0.9), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                if card == nil {
                    card = store.nextToStudy(excluding: [])
                    upcoming = store.nextToStudy(excluding: [card?.id].compactMap { $0 })
                }
            }
        }
    }

    private func cardFace(_ card: FlashCard, flipped: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(card.language.uppercased())
                streakDots(card)
                Spacer()
                if !card.level.isEmpty { LevelBadge(level: card.level) }
                if !card.partOfSpeech.isEmpty { Text(card.partOfSpeech).italic() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            if flipped {
                Text(card.translations.joined(separator: ", "))
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let example = card.examples.first, !example.translation.isEmpty {
                    Text(example.translation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            } else {
                if let example = card.examples.first {
                    contextLine(example.text, card: card)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                Text(card.headword)
                    .font(.system(size: 40, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 4)
                if !card.transcription.isEmpty {
                    Text(card.transcription).font(.title3).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button { speak(card) } label: { Image(systemName: "speaker.wave.2.fill").font(.title3) }
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.9, contentMode: .fit)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    /// The example sentence with the card's word highlighted the way it is in translations.
    private func contextLine(_ sentence: String, card: FlashCard) -> Text {
        let forms = card.allForms
        var result = Text("")
        for (i, token) in sentence.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            let word = token.trimmingCharacters(in: .punctuationCharacters).lowercased()
            var piece = Text(String(token))
            if forms.contains(word) {
                piece = piece.foregroundColor(.orange).bold()
            } else {
                piece = piece.foregroundColor(.secondary)
            }
            result = result + (i == 0 ? piece : Text(" ") + piece)
        }
        return result
    }

    /// Progress toward graduation: one dot per consecutive "remember".
    private func streakDots(_ card: FlashCard) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<FlashCard.graduationStreak, id: \.self) { i in
                Circle()
                    .fill(i < card.knowStreak ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.leading, 6)
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

    private func verdictButton(_ title: LocalizedStringKey, systemImage: String, tint: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(tint.opacity(0.85), in: Capsule())
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
        if known { remembered += 1 } else { forgot += 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            flipped = false
            offset = .zero
            recent = Array((recent + [card.id]).suffix(2))
            self.card = upcoming ?? store.nextToStudy(excluding: recent)
            upcoming = store.nextToStudy(excluding: recent + [self.card?.id].compactMap { $0 })
            if graduated {
                withAnimation { graduatedWord = card.headword }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { graduatedWord = nil }
            }
        }
    }

    private func speak(_ card: FlashCard) {
        // Playback category so the word is audible with the silent switch on and after dictation used the mic.
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
