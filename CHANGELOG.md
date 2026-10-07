# Changelog

All notable changes to Gloss are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] — 2026-10-07

### Added
- Flashcards: "Add to cards" on any word or phrase (up to 8 words, so idioms qualify) — in the sheet header, next to a translated word in the thread, and in the text selection menu. Cards are built by the model in dictionary form (singular, infinitive; object slots as "someone"/"something"), with part of speech, IPA, translations, forms, examples and CEFR level.
- Study mode: one card at a time, tap to reveal, swipe right = remember / left = forgot; cards you forget come back sooner, four consecutive "remember" swipes graduate a card. Entry points: banner above the composer, a button in the Cards list, a home-screen quick action and a widget.
- Highlighting of card words in every translation: tinted background for single words, tinted underline for whole phrases (orange while learning, green once learned); separable phrasal verbs and idioms with an object slot are matched with words in between.
- Cards list with search, learned/learning sections, swipe to mark learned or delete; card detail screen.
- Dictation into the composer (on-device speech recognition), with a transcript that keeps its tail visible while recording.
- Text size setting (System … Huge), applied in the app and in the system sheet.
- Home-screen quick actions: "Translate with camera" and "Study words" (with the count).
- `gloss://camera` and `gloss://study` URL scheme; lock-screen and home-screen widgets for both.
- UI localized into German, French, Spanish, Italian, Brazilian Portuguese, Ukrainian, Polish, Turkish, Japanese, Korean and Simplified Chinese (in addition to English and Russian).
- Setup: the API key is verified as it is typed or pasted, with a visible status and Retry; Next unlocks once a key is saved.
- Unit tests (conversation budget, model catalog parsing, card parsing and scheduling, heuristics, provider SSE parsers via a URLProtocol stub, phrase matching), a fresh-install smoke test and a setup-flow UI test; GitHub Actions CI on every push.

### Changed
- Composer: the same controls in every state — camera and mic on the left, one send button on the right that asks when a fragment is attached (or in the sheet) and translates otherwise; long-press offers the other action. Paste replaces send when the field is empty.
- System sheet: a word or short phrase stays pinned above the translation with the Add-to-cards button; long passages stay in the feed. The first translation opens at its start instead of scrolling to the end.
- Study mode restyled to system colours; no card stack, no streak dots; a session counter in the title; the answer fades in under the word instead of a 3D flip.
- The target language is stated per request from on-device language detection, so a thread full of EN→RU translations no longer pulls a Russian text into Russian.
- Content width capped on iPad; Add-to-cards is one shared control everywhere.
- Prompt template and helper strings are in English; the answer language comes from the language settings.

### Fixed
- Starting dictation wiped text already typed in the composer; dictation now appends to it.
- Review follow-ups: send is disabled while dictating; the send icon differs between ask and translate; the draft field is actually kept stable (`.equatable()`); noun phrases match adjacently and only verbs may be split by an object; phrase regexes are compiled once; widgets reload when cards change; the camera quick action no longer sticks on devices without a camera; key verification runs once per trigger.
- The thread jumped when the keyboard was dismissed, so a long-press landed on the wrong text; the view now only follows a reply while it streams.
- Backspace after swipe-typing deleted letter by letter instead of the whole word: the text field is no longer rebuilt on every keystroke.
- Settings (model, languages) were only saved by the Done button; dismissing the sheet by swipe discarded them. They now apply as soon as they change.
- System sheet rendered empty after the pinned header was added (a UIViewRepresentable inside the top safe-area inset); the header now uses plain Text.
- Discuss: sending with a fragment attached translated the draft instead of asking about the fragment, and left the fragment in place.
- Dictation dropped everything before a pause; segments are now accumulated and silent restarts detected.
- Speech playback in study mode was inaudible with the silent switch on; voice is chosen by language prefix.
- Study picker starved cards with a long "remember" streak; weights flattened, recent cards excluded, overdue cards forced.
- Card example sides swapped by the model are detected by language and put back in order.
- Study context line is centred on the word instead of cut off before it.

## [1.0.0] — 2026-09-23

First App Store release (build 3), approved 2026-09-28.

- System translation app (TranslationUIProvider): select text in Books, Safari or any app → Translate → the Gloss sheet with a streamed translation.
- One conversation thread shared by the app and the sheet: translations, Explain on a selected word, Discuss with a typed question; the model keeps the context of what you are reading.
- Dictionary card for single words: main translations, IPA, meanings by frequency with examples, nuances.
- Bring your own key: Anthropic, OpenAI, Google Gemini, DeepSeek, xAI; model lists fetched from each provider's API; keys stored in the device Keychain; no backend, no analytics.
- Photo translation with on-device text recognition (camera or library).
- Language pair setting (my language / foreign language), editable system prompt, history, share-sheet extension, English and Russian UI, onboarding with a button that opens the Default Apps settings.

[1.1.0]: https://github.com/ValentinLevitov/gloss/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ValentinLevitov/gloss/releases/tag/v1.0.0
