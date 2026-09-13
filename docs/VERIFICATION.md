# Features to be verifiedw

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.



---

## Super+M ends the session immediately, with no confirmation

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev, phios-dotfiles / dev
- **Commits:** phi-shell: a97d21e power: add a "power" IPC target that opens the popout pre-confirming, 05e29c5 merge: power confirm IPC target for Super+M — phios-dotfiles: ce65d83 hyprland: ask for confirmation on Super+M, add a no-confirm alternative, fb8e832 merge: Super+M confirmation + no-confirm alternative
- **Original TODO:** "SUPER+M to close hyprland is problematic: add a confirmation and an extra more complex binding for terminating without confirmation."
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
Super+M runs `hyprshutdown`/`hyprctl dispatch exit` the instant it's pressed — one modifier plus a common letter, with no confirm step, so a mistyped keypress can end the whole session. Asked for two things: Super+M itself should ask first, and a separate, harder-to-hit binding should still exist for ending the session immediately when that's genuinely wanted.

### What was done
Rather than build a new confirmation surface, this reuses the one the power bar-icon overlay already has: `Panels/BarPopout.qml` already renders a "Reboot now? This cannot be undone." style inline confirm step for Reboot/Shutdown, gated on a local `_confirmingAction` string. Added a `Services.BarPopout.openConfirm(key, action)` (phi-shell) that opens the popout at its existing anchor-less corner fallback and hands over a one-shot pending action — same set-once/consume-and-clear shape `Services/SettingsPanel.qml`'s `pendingSection`/`pendingReveal` already use for a caller with no button to anchor under. `Panels/BarPopout.qml` picks it up via a `Connections` block and a new `IpcHandler { target: "power" }` with one function, `confirmLogout()`.

`phios-dotfiles`' `hyprland.lua.tmpl`: Super+M now runs `qs -p ~/.config/quickshell/phi ipc call power confirmLogout` instead of the logout command directly, landing on the same "Log out now? This cannot be undone." confirm step the Reboot/Shutdown buttons already use. Super+Shift+M is the new "extra more complex binding" — still ends the session immediately, no confirmation, deliberately a letter-key double-modifier bind (matching the already-working Super+Shift+h/j/k/l/F/C binds already in this file) rather than the word-name-key pattern the still-open Super+Shift/Ctrl+arrow report involves.

**Scope is narrower than the entry's title, deliberately:** only the *keybind* path now confirms. The power overlay's own "Log out" button and the runner bar's "logout" system action still fire immediately — `Services/PowerActions.qml`'s `needsConfirm()` is untouched, still true only for reboot/shutdown. The report is specifically about an accidental key press, not about the button someone deliberately clicked after opening a menu, so this was read as the narrower, correct scope rather than making every logout path (button included) require a second click.

**Found and fixed a second, pre-existing bug while touching this line:** the old Super+M fallback command was `hyprctl dispatch 'hl.dsp.exit()'` — passing the literal string `"hl.dsp.exit()"` (Lua-binding call syntax) as a hyprctl dispatch argument, not Hyprland's real `exit` dispatcher. Replaced with `hyprctl dispatch exit`, the exact command `Services/PowerActions.qml`'s own `logout()` already runs. Not verified as broken on real hardware (no compositor here either), but confirmed suspect by reading `hyprctl`'s dispatch argument format — and left uncorrected, it would have made the new no-confirm Super+Shift+M bind a silent no-op on any machine without `hyprshutdown` installed, the one path with no confirm dialog to surface that failure.

