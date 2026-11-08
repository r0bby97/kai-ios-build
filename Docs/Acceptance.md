# Acceptance criteria

- One stable bundle ID; no app extensions or paid signing entitlements required.
- Public Chub previews appear before translation or image preparation; users can prepare 24/60/120 original cards offline, with progress and cancellation. Legacy example chats remain available while examples are hidden from discovery.
- Import Character Card V1/V2/V3 JSON and PNG metadata; create and edit original cards.
- Automatically populate the initial main library with full public Chub cards, with bounded concurrent downloads.
- Reusable user personas, scene templates, editable/alternate greetings, and favorites.
- Private groups of two to four characters with named messages, manual/automatic speaker selection and sequential all-participant turns using the latest shared history.
- Streaming chat with cancellation, retry, response regeneration, editing, copy, and branch-from-message or reset-to-start.
- Rewinding also restores memory and writing-style observations to the visible branch, without future information leaking backwards.
- Writing preferences are visible and editable; examples come only from the current branch and explicit global preferences.
- Multiple compatible cloud connections, free-only spending mode, ordered model fallback, account-wide errors surfaced honestly, no automatic account creation or quota evasion.
- Official ChatGPT plan authorization only if supported by the documented flow; no consumer session-token scraping.
- Optional local MLX engine; no claims of tested iPhone performance without a physical device test.
- Export/import versioned backups excluding secrets; atomic persistence and corrupt-file recovery.
- Core regression tests for branch isolation, persistence models, prompt budgeting, card parsing, free-mode provider selection, and SSE framing.
- CI must pass before the IPA is described as built. Physical installation and network access from the user's iPhone remain device validation steps.
- Per-chat unsent drafts survive card navigation, backgrounding and relaunch; sending clears only the submitted draft.
- Menu appearance persists, defaults to dark, and does not replace the card artwork behind chats.
- Thought/speech/context classification survives nested quotes, unfinished thoughts and historical prompt retrieval.
- A single multi-person card is recognized and prompted as an ensemble, with manual correction and no fabricated separate card requests.
- Local and online discovery include genre, card-type and favorite filters with transparent pagination scope and no source-language restriction.

- Kai display name and icon coexist with the existing bundle ID and storage directory for updates.
- Omegaverse is selectable for local and remote discovery, with A/B/O and Omega-Verse aliases.
- JannyAI's public search and pagination are integrated without fabricating unavailable definitions or popularity scores.
- The normal browser download path supports PNG/JSON import and respects source access restrictions.
- Chat scroll arrows jump to both ends without rewinding or editing story history.
- Word-based response limits survive settings migration and enforce whole-word stream termination.

- Discovery combines native glass controls with character description rows, accessible filters and unchanged source order.
- Long biographies cannot displace character personality or the rules reserving the user's speech, thoughts, feelings, choices and actions to the user.
- No extra generated portraits are substituted for card images.

- Optional character thoughts/memories are private side records, branch-aware, persisted and bounded in length; failed optional requests do not spend on a fallback provider.
- Native draggable provider priority and direct enable switches persist; disabled ChatGPT is skipped.
- The adult catalogue setting is shared across settings/discovery and does not imply a model-policy override.

- Five named API presets expose live model discovery and clear account/billing distinctions, without treating premium subscriptions as universally interchangeable.
- Native Claude SSE filters model reasoning; OpenAI API output limits are separate from ChatGPT plan-sharing limits.
- API presets require keys and stay disabled/excluded by default spending protection until configured.

1.5 regression coverage: immediate preview merge without replacing definitions or edits; legacy examples hidden without losing stories; rolling completion before slow cards, per-card failures and cancellation; public metadata and artwork while translation is deliberately held; production empty-library state; headerless official ChatGPT stream with actual completion; OpenRouter reasoning-only/truncated streams, safe errors and structured response text. Device checks still required: local MLX load-time text test and character response, ChatGPT plan response, OpenRouter free response, missing Apple language-pack setup.

Hosted service tests exercise the real byte-stream transport with controlled responses; a full UI send/fallback/persistence test verifies application usage without consuming account quota. Release binaries exclude DEBUG inference fixtures.

1.6 regression coverage: final Responses snapshot and JSON text extraction; safe HTTP diagnostics; protected translation variables; immediate native language-setup requirement and blocked untranslated greeting; Guideverse matching and query; restoration of a reply when a streaming callback fails to persist it. The complete application suite runs in the optimized Release simulator, including stream/persistence and language setup. Janny website verification and local MLX hardware remain real-device checks; there is no claim of universally unattended Janny exports.
