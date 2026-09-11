# phiOS — Parallel Tracks

**For:** Claude Code.
**Authority:** `phios-master-plan.md`. Operating rules: `phios-agent-brief.md` §2.
**Purpose:** work that does not depend on the state of any phiOS machine, and can therefore advance without waiting for a verification cycle.

---

## 1. What makes a track parallel

A track qualifies only if **all** of these hold:

1. It touches no host state. Nothing to install, enable, or reboot.
2. Its correctness can be established on the machine you run on — by building, by running tests, by reading a specification — not by looking at a screen on `zotac` or `razer`.
3. It has no ordering dependency on an unverified main-line step.
4. It produces something the main line will later consume, without forcing the main line to wait.

If a track stops satisfying any of these, it is no longer parallel. Move it to the main line and put it in the queue.

---

## 2. Rules that still apply

Everything in `phios-agent-brief.md` §2 applies here without exception. In particular:

- **One commit per unit of work**, with a `Track: P-NN` trailer instead of `Step:`.
- Parallel tracks live in their own repositories. They **do not** modify `phios-dotfiles` except to add a package row, and only when the main line has reached the step that consumes it.
- No secrets, no private hostnames, no IP addresses. The remote is public.
- No AUR, no manual builds, no new runtime dependency without asking.
- A parallel track never blocks the main line, and never unblocks itself by touching it.

**Tracking:** parallel tracks get their own table in `PROGRESS.md`, separate from the step table, with states `todo | in-progress | ready | merged`. `ready` means the work is complete and waiting for the main-line step that consumes it.

---

## 3. Tracks

### P-01 — `phi` domain library: tokens and OKLCH derivation

**Consumed by:** S-12 (`phi theme`), S-50 (final palette).
**Available from:** after S-10 (the `phi` repository exists).

Build the colour engine as a pure library with no I/O beyond reading the token files.

- Parse the `KEY=VALUE` token files. No YAML, no TOML, no dependency.
- Convert between sRGB hex and OKLCH, both directions, correctly — including the gamut-mapping decision for out-of-gamut results. State which mapping strategy you chose and why.
- Derive a full ramp from a small set of anchors, holding **perceptual lightness** uniform rather than RGB values.
- Contrast ratio computation (WCAG 2.x relative luminance), and a checker that reports every failing foreground/background pair against 4.5:1.
- Derive the 16-colour ANSI map from the semantic tokens, so terminal colours are generated rather than chosen.

**Verifiable here:** unit tests against published reference values for the colour conversions; a contrast test that must flag `#d3a0ac` on white (~2.2:1) as failing and on black (~9.4:1) as passing. If your implementation does not reproduce those two numbers, it is wrong.

**Deliverable:** library plus tests plus a short document stating the derivation rules, so the palette can be reasoned about instead of tweaked.

---

### P-02 — `phi query`: ranking and providers

**Consumed by:** S-33 (launcher).
**Available from:** after S-10.

The launcher's entire value is here; the surface is mechanical. Validate this in a terminal against `fzf` **before** any QML exists. Getting ranking wrong in a terminal costs nothing.

- Provider interface: each provider returns typed results asynchronously with its own latency. The orchestrator must never let a slow provider block typing.
- Result types: application, open window, shell command, calculation, file, web search, directory/project jump, system action, SSH host, library track.
- Frecency store: frequency plus recency per item, persisted. This is the difference between "works" and "is pleasant", and it is very little code.
- Ranking across heterogeneous types — the hard part. Single token that matches an application name outranks a file; a token with arguments is a command.
- Calculator: a fully local expression evaluator with unit conversion. No network, no dependency.
- Currency: a rates source that needs no API key, with a cache and a fallback to the last known value when offline.
- The "command" result type pushes a sub-view rather than executing. Tab on a keyword is an accelerator onto the same object (ADR 022) — not a second mechanism.

**Deferred, do not build:** dictionary and translation providers. They depend on the system translation backend, which is not yet decided.

**Ask before building:** whether password-vault entries are indexed (`Q-N09`). It is a security decision.

**Verifiable here:** a terminal harness that pipes `phi query` into `fzf` and a fixture set of queries with expected first results.

---

### P-03 — Φ identity assets and the Plymouth theme

**Consumed by:** S-53.
**Available from:** now.

- Vector Φ, `U+03A6`, in two variants: Role A monochrome (Tier 0) and Role B accent (Tier 1). Never the lowercase forms — Unicode has two (`φ U+03C6`, `ϕ U+03D5`) and fonts disagree on which renders as which.
- ASCII/Unicode variant for TUI headers, the `phi` help banner, the TTY banner, and the SSH banner.
- Plymouth theme of the `script` type, drawing the Role A mark and the LUKS passphrase prompt. Colours come from tokens at render time, not hardcoded.
- Offer, do not impose, the random-letters resolve on mark appearance: it is category C, it is a genuinely rare event, and it is thematically coherent with the unlock screen.

