# Kai

Public source snapshot and unsigned SideStore IPA builds. The app contains no personal chats, imported user cards, API keys or login tokens. Standard public GitHub Actions runners build and test the app. Release filenames include the version and build number.

Formerly Faden. The app keeps the same bundle ID and data location for existing installations.

Private iPhone character chat for SideStore. Native SwiftUI, a public character catalogue, offline preparation of original public artwork, imported character cards, branching conversations, writing-style memory, interchangeable cloud providers, and optional on-device generation.

On first launch, the app prepares up to 60 popular public Chub cards. Metadata appears before definition downloads, original image caching and cached German translation with Apple on-device. Users can prepare 24, 60 or 120 cards and cancel without losing completed work. Legacy example cards are hidden from discovery while preserving old conversations. Public definitions and artwork are fetched on the user's device and are not redistributed in this repository.

Reusable personas and scenarios customize the start of each conversation. Private groups support up to four characters with manual or automatic speaker selection and sequential all-participant rounds. Every response is attributed to its speaker and shares the current branch's context.

Chats use the primary card artwork as their backdrop, independently of the persisted light/dark menu setting. Unsent drafts survive navigation, backgrounding and relaunch. Private user thoughts between asterisks remain in the local transcript and are omitted from inference requests, retrieval, style examples and linked memories; quoted speech and visible narrative remain distinct. Ensemble cards are detected and played as multiple voices from one card; multi-card groups remain available. Genre, card-type and favorite filters complement popularity-based online discovery and the conversation history list.

The fixed bundle identifier is `dev.r0bby97.faden`. A fresh installation starts with no previous local conversations. To preserve existing data when updating, retain this identifier and the same signing account. Deleting the app removes its local conversations and downloads.

## Delivery

The macOS GitHub Actions workflow runs core tests, compiles the device app, and packages an unsigned `Kai.ipa`. SideStore supplies the user's signature. No Apple credentials belong in this repository or in CI.

## Privacy

Chats, imported cards, memories, and style settings are stored in the app's protected local storage. Provider credentials are kept in the iOS Keychain and excluded from backups. Cloud generation sends the selected conversation context to the selected provider. Character browsing contacts the public catalogue. Local generation downloads model weights once and subsequently runs on the device.

## Design

Kai is a private place to continue character-driven stories. Its interface combines restrained native Liquid Glass navigation with compact character rows, short descriptions, warm stone surfaces and a coral accent. Character artwork fills each chat independently of the menu theme. Glass is reserved for controls; message surfaces maintain readable contrast. The selected ivory-and-red mask is the app symbol.

Design guidance: [Unslop](https://github.com/heydamir/unslop), by Damir Sokolovsky, CC BY 4.0. Native accessibility, Dynamic Type, and iOS touch targets take precedence over desktop-oriented measurements in that guide.

Online discovery opens by default and includes All, Cardex and Chub, with independent pagination and partial results. Gender and alphabetically ordered genre filters combine independently; favorites and other criteria have their own filter sheet. Cardex supports direct public exports and original archived artwork, including Omegaverse, Guideverse and BDSM searches. JannyAI has been removed from active discovery at the user's request; existing complete imports remain usable. Structured card properties display as labeled sections and lists. Tapping a chat's profile opens its card without leaving the conversation. Scroll controls and a single layout-aware bottom anchor support long streaming replies. Word-based response settings retain a whole-word streaming cap.


Occasional character insights add private thoughts or memories as branch-aware side records rather than dialogue. They can be disabled or spaced around 10/20 completed replies; optional requests reuse the last successful provider and never escalate to another account. Provider priorities have a native drag interface and direct enable switches to reserve ChatGPT for occasional use.


Named API presets cover OpenAI, Claude, Gemini, Grok, DeepSeek, Arli, NanoGPT and Venice, alongside AI Horde, ChatGPT plan sharing, OpenRouter and local MLX. Presets use official endpoints, current authenticated model lists and explicit API billing controls. Chat subscriptions and API access are kept distinct.

AI Horde uses native asynchronous chat with anonymous access, compatible NSFW workers, preserved system context, bounded waiting and cancellation cleanup. The provider order shows separate erotic-content and fictional-violence guidance with sources. Arli offers a limited free test; NanoGPT and Venice are optional paid API connections. Research and limits are documented in [FreeRoleplayModels.md](Docs/FreeRoleplayModels.md), and validation in [Validation-RoleplayProviders.md](Docs/Validation-RoleplayProviders.md).

[Download Kai 1.6.0 build 1008 for SideStore](https://github.com/r0bby97/kai-ios-build/releases/download/build-1008/Kai-1.6.0-b1008.ipa). The complete public CI run passed 92 core tests, 16 iOS service tests and 18 UI tests before creating the IPA; GitHub reports zero billable macOS minutes. The downloaded device binary and archive were verified. See [build validation and remaining device/account checks](Docs/Validation-1008.md).


The 1.7 fixes are documented in [TranslationFix.md](Docs/TranslationFix.md) and [ConversationFixes.md](Docs/ConversationFixes.md). Before the next IPA, all native service and UI tests run on the public iPhone simulator. This includes a second turn with an actual backend switch, card inspection with a preserved draft and repeated long streamed replies with the keyboard open. Real Apple translation speed and personal-account model acceptance require an iPhone check.