### Honest assessment
Not verified on hardware — `phi-shell/CLAUDE.md`: "You cannot run this." The IPC plumbing mirrors an existing, working pattern (`SettingsPanel`'s pending-state handoff) closely enough to be confident in the QML side; the two `hyprland.lua` binds follow this file's own confirmed-working modifier/key-shape precedent (letter keys with a double modifier, not the broken word-name-key pattern).

Super+M now depends on `qs` (phi-shell) actually being alive to answer the IPC call — already true of the Lock keybind (same mechanism), but the failure mode here reads worse: a dead shell means Super+M does nothing at all, silently, for a keybind used routinely rather than "the screen didn't lock." Not something to route around (phi-shell is meant to always be running, ADR 072), just worth knowing if Super+M ever seems to stop working — check `pgrep -x qs` before assuming the bind itself broke.

The cheat sheet (Super+Shift+/) reads bind descriptions straight from `hyprctl binds -j` — both new binds got a `description` (the same reason every other `qs ipc call`-driven bind in this file has one), so they should show up there as "Log out (asks for confirmation)" and "Log out immediately, no confirmation" rather than an opaque entry. Not seen rendered.

Both logout commands are `command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit` — `hyprshutdown` is not in any profile's `packages.txt` (grepped all of them, no match) and isn't in `core`/`extra`/`multilib` regardless (rule 2 rules it out), so on all three machines the `command -v` check fails and `hyprctl dispatch exit` is the only branch that ever actually runs. Not a defect — the `||` fallback was clearly written for exactly this — just worth knowing that "step 5 ends the session" is testing `hyprctl dispatch exit`, not `hyprshutdown`, in case that command is ever added later and changes which branch runs.

Cosmetic, not functional: `openConfirm()` always opens at the anchor-less corner fallback (`_setAnchor(0, "right")`). If the power popout happened to already be open from clicking the left-isle power icon (anchored under that icon) and Super+M fires while it's open, the card will jump from under the icon to the top-right corner as it switches into the confirm step. Single frame, not incorrect, but don't mistake it for a bug if seen.

### How to test it
1. Update both checkouts: `phi-shell` at `~/.config/quickshell/phi` to `dev` (Quickshell hot-reloads the QML on save), and `phios-dotfiles` to `dev`.
2. Re-render the Hyprland config from the updated template and reload it — `phi theme set <your current variant, e.g. dark>` does both (it re-renders every `design/adapters.txt` row, including this one, and automatically runs that row's `hyprctl reload`); a plain `qs`/QML reload does NOT pick up this half of the change, since it's a Lua config file, not QML.
3. Press Super+M. Expected: the power popout opens (top-right corner, since no bar icon was clicked) directly on a "Log out now? This cannot be undone." confirm step with Confirm/Cancel buttons — the session does NOT end immediately. Click Cancel; confirm you're still logged in.
4. Press Super+M again and click "Log out" (or whatever the confirm button reads) this time. Expected: the session actually ends — confirms the IPC round-trip really reaches `PowerActions.perform("logout")`, not just that the confirm UI appears.
5. Log back in. Press Super+Shift+M. Expected: the session ends immediately, no popout, no confirm step.
6. Open the cheat sheet (Super+Shift+/). Expected: two distinct Super+M entries — one describing the confirm behaviour, one the immediate no-confirm behaviour — not a single stale "M" row or an opaque unlabelled one.
7. Unrelated to this entry but worth a glance while step 2 is fresh: click the power bar icon directly and click "Log out" from the button (not via a keybind). Expected: unchanged from before this change — ends the session immediately, no confirm step, since only the keybind path was scoped to require one.

---

## The calendar overlay doesn't close, or get closed by, the other status-bar overlays

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 405661e calendar: close the other bar overlays when it opens, not just the reverse, f8d81ee merge: calendar overlay exclusivity (close peers on open)
- **Original TODO:** "when the calendar overlay is opened other overlays don't close (should share the same behavior as the other, as it should use the same parent compoent), and opening other overlays don't closes the calendar. (as per overlays it's intended the panels that are opened from the icons in the status bar). The other way around, non calendar panels don't automatically close when calling the chat/notification panels, the settings or other shells"

### What was asked
The calendar card (opened from the bar clock) should behave like the other bar-icon overlays: opening it should close whichever of them is already open, and opening one of them should close the calendar — not just one direction. The closing sentence also flags that the other four don't close each other either.

### What was done
`Services/Calendar.qml` already had one direction: four `Connections` blocks (added by an earlier round, commit `ec1db11`, never signed off or removed from `docs/TODO.md`) close the calendar whenever `NotificationPanel`, `AgentPanel`, `SettingsPanel` or a `BarPopout` (volume/wifi/bluetooth/etc.) opens. The other direction didn't exist: opening the calendar left all four sitting open underneath it. Added an `onShownChanged` handler on `Calendar`'s own `shown` property that calls `.hide()` on all four the moment the calendar opens — the same peer set it already watches, just closing them instead of only reacting to them.

No feedback loop: each of the four Connections blocks only reacts when the *watched* property becomes true/non-empty (`if (Services.X.shown) root._closeIfOpen()`); calling `.hide()` on them sets it to false/empty, which those same conditions ignore.

<span style="color:red">**NOT DONE:**</span> the closing sentence's own complaint — that Notifications/AgentPanel/Settings/BarPopout don't close each other either (you can have the settings panel and the agent panel open at once, for instance) — was deliberately left alone. Fixing that is a real N-way exclusivity pass across four more files, not a mirror of one relationship this file already half-had; re-filed as its own bare `docs/TODO.md` entry rather than folding it into this one silently.

Did not attempt the parenthetical "should use the same parent compoent" — folding the calendar into `BarPopout`'s own `which` state machine so it's structurally one popout among many, rather than a second mechanism kept in sync by hand. That's a real architectural option but touches the calendar's positioning/anchoring, which needs to be seen rendered to get right; the behavioural fix above satisfies the literal complaint without that risk.

### Honest assessment
Not verified on hardware — `phi-shell/CLAUDE.md`: "You cannot run this." The change is a single property-change handler calling four `hide()` functions that already existed and are already called the same way elsewhere in this exact file's own Connections blocks, so the mechanism is not new, only its direction.

### How to test it
1. On `razer` or `zotac`, update `phi-shell`'s `dev` checkout at `~/.config/quickshell/phi` to this change (latest `dev`); Quickshell hot-reloads on save.
2. Open the notification panel (bar bell icon, or Super+N). With it open, click the bar clock to open the calendar. Expected: the notification panel closes as the calendar opens (previously: both stayed open, calendar on top).
3. With the calendar open, click a bar popout icon (volume, wifi, bluetooth, …). Expected: unchanged from before — the calendar already closed in this direction (`ec1db11`). Confirm it still does.
4. With a bar popout open (e.g. volume), click the bar clock to open the calendar. Expected (this is the new half): the volume popout closes as the calendar opens.
5. Repeat step 2/4 with the agent panel (Super+P) and the settings panel (Super+S) in place of the notification panel — same expected result: each closes when the calendar opens.
6. Not part of this fix, for awareness: open the settings panel, then open the agent panel. Expected today (unchanged, tracked as its own open item): both stay open at once — only the calendar participates in this exclusivity so far.

---

## Power button is not first in the bar, and its overlay buttons look broken

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 27104e6 bar: move the power module to the front of the left island, 006eadb settings: disable capability-gated groups instead of hiding them (unrelated, same branch — see the entry below), 36f63fb merge: settings disable-vs-hide + power button order
- **Original TODO:** "move the power button as first element of the list. The buttons in the overlay show no text and don't do anything on click"

### What was asked
Two things about the power module added to the status bar's left island in an earlier round: (1) it should be the first icon in that island, not the third; (2) its overlay (the card that opens with lock/suspend/hibernate/logout/reboot/shutdown/settings) reportedly shows buttons with no visible text that do nothing when clicked.

### What was done
(1) `Bar/modules.json`: `power` was `position: 20` (after `phiAgent` at 0 and `workspaces` at 10). Renumbered to `power: 0, phiAgent: 10, workspaces: 20` — `Bar/Bar.qml` sorts each island's modules by this field ascending, so power now renders first.

(2) Read the whole path end to end before touching anything, since this looked like it could be a real bug: `Panels/BarPopout.qml`'s power section (each row a `Widgets.SmallButton { label: Services.PowerActions.title("…"); onClicked: root._requestPowerAction("…") }`), `Widgets/SmallButton.qml` (`text: root.label` on its inner `StyledText`, a `TapHandler` that calls `root.clicked()`), and `Services/PowerActions.qml` (`title()` returns a real, non-empty label for every one of the six actions; `perform()`/`needsConfirm()` back `_requestPowerAction`/`_confirmPowerAction` in `BarPopout.qml`, including the reboot/shutdown confirm-then-act flow). Every link in that chain is wired correctly — found no defect, and no way to tell from here whether this was already the case before the two prior power-related rounds on `dev` (`0a8b8fa`, `74663b7`/`1a290ac`) or is a side effect of them; not claiming either. Made no code change for this half — nothing to fix was found — and re-added it to `docs/TODO.md` as its own bare, unreproduced entry rather than letting a real user report vanish once this section is deleted on sign-off (workspace `AGENTS.md`, *Partial completion*).

### Honest assessment
<span style="color:red">**NOT DONE:**</span> the "buttons show no text and don't do anything on click" half was checked by reading the QML end to end (`phi-shell/CLAUDE.md`: "You cannot run this — every visual result is verified by the user with a screenshot"), not reproduced, not fixed, and not explained. Static reading found the label and click-handler wiring intact and correct, so if it still reproduces on hardware it's a different failure mode than a missing binding — a screenshot of the actual broken state is what unblocks this next, filed as its own `docs/TODO.md` entry so it survives this section being deleted.

The reorder (part 1) is a trivial, mechanical change with no ambiguity — confident it is correct once `phi theme`/Quickshell picks up the new `modules.json`.

### How to test it
1. On `razer` or `zotac`, make sure `phi-shell`'s `dev` branch is checked out at `~/.config/quickshell/phi` and pulled to this change (`36f63fb` or later). Quickshell hot-reloads `Bar/modules.json` on save; a fresh `qs -p ~/.config/quickshell/phi` restart also works if it doesn't.
2. Look at the left end of the status bar. Expected: the power icon is now the FIRST icon on the left (before the Φ agent icon and the workspace pills). Before this change it was third, after the Φ icon and the workspaces.
3. Click the power icon to open its overlay. Expected: six labelled rows — Lock, Suspend, Hibernate, Log out, Reboot, Shut down — plus a "Settings…" row, each with visible text. Clicking Lock/Suspend/Hibernate/Log out should act immediately and close the overlay; clicking Reboot or Shut down should swap the list for a one-line confirm ("Reboot now? This cannot be undone.") with Confirm/Cancel buttons, not act immediately. If any of that is still wrong, it's the separate open `docs/TODO.md` entry, not this reorder — a screenshot of what's actually on screen is the next step for it.

---

## Settings modules disappear entirely when the underlying hardware is missing

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 006eadb settings: disable capability-gated groups instead of hiding them, 36f63fb merge: settings disable-vs-hide + power button order
- **Original TODO:** "wifi settings don't show if wifi is disabled or missing. No settings modules should ever be hidden, they can be completely disable (with a message stating it)"

### What was asked
The Wi-Fi group in Settings › Connectivity vanishes completely on a machine with no Wi-Fi hardware (or, per the report, when Wi-Fi is off). The user's stated rule is general, not Wi-Fi-specific: no settings module should ever fully disappear for this reason — it should stay in place, disabled, with a message explaining why.

### What was done
`Settings/sections/SettingsGroup.qml` gained two new properties, `disabled` and `disabledReason`, alongside the existing `visible`/`caption`/`title`. When `disabled` is true: the title, caption and the hairline rule stay exactly where they are; a new warn-toned message line (`disabledReason`) appears in their place where the rows would explain themselves; and the row body (`bodyWrap`) gets `enabled: !disabled` (QtQuick cascades this to every child control's own input handling) plus an animated `opacity` fade to 0.45 — the same "reduced opacity, same weight" ratio `Widgets/WidgetStates.js`'s `INACTIVE_OPACITY` defines for every other disabled control in this widget set (§8.6), duplicated here as a literal rather than imported: every existing importer of that file is a sibling inside `Widgets/`, and this is the first consumer outside it — not worth being the first cross-directory relative JS import into a path with no compositor to test it against. The group itself is never `visible: false` any more.

Grepped every `visible: Config.Capabilities.*` in `Settings/` (six call sites — this pattern was not Wi-Fi-only) and converted all six to the new `disabled`/`disabledReason` pair, matching the general wording of the request:
- `Connectivity.qml`: Bluetooth ("No Bluetooth adapter was detected on this machine."), Wi-Fi ("No Wi-Fi hardware was detected on this machine.").
- `Devices.qml`: Battery, Chroma keyboard.
- `General.qml`: Battery (the read-only stats group).
- `Notifications.qml`: Chroma (the keyboard-blink-on-notification toggle).

All six gate on `Config.Capabilities.*` alone — the boot-time `/sys` hardware-presence probe (`PROGRESS.md` §3, "Capability detection"), which is the one signal this can reason about without a compositor. The report's "disabled" wording (as opposed to "missing") raised the question of also gating Wi-Fi on `Services.WifiBridge.present` (`Quickshell.Networking`'s live device list, for a radio that's merely off rather than absent) — deliberately left out: whether NetworkManager keeps a Wi-Fi `NetworkDevice` present-but-unavailable when the radio is soft-disabled, versus dropping it from `Networking.devices` entirely, isn't knowable by reading this repo, and guessing wrong would either never trigger the disabled state on a real radio-off, or flicker it on briefly during normal device enumeration at panel-open. The static hardware-missing case is fixed with certainty now; a live radio-off indicator (if the current "not connected" text isn't already enough) is a separate follow-up that needs a real device to observe first.

Did not touch the equivalent capability gating on status-bar icons (`Bar/modules.json`'s `capability` field) — that hiding is a deliberate, different, already-documented architecture decision (ADR 074: "a module declares a capability requirement and appears only where it exists"), and the TODO entry's own wording ("wifi **settings**") only reports the settings panel.

### Honest assessment
Not verified on hardware — `phi-shell/CLAUDE.md`: "You cannot run this." The QML is straightforward (a bool + a string driving `enabled`/`opacity`/text visibility, no new service surface, no new control types) and reuses a `tone` value already exercised elsewhere in the same file tree, but the actual look of a dimmed group with its warning line has not been seen rendered.

One judgment call worth flagging: `SettingsGroup`'s existing `caption` (when a group sets one, e.g. Devices' Battery group captions its charging-sound error) is NOT suppressed while `disabled` is true — both can show at once. Left this way deliberately (the caption still describes what the group IS; `disabledReason` explains why it's currently unusable — the two aren't mutually exclusive), but it wasn't spelled out in the request either way, so it's worth a look on the actual Battery group on a desktop machine (no battery) to confirm the two lines don't read as redundant or confusing stacked together.

### How to test it
1. On `razer` or `zotac`, update `phi-shell`'s `dev` checkout at `~/.config/quickshell/phi` to this change (latest `dev`); Quickshell hot-reloads on save.
2. Open Settings › Connectivity on `zotac`. `zotac`'s host profile (`phios-dotfiles/hosts/zotac.txt`: base, desktop, workstation, nvidia, gaming) never includes `laptop`, the only profile whose `packages.txt` installs `networkmanager` — so `zotac` should have no Wi-Fi capability regardless of its actual hardware. Expected: a "Wi-Fi" group IS visible (previously it was entirely absent), its title/rule shown normally, a line below reading "No Wi-Fi hardware was detected on this machine." in the warn colour, and its rows (Network / Manage networks / Speed & latency) visibly dimmed and non-interactive (clicking "Open nmtui…" does nothing).
3. Bluetooth could not be checked the same way — `bluez`/`bluez-utils` are in the `desktop` profile, which BOTH `zotac` and `razer` include, so package composition doesn't say which host's actual hardware lacks a Bluetooth HCI device (the capability probe reads `/sys/class/bluetooth/*` directly, nothing this repo records). If either host is known to have no working Bluetooth radio, open its Settings › Connectivity and confirm the Bluetooth group shows the same visible-but-disabled pattern instead of disappearing; otherwise this half can only be confirmed by temporarily disabling the adapter (`rfkill block bluetooth` may or may not be enough to drop it from `/sys/class/bluetooth` — untested from here) or by reading the code path, already done above.
4. On a machine with real Wi-Fi (`razer`), confirm the Wi-Fi group renders normally (no dimming, no message, "Network"/"Manage networks"/the speed graph all interactive).
5. On `zotac` (a desktop tower, no laptop battery): open Settings › General and Settings › Devices. Expected: a "Battery" group appears in both (previously absent), dimmed, with "No battery was detected on this machine." One caveat: `phios-dotfiles/bin/phios-capabilities`' battery probe matches any `/sys/class/power_supply/*` entry of `type=Battery`, which is usually the laptop's own battery but can also be a wireless mouse/keyboard reporting its charge level the same way — if `zotac` has one of those connected, the group may legitimately show as enabled instead. Not a bug in that case, just a different real capability reading.
6. If Wi-Fi is ever turned off (not unplugged) on `razer` while its group shows as fully enabled/undimmed, that's the live-radio follow-up flagged above — worth its own `docs/TODO.md` entry with what was actually observed (does the group stay enabled, or does something else already indicate it), not assumed from here.

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
