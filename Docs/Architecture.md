# Architecture

## Conversation state

`Story.messages` is an append-only parent-linked message graph. `headID` selects the current path. Rewind saves the old head as a branch; edit creates a replacement message at the original parent. Derived prompts, semantic keyword retrieval, style examples and pinned memories are restricted to the selected path. There is no shared opaque model session that could retain future history after a rewind. Each local response starts a new MLX session hydrated with the selected history.

Group stories retain an ordered participant list and each assistant message's speaker ID. Automatic turns derive the next speaker from the selected path; explicit turns and all-participant rounds use the same validated participant list. Group responses run sequentially so later speakers see earlier group contributions. User personas and scenes are value snapshots, keeping conversations stable when templates change. Optional message/story fields and defaulted archive fields preserve compatibility with older archives.

An ensemble card remains a single card and generation request with multiple named voices. Conservative title/tag/definition detection is separate from multi-card turn scheduling; manual card overrides can correct it. Source cast evidence survives translation and card overrides round-trip through a namespaced Character Card extension. Older stories gain cast metadata on load.

Draft text belongs to the story, outside the message graph. Input changes immediately update observable archive state, with a cancellable 400 ms disk-save debounce. Chat dismissal and inactive/background scene transitions also flush the archive. Sending clears the draft in the same mutation that appends the user message. Rewind and regeneration leave unsubmitted text intact.

User message parsing labels quoted speech, private starred thoughts and unquoted narrative context. Thought spans take precedence over nested quotes and incomplete thoughts remain private. These labels are retained when prompts retrieve older user messages or style examples. Models receive narrator context with explicit perspective rules; this is not a separate model that cannot access the thoughts and cannot guarantee perfect fictional knowledge isolation.

Menu appearance is persisted independently of chat appearance. Chats always show the primary card's actual artwork with fixed dark readability overlays. Discovery shares genre aliases and card-type detection across local and online results; catalogue genre queries use Chub's topic parameter and retain popularity ordering. Type/favorite filters operate on loaded pages and the UI explains this scope.

## Memory

Persistent storage retains the entire graph. Generation uses a conservative byte-based context budget, character data, relevant lorebook entries, user-authored preferences, anchored pinned memories, recent dialogue, and keyword-ranked older excerpts. This is deterministic retrieval rather than an unverified claim of perfect long-term model memory. Style learning describes message length, action/dialogue formatting, and a bounded number of examples; users can disable it and override preferences.

## Providers

Connections contain no credentials. Ordered fallback tries available models and then the next connection. Authentication, payment and account rate-limit failures skip the rest of a connection. Fallback cannot append a second model's output to a partially streamed answer. OpenRouter free mode uses only explicitly free IDs. Custom unpriced endpoints require leaving free-only mode. No account generation, balance bypass, consumer session scraping or paid fallback is implemented.

## ChatGPT authorization

The documented dynamic public-client flow uses a stable host ID, system-browser authorization, a loopback-only callback listener, fresh state/nonce/PKCE, an issued client ID, validated RSA JWT signatures from the official JWKS, issuer/audience/expiry checks and granted-scope checks. Access, ID and rotating refresh tokens are atomically stored in the Keychain. Refreshes for an account are serialized. Disconnect attempts session revocation and reports an unconfirmed remote revocation. Credentials can be sent only to the fixed official endpoints; authenticated HTTP redirects are disabled.

## Storage and import

The versioned JSON archive is written atomically under protected Application Support. A validated previous copy and any damaged file are kept for recovery. Imports validate graph IDs and cycles. Backups omit secrets and merge without overwriting existing conversations. Imported connection definitions start disabled, and importing cannot disable spending protection. PNG imports extract bounded Character Card tEXt/iTXt metadata; compressed metadata and CHARX archives are not supported in this release.

## Language

German is the UI and response language. Catalogue selection and ordering use popularity, never source language. Apple Translation translates card text on device, grouped by recognized source language and with bounded batches. A serialized, cancellation-aware queue attaches the translation session to the requesting SwiftUI surface. Templates are split so variables survive byte-for-byte; long text is chunked at whitespace boundaries. Missing or declined language packs leave the card cached and explicitly pending rather than filtering it out. Users may retry or explicitly opt to use the original. Apple Translation execution requires a physical device; simulator tests cover UI, catalogue access, templates and pending states without pretending to validate on-device translation quality.

