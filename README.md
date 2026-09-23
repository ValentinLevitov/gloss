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

## Layout

- `App/` — the app: main thread, settings, model picker, onboarding, cards, study mode, camera and dictation.
- `TranslationExtension/` — the system Translate sheet (`TranslationUIProvider`).
- `ShareExtension/` — share-sheet entry for apps without the system Translate item.
- `Shared/` — providers, prompt, conversation and card stores, shared views.
- `UITests/` — UI flows used to drive the simulator for screenshots.

Privacy policy and support: https://valentinlevitov.github.io/gloss-site/