**Constraint:** the permitted contexts are a **closed list** — boot splash, TTY/login banner, about panel, bar agent segment. Never wallpaper, watermark, window icon, or launcher decoration. Do not invent a new use.

**Verifiable here:** render the SVG, inspect it, check the glyph renders in the candidate fonts. The Plymouth theme itself can only be verified on the machine — flag that clearly.

---

### P-04 — `phi` MCP server

**Consumed by:** S-73.
**Available from:** after S-10.

Tool 5 of `phios-agente.md` §7.1, and the **only growth point** for the A1 agent's capabilities.

- First version: **one read-only verb, no arguments**, sufficient to prove the connection. Resist adding more.
- Design the verb registration surface so that a future capability is a new verb, not an architectural change.
- Runs inside the containment; therefore it may not assume network, a session bus, or any path outside the mounts of `phios-agente.md` §4.3.

**Verifiable here:** protocol conformance against a local client. Containment behaviour cannot be verified here — that is S-70.

---

### P-05 — Provider brokering service

**Consumed by:** S-71.
**Available from:** after S-10.

- A `phi` verb, not a separate binary.
- Listens on loopback outside the containment; holds the key; adds it to the outbound request. Inside the containment no credential exists at all.
- **Must stream without buffering.** If it buffers, the incremental response is lost and the whole surface feels broken. This is the one implementation constraint the specification calls out explicitly.
- Natural place for consumption metering and a local rate limit. Build both; they cost little here and are expensive to retrofit.
- Fails closed: if the service is down, no agent works.

**Verifiable here:** a streaming test against a mock upstream that emits chunks with delays. The response must arrive incrementally.

---

### P-06 — `phi-notes`

**Consumed by:** S-80.
**Available from:** now, and it is the application the user most wants.

- Plain-text files: versionable, syncable, searchable with `fd` and `ripgrep`.
- **ADR 041, non-negotiable:** content and state physically separated from the first commit. The vault holds only the user's files. Index, search cache, open windows and workspace state live in `~/.local/state/<app>/`. Workspace state is machine-local by definition; syncing it is the most common cause of conflicts in synced note tools.
- Class A theming by construction: reads the tokens, reloads on change, no hardcoded values.
- Go, per ADR 016 — but see S-81: the language decision is reopened before the **second** TUI application, so keep domain logic strictly separate from the view layer.

**Ask before building:** the link schema, the folder convention, and attachment handling. These are the decisions that are expensive to change once notes exist.

**Substitutable meanwhile by:** Obsidian.

---

### P-07 — `phi-music` and `phi-media` clients

**Consumed by:** S-82, S-83.
**Available from:** after the internal API contract is settled (M6).

Both exist for criterion (c) of §10.1: glue between two own systems, which by definition does not exist off the shelf.

- `phi-music`: Navidrome streaming plus local download, **and a request to the server to add a track or album**.
- `phi-media`: Jellyfin browsing plus a request to the server to add a film, a series, or a URL — consistent with the server-side features.
- Local download is a **mirror of real files** in the library's folder structure, reusing `phi pin`. One mechanism for music and video. Not an opaque client cache: those die with the client and are unreadable by anything else.
- The offline client only **fetches**; cataloguing always happens on the server, because it needs metadata sources and therefore needs the network anyway (ADR 012). The client does not need the tagging stack.

**Substitutable meanwhile by:** `clamp` or the Navidrome web interface; the Jellyfin web interface.

**Do not start** until the API contract of §10.4 architettura exists. Building a client against an undesigned API is how both end up wrong.

---

### P-08 — Neovim integration with the design system

**Consumed by:** S-03 (migration), S-50 (final palette).
**Available from:** now.

- The colourscheme is **generated** from the tokens, never chosen from a theme library (`I-05`).
- Map highlight groups to tokens. Handle semantic colours consistently with the Tier 2 rules.
- Coherent with the terminal theme, so a colour is not defined twice.
- **Class B requirement:** Neovim must reload the colourscheme hot, on an external command, without restarting. Work out how to drive running instances and document it.

**Out of scope here:** the Neovim plugin budget of §16 architettura. That is a separate discipline (L0 native baseline first, then one plugin per demonstrated friction) and it is the user's, not yours.

---

## 4. Suggested order

If nothing else constrains you:

1. **P-01** — everything visual depends on it, and it is fully verifiable here.
2. **P-03** — no dependencies, and it unblocks the identity work whenever the main line reaches it.
3. **P-02** — the riskiest logic in the whole shell; the earlier it is validated in a terminal, the cheaper the mistakes.
4. **P-08** — small, and it removes a target from the migration step's critical path.
5. **P-06** — large, self-contained, and the application the user wants most.
6. **P-04**, **P-05** — after `phi` has a stable dispatcher.
7. **P-07** — last; it needs a contract that does not yet exist.