## Delivery

The XcodeGen specification references pinned MLX, Hugging Face and tokenizer releases. GitHub Actions runs the portable tests, builds for physical iOS devices on macOS, and packages the standard `Payload/Faden.app` layout without signing credentials. SideStore re-signs the app. Bundle ID and data schema are stable across updates. No private conversations or provider keys are bundled.

## Additional catalogue and word limits

JannyAI uses its public, read-only frontend search credential against its search index. This is not a user credential, inference account or private-definition access. The client preserves pagination and the source's relevance order instead of manufacturing popularity scores. Complete cards must come from permitted PNG downloads. A WKWebView/WKDownload flow supports user-initiated site downloads when direct API requests are blocked; no account-session extraction or hidden-definition recovery is implemented. Website changes or key rotation can require adapter maintenance.

Source changes cancel and invalidate stale searches. Downloaded and translated definitions are reused from the local library. Omegaverse genre aliases are matched without treating words such as “Kaboodle” as “ABO”.

The optional responseWords preference preserves decoding of older backups. A word cap is separate from the conservative provider token budget. A shared streaming limiter retains split words across chunks and stops only when a subsequent word starts, without cutting a word. Both the cloud byte stream and local token stream terminate normally at the cap. The internal module, bundle ID and storage directory retain their original Faden names so the Kai rename does not orphan user data.

ChatGPT plan requests omit `max_output_tokens` and other unsupported SIWC preview fields. Provider payload construction is regression-tested independently of iOS. Word limits are enforced by the shared streaming limiter, with the system prompt asking the model to finish naturally before the cap. Official reference: https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations


The 1.3 interface uses native Liquid Glass for custom controls on iOS 26 and regular material on iOS 18–25. Reduce Transparency uses opaque surfaces. Native navigation and tab bars follow the system rendering. Discovery preserves source order: the first unfiltered library card is featured once, followed by description rows. Search/filter results use rows throughout. Pending translations display original preview text with an explicit status label until a German version is available. Character artwork remains independent of menu appearance; chat messages use stable dark contrast surfaces and glass is limited to navigation/composer/scroll controls.

Character personality and voice receive their own weighted material allocation before biography, scenario and examples. Long descriptions cannot consume the personality allowance. Each provider rebuilds the same perspective and user-agency instructions for each answer, including an untruncated final reminder; user style adaptation is limited to tempo/format and must preserve character voice. Regression tests cover long biographies at 2k, 4k and 8k contexts, both single and ensemble cards. These tests verify supplied context, not a guarantee about a provider's generated behavior. No newly generated character images are included in 1.3; imported card imagery continues to supply its chat background.


Character insights are optional Story side records anchored to completed assistant message IDs, not Message nodes. Active-branch filtering controls both display and private character context; a character never receives another card's private insights. Archive validation rejects orphaned or user-message anchors and unknown participants. Legacy optional fields decode without a schema reset. Stable FNV-derived jitter schedules a gap of 8–12 or 18–22 completed non-greeting replies. Attempt anchors space out unavailable or cancelled optional generations too.

An insight request is isolated from the normal transcript, uses bounded character material, and caps output at 80 words. It reuses only the successful reply's still-enabled connection/model. There is no cross-provider fallback for this optional work, and partial/cancelled asides are discarded without altering dialogue. Runtime API/model compliance still needs actual provider testing; automated tests verify scheduling, data isolation, prompts and UI using an explicitly named DEBUG-only fixture.

The provider ordering sheet uses native List reordering and immediate persistence. Direct enabled switches feed the existing permittedModels selection. Requests snapshot the provider ordering at answer start; optional insight work rechecks enablement. New-install defaults prefer free cloud and local models, with ChatGPT disabled last. Existing saved order/enablement is not migrated. The adult catalogue setting is shared between discovery and settings; it does not change model safeguards.


Additional provider presets lock the official endpoint and use API credentials, separate from ChatGPT SIWC account tokens. OpenAI API uses Responses with max_output_tokens; SIWC omits that unsupported field. Claude uses native Messages, x-api-key, anthropic-version and optional anthropic-workspace-id; its SSE decoder consumes text deltas and message_stop, ignores reasoning/signature deltas, and propagates stream errors. Model reasoning is never mistaken for fictional character insights. Saved greetings are preceded by a control user turn and continuation requests end with a user control turn rather than an unsupported assistant prefill.

