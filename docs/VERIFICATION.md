# Features to be verifiedw

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.



---

## Yazi: token-driven colours for folder icons, non-VSC Development icon, new Games icon, hover off accent

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** 09a4bdb yazi: replace VSC/hardcoded folder icons and colours with design tokens
- **Original TODO:** "in yazi config replace the Development icon with one that is not VSC and the \"Games\" folder with a non default one. Also apply a different color for folders and subdirectories that are not part of $HOME. Finally reconsider the coloring to match the system palette: it shouldn't use accent for common elements like the selection highlight, as accent is for the details, and it uses a blue (it might be the info color) which makes no sense, it uses green for folders like Documents/Videos/Pictures/Downloads/Development, etc."

### What was asked
Four things in `yazi`'s theme: (1) the "Development" folder's icon looks like the VS Code logo, replace it; (2) the "Games" folder has no distinctive icon, give it one; (3) folders/subdirectories outside `$HOME` should look visually different from ones inside it; (4) the overall colouring doesn't track the system palette — the constant row-hover highlight uses accent (which should be reserved for real "details"), and several common personal folders render in a colour ("blue"/"green", depending on how it reads) that has no relationship to the design tokens.

### What was done
`profiles/base/templates/.config/yazi/theme.toml.tmpl` had no `[icon]` section at all — every folder icon and colour the user was seeing came straight from yazi's own built-in preset (`yazi-config/preset/theme-dark.toml`, pulled from upstream and read directly). Confirmed there: `Desktop`, `Development`, `Documents`, `Downloads`, `Library`, `Movies`, `Music`, `Pictures`, `Public`, `Videos` are ALL hardcoded to the literal `#00bcd4` — a colour this repo's `design/tokens.*.sh` does not define anywhere — and `Development`'s glyph is, byte for byte, `nf-dev-visualstudio` (the actual VS Code logo). `Games` has no entry in the preset at all, so it fell back to the plain generic-folder icon.

