import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var session = ConversationSession()
    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showHistory = false
    @State private var showCards = false
    @State private var showStudy = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var languages = LanguageSettings.current
    @State private var recorder = SpeechRecorder()
    @FocusState private var composerFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                ThreadView(session: session) { composerFocused = true }
                    .padding()
                    .frame(maxWidth: 720)   // readable line length on iPad
                    .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.top, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if session.messages.isEmpty, session.errorMessage == nil {
                    ContentUnavailableView {
                        Label("ru ↔ en", systemImage: "character.bubble")
                    } description: {
                        Text("Type a word or a text. Then select any fragment to discuss it — the thread keeps its context.")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    StudyBanner(isPresented: $showStudy)
                    composer
                }
            }
            .fullScreenCover(isPresented: $showStudy) { StudyView() }
            .navigationTitle("Gloss")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button { showSettings = true } label: {
                        VStack(spacing: 1) {
                            Text("Gloss").font(.headline)
                            Text(languages.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                    Button { showCards = true } label: { Image(systemName: "rectangle.stack") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { session.startNewThread() } label: { Image(systemName: "square.and.pencil") }
                        .disabled(session.messages.isEmpty)
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: { languages = .current }) { SettingsView() }
            .sheet(isPresented: $showOnboarding) { OnboardingView() }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    if let image { translate(image) }
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showLibrary, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                pickedItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        translate(image)
                    }
                }
            }
            .sheet(isPresented: $showCards) { CardsView() }
            .sheet(isPresented: $showHistory) {
                HistoryView { session.startThread(from: $0) }
            }
            .onAppear {
                ModelCatalog.refreshStale()
                if !AppGroup.defaults.bool(forKey: OnboardingView.completedKey) {
                    showOnboarding = true
                } else if session.messages.isEmpty {
                    composerFocused = true
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                languages = .current
                // The thread and the cards may have changed in the system translation sheet while the app was in the background.
                session.reload()
                CardStore.shared.reload()
                QuickActions.shared.refresh()
                openStudyIfRequested()
                openCameraIfRequested()
            }
            .onChange(of: QuickActions.shared.pendingStudy) { _, _ in openStudyIfRequested() }
            .onChange(of: QuickActions.shared.pendingCamera) { _, _ in openCameraIfRequested() }
        }
        .modifier(DictationBridge(recorder: recorder, session: session, focused: $composerFocused))
    }

    private var composer: some View {
        composerView.frame(maxWidth: 720).frame(maxWidth: .infinity).background(.bar)
    }

    private var composerView: some View {
        ComposerView(
            session: session,
            focused: $composerFocused,
            onPhoto: { source in
                composerFocused = false
                switch source {
                case .camera: showCamera = true
                case .library: showLibrary = true
                }
            },
            dictation: ComposerView.DictationControl(
                isRecording: recorder.isRecording,
                start: { language in
                    composerFocused = false
                    Task { await recorder.start(language: language) }
                },
                stop: { recorder.stop() }
            )
        )
    }

    /// Home-screen quick action "Study words".
    private func openStudyIfRequested() {
        guard QuickActions.shared.pendingStudy else { return }
        QuickActions.shared.pendingStudy = false
        showSettings = false
        showCards = false
        showHistory = false
        showStudy = true
    }

    /// Quick action / widget "Translate with camera".
    private func openCameraIfRequested() {
        guard QuickActions.shared.pendingCamera, CameraPicker.isAvailable else { return }
        QuickActions.shared.pendingCamera = false
        showSettings = false
        showCards = false
        showHistory = false
        showStudy = false
        showOnboarding = false
        composerFocused = false
        showCamera = true
    }

    private func translate(_ image: UIImage) {
        session.cancel()
        session.errorMessage = nil
        session.isRecognizing = true
        Task {
            defer { session.isRecognizing = false }
            do {
                let text = try await ImageTextRecognizer.text(in: image, languages: languages)
                session.translate(text)
            } catch {
                session.errorMessage = error.localizedDescription
            }
        }
    }
}

/// Pushes dictation results into the composer draft.
private struct DictationBridge: ViewModifier {
    let recorder: SpeechRecorder
    let session: ConversationSession
    var focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: recorder.transcript) { _, text in
                if recorder.isRecording { session.draft = text }
            }
            .onChange(of: recorder.isRecording) { _, recording in
                if !recording, !recorder.transcript.isEmpty {
                    session.draft = recorder.transcript
                    focused.wrappedValue = true
                }
            }
            .onChange(of: recorder.errorMessage) { _, message in
                if let message { session.errorMessage = message }
            }
    }
}

/// One-tap way into study mode, shown above the composer while there are cards to learn.
private struct StudyBanner: View {
    @Binding var isPresented: Bool
    private var count: Int { CardStore.shared.cards.filter { !$0.isLearned }.count }

    var body: some View {
        if count > 0 {
            Button { isPresented = true } label: {
                HStack {
                    Label("\(count) words to learn", systemImage: "rectangle.stack")
                    Spacer()
                    Text("Study").fontWeight(.semibold)
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .tint(.primary)
            .background(.bar)
        }
    }
}
