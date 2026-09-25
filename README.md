# Gloss — AI translator for reading

Gloss is an iOS translator that becomes the system translation app: select text in Books, Safari or any other app, tap **Translate**, and the translation streams in from the AI model you choose — with your own API key.

- **Translate in context.** Every fragment goes into one thread, so the model keeps the names, terms and style of what you are reading.
- **Explain and discuss.** Select a word in the original or the translation → *Explain*, or *Discuss* to ask your own question.
- **Dictionary cards** for single words: translations, IPA, meanings by frequency, nuances.
- **Flashcards & study mode.** *Add to cards* builds a card in the dictionary form (singular, infinitive) with forms, examples and CEFR level; words with cards are highlighted in every translation. Swipe through cards to learn them.
- **Bring your own key.** Anthropic, OpenAI, Google Gemini, DeepSeek or xAI. Model lists are fetched live. Keys stay in the device Keychain; text goes straight to the provider. No backend, no analytics.
- **Photo translation** (on-device OCR), dictation, editable prompt, any language pair.

## Building

Requires Xcode 27, iOS 18.4+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open Translator.xcodeproj
```

Set your `DEVELOPMENT_TEAM` in `project.yml`. The default-translation-app entitlement (`com.apple.developer.translation-app`) requires a paid Apple Developer Program membership; a Personal Team can build everything else.

## Tests

```sh
xcodebuild -project Translator.xcodeproj -scheme Translator -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan CI test
```

- `UnitTests/` — pure logic: conversation budget and prompt shape, model-list parsing, flashcard JSON and study
  scheduling, dictation and Books-text heuristics, and the three provider stream parsers against canned SSE
  bodies served by a `URLProtocol` stub (no network, no real keys).
- `UITests/SmokeTests` — launches the app on a simulator with no key and expects the Setup screen.
- `UITests/` also holds flows that drive the simulator or a device for App Store screenshots and the review
  demo recording (`Demo.xctestplan`); those are not part of CI.

CI runs the `CI` test plan on every push (`.github/workflows/ci.yml`).

## Layout

- `App/` — the app: main thread, settings, model picker, onboarding, cards, study mode, camera and dictation.
- `TranslationExtension/` — the system Translate sheet (`TranslationUIProvider`).
- `ShareExtension/` — share-sheet entry for apps without the system Translate item.
- `Shared/` — providers, prompt, conversation and card stores, shared views.
- `UITests/` — UI flows used to drive the simulator for screenshots.

Privacy policy and support: https://valentinlevitov.github.io/gloss-site/