Added `[icon] prepend_dirs = [...]` (yazi's own documented merge semantics: `prepend_*` extends the built-in set by exact `name` match rather than replacing it, so `.config`/`.git`/etc — not part of this complaint — are untouched). `Development` now uses `fa-code` (U+F121, a generic "`</>`" glyph, no editor or publisher branding); `Games` is new, `fa-gamepad` (U+F11B). Every other folder in that list keeps its exact original glyph, recoloured to `${PHI_FG_2}` ("secondary text/comments" per `design/tokens.dark.sh`) — one coherent, deliberate value shared by the whole "ordinary personal folder" cluster instead of one arbitrary hardcoded one. Both new codepoints were checked against `profiles/desktop/templates/.config/kitty/fonts.conf.tmpl`'s own declared `symbol_map` ranges for `PHI_FONT_SYMBOL` (U+ED00-U+F2FF covers both) — the same font every other yazi glyph here already depends on, not an unverified new range.

`[mgr].hovered` (the row under the cursor — repainted constantly while browsing, not an occasional/deliberate action) moved from `${PHI_ACCENT}` to `${PHI_FG_0}` on `${PHI_BG_2}` — `design/tokens.dark.sh`'s own comment defines accent as "One role and one only: active state, focus, primary interactivity," which an ambient per-row highlight isn't. `marker_selected`/`count_selected` (the deliberate, Space-triggered multi-select) were deliberately left on accent — that IS "active state ... primary interactivity" by the same definition, and wasn't part of the complaint.

Added `prepend_globs` (yazi's `globs` rules match a folder's *full path*, confirmed against `yazi-config/src/pattern.rs`, unlike `dirs` which matches only the basename) for `/mnt` and `/srv` — the actual documented non-home storage on this project's own machines (`PROGRESS.md` §1: zotac's second disk at `/mnt/bulk`, mini's `/srv` volume) — coloured `${PHI_INFO}`, a deliberate and different use of that token from the "makes no sense" complaint above: not decoration on an everyday folder, but `design/tokens.dark.sh`'s own stated Tier-2 rule ("on threshold or state only") applied as intended — crossing outside `$HOME` onto a different volume is exactly that kind of state.

Verified by actually rendering the template: sourced `design/tokens.common.sh` + both variant files and ran the identical `envsubst` call `bin/lib/tokens.sh`'s `phios_render_template` uses, for dark AND light, then parsed both outputs with Python's `tomllib` — no leftover `${...}` in either, both parse as valid TOML, and the resolved `[icon]`/`[mgr]` values are exactly what was intended (confirmed every glyph's codepoint individually, not just that the file parses).

### Honest assessment
<span style="color:red">**NOT DONE (partially):**</span> "apply a different color for folders and subdirectories that are not part of $HOME" was implemented narrowly, not generally. yazi's `Pattern` does no `~`/`$HOME` expansion (confirmed against its own source), and this repo's template renderer deliberately leaves a literal `$HOME` untouched in any template (`bin/lib/tokens.sh`'s own stated reason: so a real `$PATH`/`$HOME` reference inside someone's OTHER config survives) — so there is no portable way to write a true "anything outside $HOME" rule in this shared, per-host-agnostic `profiles/base/` template without hardcoding a specific user's absolute home path, which would break for any other user or a differently-named account. Scoped instead to the two non-home storage locations this project actually documents and uses (`/mnt`, `/srv`) — real coverage for the real cases, not a general solution for an arbitrary future mount point elsewhere.

Everything else is clean and directly verified: not merely "should parse" but rendered through the real templating mechanism for both variants and checked with an actual TOML parser, plus every replaced icon codepoint checked individually against both the upstream default (for the ones just recoloured) and the declared font coverage (for the two new ones). Not verified visually on hardware — `AGENTS.md`'s own machines-off-limits rule — but this is the rare style task that could be verified structurally rather than only by eye, which was done as far as it goes.

One thing worth confirming and one worth flagging, both found by reading yazi's actual Rust source (downloaded the full repo tarball, not just its docs) after the fact: (1) `prepend_dirs` genuinely does override same-named entries in yazi's built-in preset, not merely sit alongside them unused — `yazi-config/src/theme/icon.rs`'s own merge builds the final `HashMap` as `append_dirs.chain(dirs).chain(prepend_dirs).collect()`, and a `HashMap::collect()` keeps the LAST value inserted for a duplicate key, so `prepend_dirs` (chained last) wins; `prepend_globs` is separately confirmed to go to the FRONT of an ordered `Vec` that a plain `.find()` scans front-to-back (`yazi-config/src/theme/icon_globs.rs`), so it's checked before the (in this case empty) built-in globs list too. Neither was a given from the TOML-parsing check alone, and this closes that gap. (2) `[filetype] rules = [{ url = "*/", fg = "${PHI_ACCENT}", bold = true }]` was left untouched — every directory's NAME (as opposed to its icon, which this fix did recolour) still renders in accent, including the personal folders now icon-recoloured to fg-2. That will show as a grey icon next to a pink/accent name on those specific rows. Left alone deliberately: the user's own complaint named specific folders (Documents/Videos/Pictures/Downloads/Development) that only the per-name `dirs` icon rule could explain — the blanket `*/` rule colours literally every directory's name the same way regardless of which one it is, so it doesn't match what was actually described, and changing it would be a much bigger, unrequested visual change (every folder name in every yazi view, not just these ones). Flagging it here so it can be judged from the actual screenshot rather than landing as an unnoticed side effect.

### How to test it
1. Run `bin/phios-install` (or wait for the next routine run) on `razer`, `zotac`, or `mini` to re-render `~/.config/yazi/theme.toml` from this template.
2. Open `yazi` and navigate to `$HOME`. Expected: Documents/Downloads/Pictures/Videos/Music/Movies/Desktop/Library/Public/Development all show in a muted grey tone (not the old bright blue), each keeping its previous icon shape except Development (now a plain "`</>`" code glyph, not the VS Code logo) and a new "Games" folder if one exists (now a gamepad glyph instead of the generic folder icon).
3. Move the cursor up/down through a directory listing. Expected: the highlighted row now shows a neutral grey background with normal-tone bold text, not the pink/accent background it used before.
4. Select a file with Space. Expected: unchanged — still the accent-coloured marker, distinct from the plain cursor-row highlight in step 3.
5. Navigate into `/mnt` (zotac) or `/srv` (mini) and any subdirectory under it. Expected: those folders render in a bluish-slate tone (the info token), visually distinct from both the accent selection marker and the muted grey personal-folder colour from step 2.

---

## Auto-start the phi agent a1 service when the agent panel opens

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** a12ea1f agent: auto-start the a1 service on panel open, 2ea457a merge: auto-start the a1 service on panel open
- **Original TODO:** "phi agent should run automatically as the panel is opened for the first time (or on startup). It should not waste resources when not used"

### What was asked
Today the a1 agent service (`phi-agent-a1.service`) only starts when the user manually flips a toggle in Settings or clicks "Start service" in the agent panel itself. The ask: start it automatically, either on the panel's first open or at shell startup, without wasting resources when the panel is never used.

### What was done
Picked "on panel open," not "on startup": starting at shell startup would run the (potentially heavy, opencode-backed) agent service on every boot even for a session that never opens the panel, which directly conflicts with the "should not waste resources when not used" half of the same request. Nothing in `Component.onCompleted` was touched — it still only reads health, never activates anything.

In `phi-shell/Services/Agent.qml`, added a `Connections` block watching `Services.AgentPanel.shown` (the existing singleton that owns the panel's open/closed state, already read by `Panels/AgentPanel.qml`). On every transition to shown, if the service isn't currently available, it calls the existing `setActivated(true)` (the same function the manual "Start service" button already uses — no new activation path, just an automatic trigger for the existing one).

This fires on every open where the service happens to be down, not only the literal first one — which was a deliberate choice, not an oversight: it means the same code also recovers the service automatically if it dies while the panel is closed, which reads as "it just works" rather than a one-shot convenience that stops helping after the first session. The manual "Start service" button in `Panels/tabs/agent/Chat.qml` was left in place as a fallback for whatever this doesn't catch (e.g. the service failing to come up at all).

Added a new `healthChecked` boolean (false until the first health-check result ever lands) and gated the auto-start on it, not just on `available` being false. Without that gate, a panel opened in the narrow window right after shell startup — before the first health check has returned — would read `available: false` (its declared default, indistinguishable from "confirmed down") and could fire an unnecessary `systemctl start` against a service that might already be running from a previous session. This mattered enough to fix before landing: `docs/TODO.md` has its own still-open, unexplained "ai agent a1 always fails starting" report with a second-start/address-in-use symptom, and adding a new code path that could issue a redundant start under a timing condition felt like the wrong thing to introduce onto an already-flaky service, even though a systemd `start` against an already-running unit is normally a harmless no-op.

### Honest assessment
- **Untested against a real compositor or the actual service** — `phi-shell/CLAUDE.md`: "You cannot run this." The `Connections`/`onShownChanged` mechanism, the singleton cross-reference (`Services/Agent.qml` importing `qs.Services` to reach `Services.AgentPanel` — precedented, `Services/Chroma.qml` already does the same to reach `Services.PowerBridge`), and the `healthChecked` gate are all verified by reading, not by seeing it run.
- This does not touch or explain the separate, still-open "ai agent a1 always fails starting" TODO entry — that investigation stands as it was, and this change was deliberately built not to make it worse (the `healthChecked` gate exists specifically because of that open report).
- "Should not waste resources when not used" is satisfied for the heavy agent service itself (never started unless the panel is actually opened), but there's a pre-existing, unrelated lightweight health-check poll (`curl` against `/global/health` every 5 seconds, always running regardless of whether the panel is open) that this change did not touch and was out of scope for this entry.

### How to test it
1. On razer or zotac, pull the updated `phi-shell` `dev` branch (Quickshell hot-reloads `.qml` changes on save; a fresh `qs -p ~/.config/quickshell/phi` restart also works if needed).
2. Make sure `phi-agent-a1.service` is currently stopped (`systemctl --user stop phi-agent-a1.service`, or check `systemctl --user status phi-agent-a1.service`).
3. Open the agent panel (Super+P, or the bar's Φ segment, or Settings › AI Agent › "Open agent panel"). Do NOT click "Start service" manually.
4. Within a couple of seconds, the panel should transition from the "Agent offline" state to the normal chat/dashboard view on its own, without any manual click — confirm with `systemctl --user status phi-agent-a1.service` that it's now active.
5. Stop the service again, close the panel, then reopen it — it should auto-start again each time (this is deliberate, not a bug — see "What was done").
6. With the service already running, close and reopen the panel a few times in quick succession — `systemctl --user status phi-agent-a1.service` should show no repeated restart activity (no flapping), since the auto-start only fires when `available` is actually false.

---
