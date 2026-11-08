# Kai

Public source snapshot and unsigned SideStore IPA builds. The app contains no personal chats, imported user cards, API keys or login tokens. Standard public GitHub Actions runners build and test the app. Release filenames include the version and build number.

Formerly Faden. The app keeps the same bundle ID and data location for existing installations.

Private iPhone character chat for SideStore. Native SwiftUI, a public character catalogue, offline preparation of original public artwork, imported character cards, branching conversations, writing-style memory, interchangeable cloud providers, and optional on-device generation.

On first launch, the app prepares up to 60 popular public Chub cards. Metadata appears before definition downloads, original image caching and cached German translation with Apple on-device. Users can prepare 24, 60 or 120 cards and cancel without losing completed work. Legacy example cards are hidden from discovery while preserving old conversations. Public definitions and artwork are fetched on the user's device and are not redistributed in this repository.

Reusable personas and scenarios customize the start of each conversation. Private groups support up to four characters with manual or automatic speaker selection and sequential all-participant rounds. Every response is attributed to its speaker and shares the current branch's context.

Chats use the primary card artwork as their backdrop, independently of the persisted light/dark menu setting. Unsent drafts survive navigation, backgrounding and relaunch. User thoughts, quoted speech and narrative context receive separate prompt labels. Ensemble cards are detected and played as multiple voices from one card; multi-card groups remain available. Genre, card-type and favorite filters complement popularity-based online discovery and the conversation history list.

The fixed bundle identifier is `dev.r0bby97.faden`. A fresh installation starts with no previous local conversations. To preserve existing data when updating, retain this identifier and the same signing account. Deleting the app removes its local conversations and downloads.

## Delivery

The macOS GitHub Actions workflow runs core tests, compiles the device app, and packages an unsigned `Kai.ipa`. SideStore supplies the user's signature. No Apple credentials belong in this repository or in CI.

## Privacy

Chats, imported cards, memories, and style settings are stored in the app's protected local storage. Provider credentials are kept in the iOS Keychain and excluded from backups. Cloud generation sends the selected conversation context to the selected provider. Character browsing contacts the public catalogue. Local generation downloads model weights once and subsequently runs on the device.

## Design

Kai is a private place to continue character-driven stories. Its interface combines restrained native Liquid Glass navigation with compact character rows, short descriptions, warm stone surfaces and a coral accent. Character artwork fills each chat independently of the menu theme. Glass is reserved for controls; message surfaces maintain readable contrast. The selected ivory-and-red mask is the app symbol.

Design guidance: [Unslop](https://github.com/heydamir/unslop), by Damir Sokolovsky, CC BY 4.0. Native accessibility, Dynamic Type, and iOS touch targets take precedence over desktop-oriented measurements in that guide.

Omegaverse discovery includes genre aliases and a second public source, JannyAI. Chub uses popularity order and JannyAI uses source relevance order. Public card-download restrictions are surfaced honestly, with an integrated normal website download path. Scroll arrows navigate long conversations without changing branches. Word-based response settings are backed by a whole-word streaming cap.


Occasional character insights add private thoughts or memories as branch-aware side records rather than dialogue. They can be disabled or spaced around 10/20 completed replies; optional requests reuse the last successful provider and never escalate to another account. Provider priorities have a native drag interface and direct enable switches to reserve ChatGPT for occasional use.


Named API presets cover OpenAI, Claude, Gemini, Grok and DeepSeek, alongside ChatGPT plan sharing, OpenRouter and local MLX. Presets use official endpoints, current authenticated model lists and explicit API billing controls. Chat subscriptions and API access are kept distinct.