Gemini uses its official OpenAI compatibility endpoint; Grok and DeepSeek use their official OpenAI-compatible text streams. Sampling parameters are omitted for broad model compatibility. API preset endpoints are validated before sending credentials, and SIWC host validation now covers both model listing and inference. New API presets are disabled, require a key, and are excluded by free-only mode. Account-specific free tiers or subscription credits are not inferred from an API key. Automated tests validate payloads, stream events, cost guards, endpoint metadata and setup UI; actual authorized inference needs the user's own credentials.

Protocol references: https://platform.claude.com/docs/en/api/overview ; https://ai.google.dev/gemini-api/docs/openai ; https://docs.x.ai/developers/quickstart ; https://api-docs.deepseek.com/ .

Genre selection uses a shared matched-geometry capsule in a native GlassEffectContainer on iOS 26, with glassEffectID/transition, and a solid fallback. Main tabs keep the system tab bar and add a short content entrance. Reduce Motion removes the added motion; Reduce Transparency replaces the glass selection with an opaque surface. CI optionally records only the offline library UI test on the same non-parallel simulator; this preview is test footage, not an AI mockup or production screen recording feature.

## Catalogue preparation (1.5)

Production starts with no synthetic cards. `Archive.libraryCharacters` hides legacy example IDs without deleting data referenced by old stories. Metadata pages publish immediately in source popularity order. `CataloguePreparation` uses a rolling bounded task group; slow cards and individual failures do not hold completed cards back. `CatalogueNetwork` stores validated original image bytes separately from the original source URL; exports omit device-local cached paths. Public-source requests use an isolated session with 12-second request and 25-second resource deadlines.

Translation is a separate store-owned task. Background translation checks installed Apple language pairs before scheduling work; missing packs never start an invisible download. Explicit setup owns the foreground translation host. Original text is visible until translation completes. Online result pages likewise publish before any preview translation.

`TextStreamPolicy` permits missing Content-Type only for the official ChatGPT direct route and still requires Responses completion. `TextStreamEvent` extracts only public response text, distinguishes truncation and provider errors, and excludes internal reasoning. Local MLX uses Qwen non-thinking templates and a short real load-time text test. Hardware execution cannot be validated by the Linux core suite or an iOS simulator.

## Inference integration tests

The iOS hosted service suite drives the actual URLSession byte-stream reader using fragmented URLProtocol fixtures: headerless official Responses, OpenRouter text, account-wide 429, HTML rejection, and reasoning-only or truncated responses. A DEBUG-only UI fixture then exercises send → account-wide failure → next provider → streamed reply → persistence across relaunch through AppStore and ChatView. These fixtures are excluded from the Release IPA and consume no external account quota; they do not substitute for device model or real account acceptance tests.

## Inference receipts and diagnostics (1.6)

Cloud and local backends return `InferenceResult` with independent response text and a metadata-only receipt. AppStore verifies its actual persisted assistant node rather than a captured Boolean across suspension. If a callback failed to persist output, the same engine result can restore the node with the word cap applied. Partial answers still prevent provider splicing. Final response snapshots and JSON responses are read from the original request, without issuing a paid retry.

`DiagnosticLog` retains 30 metadata-only attempts outside backups. Reports contain no prompt, response text, keys, raw upstream errors or credentials. A Release simulator suite with KAI_TESTING checks the complete optimized application path; production device Release excludes these fixtures.

Apple translation is local. iOS 26 uses TranslationSession(installedSource:target:) directly after a language-availability check; iOS 26.4 explicitly selects lowLatency. Missing pairs return a typed setup requirement immediately. Only the foreground setup queues a session that can request downloads; automatic catalogue work never downloads invisibly. CardTranslationBatch is the exact request/restoration plan used by the native session: variables stay out of translation requests, missing segments fail, and original boundary whitespace is restored. Successful translated cards persist in the archive. Central conversation creation waits before using the source greeting. Google translation was removed after its public endpoint returned HTTP 429 in the live CI probe.

Janny HTTP 403 is not interpreted as creator withdrawal. The normal public browser export path is opened automatically, with best-effort clicks only on ordinary export/PNG/JSON controls. No CAPTCHA, consent or access-control interaction is automated. Download URLs may contain their normal signed query; downloads contain no inference credentials and may follow CDN redirects.
