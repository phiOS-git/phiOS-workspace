# Features to be verified

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.

---

## Play a sound when the charger is plugged in

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 396b2f8 power: play a sound when the charger is plugged in, f967035 merge: play a sound when the charger is plugged in
- **Original TODO:** "add a sound on charging plugged in"

### What was asked
Play a sound the moment the laptop charger is plugged in — a discrete audio cue for a discrete event.

### What was done
This one is a Features-section item, not bug fixing: with the Bug Fixing section now down to hardware-blocked entries and feature-sized ones (see the h/j/k/l and scratchpad-border entries above, and the phi-agent-auto-start entry below), I moved to the smallest well-scoped Features item rather than stopping — flagging that here in case a straight bug-fixing continuation was expected instead.

In `phi-shell/Services/PowerBridge.qml` (the one file outside `Config/` sanctioned to touch the UPower service surface), added a `chargingSoundEnabled` property (default **on** — this is a small, deliberate difference from `Services/Notifications.qml`'s own sound toggle, which defaults off; a plug-in event happens once, not in bursts, and the user asked for this directly). Detection reuses the file's own existing `discharging` property (already `root.present && device.state === Discharging`) and watches for it flipping from `true` to `false` while `root.present` stays true — a charger being plugged in while running on battery. The `root.present` condition on the trigger matters concretely: without it, the UPower device disappearing entirely (e.g. a re-enumeration around suspend/resume) would ALSO read as a discharging→false transition and fire the sound with no charger involved — and this project has two separate, still-open, unexplained hibernation bugs on razer, the exact machine this targets, so that edge case felt worth guarding against rather than assuming away. A `_chargeSoundInit` guard also makes sure the very first state read (whenever UPower's device becomes ready, on shell startup) never itself counts as a "transition" and fires a sound at boot.

The sound plays via `pw-play` against `/usr/share/sounds/freedesktop/stereo/power-plug.oga` — same mechanism `Services/Notifications.qml` already uses for its own sound. Before picking that filename, checked (not recalled) that it's real: fetched the actual Arch `extra` package file listing for `sound-theme-freedesktop` (`archlinux.org/packages/extra/any/sound-theme-freedesktop/files/`) and confirmed `power-plug.oga` is genuinely shipped, and that the package itself is in `profiles/desktop/packages.txt` (so present on every machine that runs `phi-shell` — `mini` is headless and never renders this). A failed `pw-play` call now sets a `chargingSoundError` string (mirroring `Services/Notifications.qml`'s own `soundError` pattern) instead of failing silently.

A toggle to turn the sound off lives in Settings › Devices › Battery (new `SettingsGroup`, gated on `Config.Capabilities.battery` like the existing battery-stats group), persisted through `Config.Settings` (`phi state`) under the key `power.chargingSound`. Deliberately NOT placed in Settings › General's existing Battery group: that file's own header explicitly documents itself as read-only, "does not configure anything (§9.12 perimeter)" — tried putting the toggle there first and amending that documented invariant to carve out an exception, an advisor review called that out as rewriting the rule to fit the change rather than respecting it, which was the right call; moved the toggle to Devices (which already hosts other editable device/sound behaviour) and reverted the General.qml edit back to a clean no-op. Added "battery charging plug sound" to Devices' own search keywords in `Settings/sections.json` since Devices had no battery-related keywords before this.

### Honest assessment
- **Untested against a real compositor** — `phi-shell/CLAUDE.md`: "You cannot run this." Everything here (the UPower `discharging` edge-detection, the `pw-play` invocation, the Settings toggle wiring) is verified by reading source and, for the sound file itself, checking the real upstream package listing — not by hearing it play.
- **On by default.** The first time this lands, the user will hear a sound the next time they plug in the charger without having enabled anything — worth knowing going in, not discovering by surprise. Settings › Devices › Battery turns it off.
- **By design, this only fires on an actual discharging→charging transition while the device stays present** — it will NOT play at shell startup even if already plugged in at boot, and will NOT play across a suspend/resume cycle (the `root.present` guard exists specifically to prevent that). If it doesn't sound when the machine boots already on AC, that's the intended behavior, not a bug.
- Did not add any equivalent "unplugged" sound (`power-unplug.oga` also exists in the same theme) — not asked for, so not built.

### How to test it
1. On razer, pull the updated `phi-shell` `dev` branch (Quickshell hot-reloads `.qml` on save).
2. Unplug the charger if it's currently connected, wait a moment so the shell registers `discharging: true` (check Settings › General › Battery, which already shows "(discharging)"/"(charging)" next to the charge percentage).
3. Plug the charger back in — within a second or two you should hear the freedesktop "power-plug" chime once.
4. Open Settings › Devices, scroll to the new "Battery" group, and confirm the "Play a sound when the charger is plugged in" toggle is ON.
5. Turn it off, unplug and replug the charger again — confirm no sound plays this time.
6. Turn it back on, close and reopen the Settings panel (or restart the shell) to confirm the toggle's state survives — it's persisted via `phi state get power.chargingSound`.
7. If no sound plays at all even with the toggle on, check Settings › Devices › Battery's caption for a "Last sound error" message, and confirm `sound-theme-freedesktop` is actually installed (`pacman -Q sound-theme-freedesktop`).

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

## Give the scratchpad an accent-coloured border

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** c8ce034 hyprland: give the scratchpad an accent-coloured border, 464bb3f merge: give the scratchpad an accent-coloured border
- **Original TODO:** "add borders to the whole view when in the scratchpad or make it recognisable"

### What was asked
The general-purpose scratchpad (Super+A, `special:scratch`) looks identical to a normal workspace — nothing marks it as the scratchpad overlay rather than just another window. Add a border, or otherwise make it visually distinct.

### What was done
Pure Hyprland config, no phi-shell involvement — checked project memory first (`project_scratchpad_vs_special_workspaces_module`), which already established that Quickshell 0.3.1 (this project's pinned version) cannot read Hyprland's "special" workspace state at all, verified against Quickshell's own C++ IPC source, so a phi-shell-side indicator was ruled out ahead of time rather than attempted and found broken.

Added one `hl.window_rule` in `profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`, matching `workspace = "special:scratch"` (confirmed against Hyprland's own `desktop/rule/Rule.cpp` and `workspace/filter/statement/SpecialAddressableNameStatement.cpp` to be an exact match on the workspace's addressable name — exactly what `hl.dsp.workspace.toggle_special("scratch")`, already bound to Super+A, creates), setting `border_size = 3` (vs. Hyprland's own default of 1, confirmed from its `config/values/ConfigValues.cpp`) and `border_color = "${PHI_ACCENT} ${PHI_ACCENT}"` (the project's accent design token, `design/tokens.*.sh`).

The double-token colour value is deliberate, not a typo: traced how the Lua `border_color` binding actually resolves (`config/lua/bindings/LuaBindingsInternal.cpp` → `desktop/rule/windowRule/WindowRule.cpp`) and found a *single* colour string only ever sets the ACTIVE border — the moment the scratchpad's window loses focus, the border would revert to the normal default, defeating the point. Two identical colour tokens hit Hyprland's own documented `bordercolor <active> <inactive>` two-colour form instead, which the Lua wrapper reaches through an explicit legacy-string fallback when a plain single-colour parse fails (traced and confirmed, not assumed) — so the accent border stays regardless of focus.

### Honest assessment
- **Untested against a real compositor** — `phi-shell/CLAUDE.md`'s "you cannot run this" applies here too (no compositor access from an agent session). Everything above is verified by reading Hyprland's actual upstream source for this exact code path, not guessed at, but the visual result has not been seen.
- **Scope is deliberately narrower than it could be.** There's a separate, still-open Style-section TODO entry ("the hyprland scratchpad should slide in from below, have slightly more out spacing than other workspace and have a accent-colored border all around the screen") that asks for the same border plus a slide-in animation and wider gaps. This fix satisfies that entry's border request as a side effect, but does NOT touch spacing (`gaps_out`) or add any animation — those remain genuinely unimplemented. Did not edit or remove that Style entry since I didn't claim it and didn't do the rest of what it asks; flagging the overlap here so whoever picks it up next knows the border half is already done.
- The scratchpad can in principle hold more than one window — every window on `special:scratch` gets the accent border, which is the intent, but worth knowing if several windows are stashed there and shown together (rather than one showing up unexpectedly bordered).
- "The whole view" (a border around the full screen, rather than per-window) isn't something Hyprland's workspace/window rules can express — borders are always a per-window property in this compositor. This implements the closest real equivalent: every window on the scratchpad gets a thicker, accent-coloured border.

### How to test it
1. On razer (or zotac), pull the updated `phios-dotfiles` `dev` branch and re-run the install (`bin/phios-install`) so the template re-renders.
2. Reload the Hyprland config (or log out/in).
3. Press `Super+A` to open a window on the scratchpad (or `Super+Shift+A` on an existing window to send it there, then `Super+A` to show it).
4. The window's border should be visibly thicker than normal windows and coloured with the accent colour (`#d3a0ac` in the dark palette, `#8e5f6b` in light) — check both while the window is focused and, if possible, while focus has moved to a window on the underlying normal workspace with the scratchpad still shown, to confirm the border doesn't disappear on focus loss.
5. Press `Super+A` again to hide the scratchpad, confirm normal workspaces are unaffected (no accent borders anywhere else).

---

## Add working h/j/k/l alternatives for the broken super+shift/ctrl+arrow binds

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** fb70812 hyprland: add h/j/k/l alternatives for move-window and workspace prev/next, 4e0beff merge: add h/j/k/l alternatives for move-window and workspace prev/next
- **Original TODO:** "super+shit+left/right do not change active workspace" (clarified by the user during this session: neither Super+Shift+Left/Right nor Super+Ctrl+Left/Right do anything at all — not workspace change, not window move, not window focus. Only bare Super+Left/Right, which changes the focused window, works. The user does not care which exact keys end up bound, just that moving a window and switching workspace both work somehow.)

### What was asked
Super+Shift+Left/Right (move window) and Super+Ctrl+Left/Right (prev/next workspace) are both dead on the user's hardware (razer). Fix it — any working binding is acceptable.

### What was done
Spent real effort trying to find an actual root cause before resorting to a workaround, since "the arrow binds are broken" implied a possible config or Hyprland bug worth fixing at the source. Checked, against Hyprland's own upstream source (`gh api` against `hyprwm/Hyprland` and `hyprwm/hyprutils`, not guessed):
1. `keybinds/Bind.cpp` (`CBind::make`, modifier/key parsing, `matches`/`matchesContext`) — modifier tokens and multi-key binds are parsed and matched correctly; `Super+Shift+Left` and bare `Super+Left` have different modmasks and don't collide.
2. `keybinds/Resolver.cpp` (`modifierFromString`, `CResolver::resolveKeycode`) — "SHIFT"/"CTRL"/"SUPER" are all valid modifier names; `xkb_keysym_from_name` resolving "left"/"right" is case-insensitive and unrelated to which modifiers are also held.
3. `config/lua/bindings/LuaBindingsToplevel.cpp`'s `hlBind` (the actual C function behind `hl.bind` in this project's `.lua.tmpl` config) — nothing suspicious in how it builds the bind from the Lua call.
4. `hlBind`'s own `parseKeyString`, which splits the bind string on `+` via `hyprutils`' `CVarList2` and trims each token — verified (by reading `CVarList2::construct` in `hyprutils/src/string/VarList2.cpp`) that it trims every token both there and again in `parseKeyString`, so `"SUPER + SHIFT + left"` tokenizes to `["SUPER","SHIFT","left"]` correctly regardless of spacing. This ruled out a specific hypothesis (a naive splitter leaving a stray leading space that would make `xkb_keysym_from_name` fail to resolve "left" but not single-character keys) that looked plausible before checking.

None of these four checks turned up a defect. Given the user's explicit "I don't care about the exact bindings, I just want it to work," stopped trying to root-cause and instead added working alternative bindings, additively (nothing existing removed or changed) in `profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`:
- `Super+Shift+h/j/k/l` → move window left/down/up/right (`hyprctl dispatch movewindow l/d/u/r`)
- `Super+Ctrl+h/l` → previous/next workspace (`hyprctl dispatch workspace m-1/m+1`)

Checked for modmask collisions before adding: the existing "resize" submap's own bare `h/j/k/l` binds are submap-scoped (only active inside Super+R's submap) so they don't collide; `Super+L` (lock) has a different modmask than `Super+Shift+L` or `Super+Ctrl+L`, and Hyprland's bind matcher requires an exact modmask match (`Bind.cpp`'s `matchesContext`), so no collision there either.

### Honest assessment
This is a workaround, not a root-cause fix — the original Super+Shift/Ctrl+Left/Right binds are still declared in the config and, per the user's report, still don't do anything on real hardware. I could not reproduce the failure myself (no compositor access — `phios-dotfiles/CLAUDE.md` and workspace rules keep the three machines off-limits to agents), so I could not narrow down whether the binds are failing to register at all or registering but never firing (an input-layer/app-stealing-the-shortcut issue, or something keyboard/hardware-specific to razer). Left a detailed note with a concrete next diagnostic step (`hyprctl binds -j | grep -i left`, which discriminates "not registered" from "registered but not firing") in the TODO.md entry rather than closing it, since the real bug is still open.

### How to test it
1. On razer, pull the updated `phios-dotfiles` `dev` branch and re-run the install (`bin/phios-install`) so the template re-renders.
2. Reload the Hyprland config (or log out/in).
3. Focus a window, then press `Super+Shift+h`, `Super+Shift+l`, `Super+Shift+k`, `Super+Shift+j` — the focused window should move left, right, up, down respectively (equivalent to what `Super+Shift+Left/Right` was supposed to do and doesn't).
4. Press `Super+Ctrl+h` and `Super+Ctrl+l` — the active workspace should switch to the previous/next one (equivalent to what `Super+Ctrl+Left/Right` was supposed to do and doesn't).
5. Also still try the original `Super+Shift+Left/Right` and `Super+Ctrl+Left/Right` and confirm whether they remain non-functional — if this has changed, that's new information for the still-open root-cause investigation in TODO.md, not something this fix addresses.
6. If you have a moment, `hyprctl binds -j | grep -i left` and share the output — it tells us whether the original arrow binds are even registering, which is the open question.

---

## Cheat sheet: bindings now render in two columns

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** b38801e cheatsheet: render binding groups in two columns, ae98036 merge: render cheatsheet binding groups in two columns
- **Original TODO:** "the cheathsheet shell should have 2 columns"

### What was asked
The cheat sheet (Super+Shift+/) rendered every keybinding group stacked in one long vertical scrolling column. Wanted: two columns, presumably to use the panel's width better and shorten the scroll.

### What was done
`Cheatsheet/Cheatsheet.qml` previously had one `Column` (inside a `Flickable`) with a single `Repeater` over `root.grouped`, each group rendering its own header + hairline + Repeater of bind rows. Split `root.grouped` into `groupedLeft`/`groupedRight` by index parity (even index → left, odd → right) — not a straight first half / second half split, since `Services.Keybinds.groups` gives no guarantee groups are ordered by size, and alternating spreads the risk of one column ending up visibly taller more evenly than a blind split would.

The per-group renderer (header, hairline, its own Repeater of bind rows) is now a shared `Component` (`groupBlock`), instantiated by two separate `Repeater`s — one per column — instead of appearing inline once. Its own root `Column`'s `width` binding changed from a specific named outer Column to `parent.width`, since it's now instantiated by two different parent Columns and needs to resolve correctly under either. The two columns sit in a `Row` inside the same single `Flickable` as before; `Row`'s own `implicitHeight` (the taller of its two children — standard Qt Quick behavior) drives the Flickable's scroll extent, so nothing here has to compare the two columns' heights itself.

`keyColW` (the shared key-column width all rows align to, so `[ SUPER + ... ]`-style key chips line up) stays computed across the *full* `root.filtered` list, unchanged — both columns needed to agree on the same width for the alignment to still read as one coherent sheet, not two separately-aligned halves.

### Honest assessment
- Went through an advisor review before landing: it flagged that `keyColW`'s own comment says it's "capped... so a single very long binding cannot push the description column off to the right," and asked whether that cap was proportional to panel width (which would now be halved) or absolute. Checked: the cap is `(min(longest-key-chars, 34) + 1) * chWidth` — a fixed character-cell count, completely independent of panel width — and the cheat sheet panel itself is `parent.width * 0.6`, so each half-column is comfortably wider than the cap's ~35-cell budget. Confirmed fine, not just assumed.
- **A real, inherent side effect worth knowing about, not a bug**: `groupedLeft`/`groupedRight` are derived from `root.filtered`, which changes with every keystroke in the search field. Since the split is by index parity over the *filtered* list, typing a search query that removes a group can shift every later group's parity — visible as groups hopping between the left and right column while you type. This is inherent to any index-based alternating split reacting to a filtered list, not something worth building around for a read-only cheat sheet, but you should expect to see it rather than read it as broken.
- Untested against a real compositor — `phi-shell/CLAUDE.md`: "You cannot run this."

### How to test it
1. Open the cheat sheet (Super+Shift+/).
2. It should now show two side-by-side columns of keybinding groups (each with its own context header and hairline), not one long single column.
3. Scroll — both columns should scroll together as one unit, and the shorter column's empty space at the bottom is expected (matches the taller one's extent), not a bug.
4. Type into the search field and watch closely: as groups get filtered out, some remaining groups may visibly swap from the left column to the right or vice versa. Expected — see the honest assessment above — not a rendering glitch.
5. Regression check: key chip alignment (`[ SUPER + N ]` style) should still look correct within each column, and every row should still show key → arrow → description exactly as before, just narrower per column.

---

## Steam moved to workspace 11, btop to workspace 12

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev, phi-shell / dev
- **Commits:** phios-dotfiles: 7c47272 hyprland: move Steam to workspace 11, btop to workspace 12, 387f781 merge: move Steam to workspace 11, btop to workspace 12 — phi-shell: ddb2593 bar: renumber Steam/btop workspace icons to 11/12, cbea7c2 merge: renumber Steam/btop workspace icons to 11/12
- **Original TODO:** "make steam workspace 11 and btop workspace 12"

### What was asked
Move the pinned Steam and btop workspaces from their current numbers (9 and 10) to 11 and 12.

### What was done
Renumbered both in `phios-dotfiles`' `hyprland.lua.tmpl`: the btop `workspace_rule` (`persistent`) and both apps' `window_rule`s (`^phios-btop$` → workspace, `^steam$` → workspace) now target `"12"`/`"12 silent"`/`"11"` instead of `"10"`/`"10 silent"`/`"9"`, plus every surrounding comment that named the old numbers (the AUTOSTART section's btop note, the scratchpad bind's note, and the WINDOWS AND WORKSPACES block itself). Companion change in `phi-shell`: `Bar/workspace-icons.json` (the id → glyph data file, ADR 078 — this is genuinely the whole client-side change needed, the rendering code is data-driven) now maps ids 11/12 instead of 9/10, plus the explanatory comment in `Bar/modules/Workspaces.qml`.

Checked for every other reference to the old numbers across both repos (`grep` for "workspace 9", "workspace 10", `= "9"`, `= "10"`, the JSON ids) before calling it done — found and fixed all of them; nothing else in either repo hardcodes these two workspace numbers.

### Honest assessment
- **Real, not-hidden trade-off**: workspaces 1-10 have a dedicated physical key under the existing `Super+1..0` loop (`for i = 1, 10`); 11 and 12 do not, and the loop wasn't extended to cover them (nothing in the TODO asked for that, and this project's convention keeps "type is code, instance is data" — extending the loop's range is a design decision I didn't make speculatively). Reaching Steam/btop by keyboard now means the bar icon click, or the three-finger workspace-swipe gesture cycling around to them — not a dedicated bind. The upside, and very likely the actual point of this request: Super+9 and Super+0 go back to being ordinary, unclaimed workspace switches instead of always landing on Steam/btop.
- Untested against a real compositor — `phi-shell/CLAUDE.md`: "You cannot run this." This is a low-risk, mechanical renumbering (every changed value is a plain string/number, not new logic), so I'm confident in it, but a screenshot check is still the real verification.

### How to test it
This needs `phios-install` to re-render the templated Hyprland config and reload it — either run `bin/phios-install` from `phios-dotfiles` and then `hyprctl reload`, or however you normally pick up a `hyprland.lua.tmpl` change. `phi theme render`/a `qs` hot-reload should pick up the `workspace-icons.json` change automatically since Quickshell watches its own files.
1. Open btop (or let it autostart with the session) and check it lands on workspace 12, not 10 — the bar's workspace strip should show a monitor-glyph icon at that position.
2. Open Steam and check it lands on workspace 11, not 9 — the bar should show a Steam-glyph icon there.
3. Press Super+9 and Super+0 — they should now switch to plain, ordinary (possibly empty/newly-created) workspaces, not jump to Steam or btop.
4. Click the Steam/monitor icons in the bar's workspace strip — each should switch to its respective workspace (11/12) exactly as clicking any workspace icon always has.

---

## Clipboard preview: floats beside the sidebar, aligned to the entry

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 9e66140 clipboard: float the hold/hover preview beside the sidebar, aligned to the entry, 77f4721 merge: float the hold/hover preview beside the sidebar, aligned to the entry
- **Original TODO:** "the clipboard preview should be on the left of the sidebar, rather than inside. Also it's very low, it should be vertically aligned with the relative entry (beware of the position in the screen, so that it does not go out of the screen area)."

### What was asked
The clipboard tab's hold/hover preview (shown after dwelling on an entry) was rendering as a full-width bar docked to the bottom of the sidebar's own content area — inside the panel, low on screen, and not related to which entry triggered it. Wanted: a floating panel to the LEFT of the sidebar, vertically lined up with the specific entry that's being previewed, and never allowed to run off any screen edge.

### What was done
`Panels/tabs/Clipboard.qml`'s preview was `anchors.left/right/bottom: parent...` — a bar glued to the tab's own bottom edge, unrelated to any card. The original author had deliberately avoided tracking a specific card's position, flagging per-card `mapToItem` tracking as "unverifiable without a compositor" (their own comment, still in the file's history).

Rebuilt it as a properly positioned floating panel, following the same one-shot-`mapToItem`-at-a-known-moment shape `Widgets/Segment.qml`'s `rightX()` already uses for the bar's popouts (called imperatively from a handler, not left inside a live declarative binding — confirmed `mapToItem` isn't tracked as a binding dependency by Qt's meta-object system anyway, so a continuous binding through it wouldn't reliably update):

- Every `entryCard` delegate now registers itself into `root._cardItems` (id → Item) on creation and unregisters on destruction, since the pinned/rest split means there's no single flat Repeater index to look a card up by.
- When the dwell timer fires (right before the preview becomes visible), `_updatePreviewPosition()` reads three absolute screen positions once: the dwelled card's Y (center), the sidebar dock's own left edge (via a new `dockItem` reference `Sidebar.qml` now passes down — the tab's own root sits inset inside the dock by `Widgets/Panel.qml`'s own padding, so root's own position is NOT the dock's visible edge), and root's own absolute Y (needed to convert the preview's y into root-relative terms, since the preview stays root's own child rather than being reparented to the window's top item).
- The preview panel's `x`/`y` are computed in absolute screen terms from those three numbers, each axis independently clamped to `[panelGap, screen edge − panel's own size − panelGap]` — the TODO's explicit "does not go out of the screen area" — then converted back to root-relative coordinates.
- `Sidebar.qml` now hands the Clipboard tab its own actual screen size (`screenWidth`/`screenHeight`) and the `dock` Item reference, since the tab's own width/height was only ever the dock's own right-hand strip, not the screen.
- Narrowed the preview to 80% of the dock's own width (previously exactly the dock's own width): at full width, a screen narrower than usual would push the panel far enough left that the screen-edge clamp wins and the preview slides *under* the dock instead of beside it — silently wrong-looking, not an error, so worth avoiding rather than accepting.

### Honest assessment
This went through a real review pass before landing, not just a single draft: an advisor review (I use one for substantive changes) caught two things I'd gotten wrong the first time — the preview's X position was computed from root's own absolute position instead of the dock's, which would have overlapped the sidebar's left border by about one padding's worth instead of sitting beside it; and a `Component.onDestruction` handler read `card.modelData.id` directly, a known QML footgun where `modelData` can already be `undefined` on an about-to-be-destroyed Repeater delegate. Both are fixed in what actually landed (the id is now captured into its own property at creation, read by both the register and unregister paths). The width-narrowing tradeoff is a judgment call, not a correctness fix — noted above so you can weigh in if 80% reads wrong once you see it.

Still genuinely untested against a real compositor — `phi-shell/CLAUDE.md`: "You cannot run this. Every visual result is verified by the user with a screenshot." This is meaningfully more involved QML than most of this session's other fixes (new cross-component state, coordinate-space conversion, delegate lifecycle), so it deserves a closer look than a glance.

### How to test it
1. Open the clipboard panel (Super+Shift+V) with several entries in history.
2. Hover over an entry card (not the very top or bottom one) and hold still for about 700ms. The preview panel should appear as a floating panel to the LEFT of the sidebar dock — not inside it, not docked to the bottom — vertically centred roughly on the row you're hovering.
3. Move to a different card (or use arrow keys to change the keyboard selection) and dwell again — the preview should reposition to align with the new entry.
4. Hover/select an entry very near the TOP of the screen, and separately one very near the BOTTOM. In both cases the preview panel should stay fully on-screen (clamped), not spill off the top or bottom edge, even though it's no longer perfectly centred on the entry in those cases.
5. If your output is on the narrower side, check the preview doesn't end up sitting underneath the dock instead of beside it — if it does, the 80%-width judgment call above needs revisiting.

---

## Volume-up key now caps at 100%

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** 9de4051 hyprland: cap volume-up key at 100%, 5e9a802 merge: cap volume-up key at 100%
- **Original TODO:** "holding the volume up key (fn+f3 on the razer) should reach a top of 100%. To increase over 100% it requires a double click + hold." — partially done, see below

### What was asked
Two things in one line: holding the volume-up key should stop climbing at 100% (it currently doesn't), and going past 100% should require a deliberate double-tap-and-hold instead of happening by default.

### What was done
Only the first half. `hyprland.lua.tmpl` binds `XF86AudioRaiseVolume` straight to `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+`, `repeating = true`. `wpctl`'s percentage steps are uncapped by default — PipeWire allows amplification above unity gain — so every repeat of `5%+` while the key is held just kept climbing with nothing to stop it at 100%. Added `wpctl`'s own `-l 1.0` limit flag (confirmed against the real Arch `wpctl(1)` man page: "`-l, --limit LIMIT` — Limit final volume to below this value (floating point, 1.0 = 100%)", not assumed from memory) — the new bind is `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0`.

Deliberately did **not** attempt the second half (a double-tap-and-hold gesture to intentionally exceed 100%) as part of this fix, and left it behind as its own, narrower `docs/TODO.md` entry rather than silently dropping it. Reasons: Hyprland's Lua bind system has no built-in double-tap primitive — it would need custom timer/state logic in `hyprland.lua.tmpl` — and this exact file already documents a cautionary precedent for that shape of gesture: SUPER+G's cursor-spotlight bind went through several rounds (ROUNDS FOUR/FIVE/SIX, all in this same file) trying a double-/triple-tap gesture before landing on a documented, real compositor bug (`hyprwm/Hyprland#6946`) and reverting to a plain press/release bind. That precedent is specifically about a bare-modifier-keysym bind (`SUPER_L`), which doesn't directly apply to an ordinary key like `XF86AudioRaiseVolume` — but building a new custom-timed gesture on a volume key still deserves its own deliberate design pass, not a guess bolted onto this fix.

### Honest assessment
The 100% cap is a config-only fix using a documented, real `wpctl` flag — I'm confident in it, though untestable without the real machine (`phios-dotfiles`' `CLAUDE.md`: no `pacman`/`systemctl`/hardware access). The deferred half is a genuine scope cut, not an oversight — flagged clearly rather than either guessing at a fragile implementation or silently deleting the ask.

### How to test it
This needs `phios-install` to re-render the templated Hyprland config and reload it — either run `bin/phios-install` from `phios-dotfiles` on `razer` and then `hyprctl reload`, or however you normally pick up a `hyprland.lua.tmpl` change.
1. Lower the volume to something well under 100% (e.g. via the OSD or `wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%`).
2. Hold Fn+F3 (or however the raise-volume key reaches Hyprland as `XF86AudioRaiseVolume`) down continuously.
3. Volume should climb in 5% steps and stop exactly at 100% — it should not be possible to push it higher by holding the key, however long you hold it.
4. Regression check: lowering volume (Fn+F2 or whichever key maps to `XF86AudioLowerVolume`) should behave exactly as before, stopping at 0%, unaffected by this change.

---

## Mouse cursor no longer disappears after touchscreen contact

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** 968104b hyprland: stop hiding the cursor on touchscreen contact, 2e3ffa3 merge: stop hiding the cursor on touchscreen contact
- **Original TODO:** "the mouse cursor often disappear arbitrarily. Do not apply more logic, check where the cursor visibility is ever altered and and work from that"

### What was asked
The mouse cursor sometimes vanishes with no obvious trigger, and I was specifically asked not to bolt on new workaround logic, but to find whichever existing mechanism is actually altering cursor visibility and fix that.

### What was done
Nothing in this project's code alters cursor visibility directly — there's no QML or shell logic anywhere that hides the system cursor (checked: grepped every repo for cursor-visibility-related identifiers, nothing turned up beyond theming/cursor-theme config). The mechanism is Hyprland's own, and this project simply never configures it, so Hyprland's *default* has been running untouched.

Pulled Hyprland's actual default-value table for the `cursor` category (`hyprwm/hyprland-wiki`'s `content/configuring/core/config-options.md`, the same file the docs site renders from — not assumed from memory): `cursor:hide_on_touch` defaults to `true` — "Hides the cursor when the last input was a touch input until a mouse input is done." `razer` (your primary, daily-use machine) has a touchscreen (`phios-capabilities`' `PHI_CAP_TOUCHSCREEN`, and this same config file's own GESTURES section already notes "razer has both" a touchpad and touchscreen). Any contact with the screen — a deliberate touch gesture, or just brushing it while adjusting the lid — puts Hyprland into "last input was touch" state and hides the pointer until it sees a mouse-classified input again. That is about as "arbitrary-looking" as a real bug gets: there's no reason to associate "screen went dark for a second, cursor's gone" with "I touched the display."

Fixed with one `hl.config({ cursor = { hide_on_touch = false } })` block in `hyprland.lua.tmpl`, right after the existing `input` config block (same file, same `hl.config` mechanism already used there for `follow_mouse`). This is a plain default override, not new logic layered on top — it turns off the exact switch causing the symptom. `zotac` has no touchscreen, so the setting is a no-op there, same reasoning already established for the touchscreen gesture binds elsewhere in the same file; `mini` never renders this template at all (headless, no graphical session).

### Honest assessment
I'm confident in the mechanism (verified against Hyprland's own documented default, not guessed), but I could not reproduce "cursor disappears" myself — no compositor to run (`phi-shell/CLAUDE.md`'s "you cannot run this" applies just as much to Hyprland itself in this environment) — so I can't rule out a second, unrelated trigger also contributing on your hardware. If the cursor still disappears after this lands, the next things I'd check are `cursor:hide_on_key_press` and `cursor:inactive_timeout` (both already default to off/0 — no reason to touch them pre-emptively, but worth confirming they're still at their defaults and nothing else set them since).

### How to test it
This needs `phios-install` to re-render the templated Hyprland config and reload it — either run `bin/phios-install` from `phios-dotfiles` on `razer` and then `hyprctl reload`, or however you normally pick up a `hyprland.lua.tmpl` change.
1. Tap the touchscreen once (a single tap is enough to register as touch input).
2. Without moving the trackpad/mouse, check whether the pointer is still visible on screen. Before this fix it would vanish; after, it should stay visible exactly as before the tap.
3. Move the trackpad/mouse — the pointer should of course still track normally either way, so this step alone doesn't distinguish before/after; step 2 is the actual test.
4. General regression check: touchscreen gestures (the three-finger workspace swipe) should behave exactly as before — this change only affects cursor visibility, not any touch input handling.

---

## Steam workspace icon: fixed wrong glyph codepoint

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 5be5304 bar: fix the Steam workspace glyph codepoint, 02868e3 merge: fix the Steam workspace glyph codepoint
- **Original TODO:** "steam icon in the status bar is using a phone glyph, it should use the steam one from font nerd"

### What was asked
The workspace icon meant to show Steam (workspace 9's glyph in the bar's workspace strip) renders as a phone icon instead.

### What was done
`Bar/glyphs.js` defined `steam` as codepoint `0xF03F7`. I downloaded nerd-fonts' own `glyphnames.json` (`gh api repos/ryanoasis/nerd-fonts/contents/glyphnames.json`, the authoritative name→codepoint table for the exact font this project patches against) and looked up both directions: `0xF03F7` is `nf-md-phone_incoming` — literally a phone glyph, matching your report exactly — and the real `nf-md-steam` is `0xF04D3`. Simple wrong-constant bug, not a missing/unpatched glyph, which is why it silently rendered as a real (wrong) icon instead of a tofu box or an obviously broken one. Fixed the one definition; confirmed via `grep` that nothing else in the repo referenced the old codepoint directly.

### Honest assessment
Clean — this is a one-line data fix confirmed against the authoritative source for what the codepoint should be, not a guess. The only thing I can't confirm myself is that the installed font on your machines actually is a nerd-fonts build recent enough to include Material Design Icons at the new `0xF0001+` codepoint range (nerd-fonts v3.0+ moved MDI off the old `0xF500-0xFD46` range) — if it's an older patched font, `Glyphs.monitor` (btop's icon, same range) would already be showing the same symptom, so if btop's icon has looked correct this whole time, this fix will too.

### How to test it
Look at workspace 9 in the bar's workspace strip (or wherever Steam is currently pinned — see the separate open TODO about renumbering it to 11). It should show the Steam icon (the stylized "S" in a circle), not a phone icon.

---

## Super+N always lands on Notifications; Super+Shift+V now toggles the clipboard panel closed too

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev, phios-dotfiles / dev
- **Commits:** phi-shell: 2ff299e notifications: make the per-tab open actions toggle-aware, fb2b4a4 merge: make the per-tab open actions toggle-aware — phios-dotfiles: 5ce78eb hyprland: bind Super+N to the notifications-tab action, not plain toggle, 87795bc merge: bind Super+N to the notifications-tab action
- **Original TODO:** "super+n should open notification (focus the right tab), super+shit+v should not only open but also close the clipboard panel"

### What was asked
Two related complaints about the notification/clipboard panel's two keyboard entry points: Super+N should always land you on the Notifications tab (not wherever the panel was last left), and Super+Shift+V — which opens straight onto the Clipboard tab — should also close the panel on a second press, the way a toggle normally would.

### What was done
Found both bugs exactly where the TODO describes them, in `Services/NotificationPanel.qml` and `phios-dotfiles`' `hyprland.lua.tmpl`:

- **Super+Shift+V**: bound to `ipc call notifications clipboard` → `openClipboard()` → the old `openTab(1)`, which unconditionally does `tab = 1; shown = true`. There was no branch that ever set `shown = false` — a second press while already open on the Clipboard tab was a no-op, so it could only open, never close.
- **Super+N**: bound to `ipc call notifications toggle` — the *plain* `toggle()` (`shown = !shown`), which never touches `tab` at all. If the panel was last left open on the Clipboard tab and then closed, pressing Super+N reopened it back onto the Clipboard tab, not Notifications — "focus the right tab" never actually happened. (A `notifications()` ipc function calling `openNotifications()`/`openTab(0)` already existed in `Panels/Sidebar.qml`'s IpcHandler, just not wired to any keybind — Super+Shift+V's `clipboard()` counterpart was already bound, `notifications()` wasn't.)

Fix: added `toggleTab(i)` to `Services/NotificationPanel.qml` — switches to tab `i` (opening the panel if it was closed, or switching tabs if it was open elsewhere), and closes the panel only if it was already open on that exact tab. `openClipboard()` and `openNotifications()` both now go through it. Then rebound Super+N in `hyprland.lua.tmpl` from `qsIpc("notifications", "toggle")` to `qsIpc("notifications", "notifications")`, so it goes through the same tab-aware path Super+Shift+V already used. Super+Shift+V's own hyprland.lua bind needed no change — it already called `clipboard()`, which inherited the new toggle-close behavior automatically once `openClipboard()` was rewired.

The bar's notification bell (`Bar/modules/Notifications.qml`) still calls the plain `toggle()` directly, untouched — clicking it isn't tab-specific the way a keybind aimed at one particular tab is, so its "just flip visibility, stay wherever the tab was" behavior is still the right one.

### Honest assessment
Untested — this is QML and a Hyprland Lua config I cannot run (`phi-shell/CLAUDE.md`: "You cannot run this. Every visual result is verified by the user with a screenshot"). The logic is small and I traced every call site of the changed functions (`grep -rn "NotificationPanel\."` across the whole `phi-shell` tree) to confirm nothing else relies on the old unconditional-open behavior of `openClipboard()`/`openNotifications()` — only the two IpcHandler entries in `Panels/Sidebar.qml` call them, and both are exactly the keybinds this TODO is about.

### How to test it
This needs `phios-install` to re-render the templated Hyprland config and reload it — either run `bin/phios-install` from `phios-dotfiles` and then `hyprctl reload`, or however you normally pick up a `hyprland.lua.tmpl` change.
1. With the notification/clipboard panel closed, press Super+N. It should open on the Notifications tab.
2. Press Super+Shift+V. It should switch to the Clipboard tab (panel stays open, just switches tab) — not close.
3. Press Super+Shift+V again, with the panel still open on the Clipboard tab. It should now close the panel.
4. Reopen with Super+N. It should open straight on Notifications again (not Clipboard, even though Clipboard was the last tab shown).
5. Press Super+N again while already on the Notifications tab. It should close the panel.
6. Regression check: click the bell icon in the status bar. It should still just toggle the panel open/closed, staying on whatever tab was last active — unaffected by this change.

---

## Clipboard: long pastes no longer preview as "(empty)"

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 0ac1225 clipboard: bound the list preview by bytes, not by line, d96f8d0 merge: bound the clipboard list preview by bytes, not by line
- **Original TODO:** "the clipboard shows \"(empty)\" when the content is too long, it should get trimmed"

### What was asked
A long clipboard entry shows "(empty)" as its card preview in the sidebar instead of a trimmed snippet of its actual content.

### What was done
Found the extraction, in `Services/Clipboard.qml`'s `listProcess`: `head -n1 "$dir/$id.data" | cut -c1-200` — take the first physical line, then truncate to 200 characters. I could not reproduce the exact "(empty)" symptom itself (QML I cannot run), so I can't point at one single confirmed root cause, but there are two real, independent bugs in that line, either of which produces exactly this symptom, and my fix removes both:

1. **`head -n1` returns an empty string whenever the first physical line of the file is blank.** Very plausible for "long content" specifically — a block of text copied out of a browser selection or an editor often carries a leading blank line, no matter how much real content follows on later lines. `entries[].preview` then ends up `""` and the card falls back to the literal string `"(empty)"`.
2. **`cut -c` has to buffer an entire line into memory before it can emit anything**, since it needs to find the line boundary before it knows what "characters 1-200" even means. For a long paste with no embedded newline at all (one big unbroken line — a long URL, a minified blob, a paragraph copied without hard wraps), that's the entire multi-megabyte content `cut` has to hold before producing 200 characters of output. I measured this directly (plain shell, no hardware needed): a 50MB single-line file took `head -n1 | cut -c1-200` ~1.9s, versus ~10ms flat for the `head -c 200` replacement regardless of file size. That confirms the cost scales badly with content size and sits inside `listProcess`'s for-loop over *every* clipboard entry on every refresh — but at the sizes I tested it still eventually produced output, just slowly, so I can't confirm this path is the one that actually reached zero output rather than #1 above.

Fixed by switching to `head -c 200`, which reads exactly 200 bytes directly off disk regardless of line length or line count — this depends on neither line boundaries nor content size, so it structurally rules out both candidate causes rather than just the one I could measure. Since `head -c` no longer stops at the first newline, the extracted snippet can now itself span multiple lines; the `tr` pass was changed from stripping `\0`/`\r`/`\t` to *folding* `\n`/`\r`/`\t`/`\0` into spaces instead, so an embedded newline can't split the shell loop's `id<TAB>mime<TAB>preview` row into two lines and break the TSV parsing on the QML side. That fold is also a visible, deliberate behavior change worth knowing about: a multi-line paste's card preview is no longer just "the first line(s)" — it's the first 200 bytes of the whole entry, line breaks shown as spaces. I checked every other reader of this field (`grep -rn "\.preview" phi-shell/`) — only `Clipboard.qml`'s search filter and card display touch it, both fine with the new shape.

### Honest assessment
- I don't have a confirmed single root cause, only two real bugs that both produce this exact symptom and are both eliminated by the fix (see above) — I'm confident the fix is correct, less confident about which bug you actually hit.
- Byte-bounded truncation (`head -c 200`) can in principle split a multi-byte UTF-8 character at the 200-byte boundary for non-ASCII content, which `cut -c` (locale-aware on GNU coreutils) mostly avoided. Worst case this shows as a single stray replacement character at the tail of a non-ASCII preview — cosmetic, not another "(empty)" case — and only on the short card preview; the separate hold/hover full-text preview (`previewFullText` in `Panels/tabs/Clipboard.qml`) already truncates correctly on decoded-string length, unaffected by this change.

### How to test it
1. Copy something whose first line is blank — e.g. `printf '\nhello world' | wl-copy` — or something very long with no line breaks at all — e.g. `python3 -c "print('x'*2000000, end='')" | wl-copy`.
2. Open the clipboard panel (Super+Shift+V) and find that entry in the list. Its card should show a trimmed snippet of the actual content ("hello world", or a couple hundred `x`s), not "(empty)".
3. Regression check, and note this is a real behavior change, not "exactly as before": copy a short multi-line paste (e.g. two or three lines of a code snippet). The card should now show up to ~200 characters starting from the very beginning of the content, with line breaks rendered as spaces (not just the bare first line truncated at 200 characters as it did before) — still wrapped over at most 2 lines on the card.

---

## Bar: Tailscale/VPN module no longer disappears when idle

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 211720a bar: keep the network module visible with an off state, ae8fa0c merge: keep the network module visible with an off state
- **Original TODO:** "tailscale/VPN in the status bar completely disappear, it used to be next to the wifi in previous versions and needs to be restored. Even when neither of the 2 are active, the icon should still exist (with a custom state, not empty)"

### What was asked
The Tailscale/VPN module in the status bar was gone entirely — you said it used to sit next to the wifi module and should come back, and that even with neither Tailscale nor a WireGuard tunnel up, the icon should stay put with a distinct "off" state instead of vanishing.

### What was done
Its position was never the problem: `Bar/modules.json` already places `network` at position 30, right before `wifi` at 40 — same slot it's always had. The bug was in `Bar/modules/Network.qml`: `visible: root.ts || root.vpn` hid the whole segment whenever both Tailscale and every VPN tunnel were down, which on a machine with neither active reads as "the module is broken," not "idle." A `vpnOff` glyph already existed in `glyphs.js` (comment: "tailscale down"), unused — a leftover from before that `visible` line was added.

Removed the `visible` binding (Segment defaults to visible) and made the module follow the same grammar `Wifi.qml`/`Bluetooth.qml` already use: glyph swaps to `Glyphs.vpnOff`, label reads `"off"`, and `tone: "warn"` when neither Tailscale nor any VPN tunnel is up; otherwise unchanged (glyph `Glyphs.vpn`, label `"<tailscale host> | <vpn tunnel>"`, joined only from whichever side is actually up). The bar popout (`Panels/BarPopout.qml`, `which === "network"`) already renders a sensible idle state (Tailscale's own state string, "VPN · no tunnels") — it needed no change, and is now actually reachable by click when the module is idle, which it wasn't before.

### Honest assessment
Untested — this is QML I cannot run (`phi-shell/CLAUDE.md`: "You cannot run this. Every visual result is verified by the user with a screenshot"). The fix is small and mirrors an existing, working pattern (Wifi/Bluetooth modules) exactly, so I'm confident in the logic, but I have not seen it rendered.

### How to test it
1. On a host where Tailscale is down and no WireGuard tunnel is up, look at the right island of the status bar, just left of the wifi icon. The network module should now be visible showing a dimmed/warn-toned icon and the label "off" — previously nothing was there at all.
2. Click it — the bar popout should open under it showing "Tailscale: <state>" (e.g. "Stopped") and "VPN · no tunnels" (or your configured tunnels, toggleable), same as before.
3. Bring Tailscale up (or start a WireGuard tunnel) and check the module switches back to the active glyph/tone with the hostname/tunnel name as the label, still in the same position.

---

## Screenshot: area captures were always tinted pink

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** f163d93 screenshot: hide our own UI before invoking grim, not after
- **Original TODO:** none — reported directly in conversation, not from docs/TODO.md ("the screenshot area works correctly, however area screenshots are always pink, as they screenshot the area selection which is pink")

### What was asked
You reported the area-selection geometry itself is correct now (the earlier offset bug is fixed), but every area screenshot comes out tinted — because it's capturing the pink drag-select rectangle itself, not just the screen content underneath it. You also asked for a broader cleanup pass on the screenshot feature, since a bug like this is the kind that "should never happen."

### What was done
Root cause, in `Screenshot/Screenshot.qml`: `_captureGeometry` spawned `grim` **synchronously, before `root.mode` was even set back to `"idle"`** in the same `onReleased` handler. The drag-select rectangle (`Config.Appearance.accent` at 0.25 opacity — accent happens to be pink in the current theme, hence "always pink") was still fully composited on screen at the exact moment `grim` ran. This wasn't a rare race — it was a flatly wrong order, capture-then-hide instead of hide-then-capture, so it fired on literally every area capture.

Fixed with a new `_prepareCapture(fn)` that every capture path now funnels through (area/OCR/QR select, fullscreen, and the hyprctl-driven window capture): it hides this surface's own UI first — `mode` back to `"idle"`, `selectionRect` cleared, **and `resultText` cleared too**, since a leftover, undismissed OCR/QR result panel from a *previous* capture is just as much "our own UI" and would leak into a new capture the exact same way — then waits one Category-B state-transition duration (`Config.Appearance.motionBDuration`, a real design token — not a hardcoded literal, which `phi-shell/CLAUDE.md`'s audit rule forbids) before actually invoking `grim`. That wait matters: writing the hide-triggering properties is necessary but not sufficient, since Qt Quick still has to render a frame without them and the compositor still has to composite and present it, and neither happens synchronously with the property write.

`_captureFullscreen`/`_captureGeometry` are now thin wrappers; the actual `grim` invocation moved to `_doCaptureFullscreen`/`_doCaptureGeometry`. Every existing call site gets the fix automatically, without needing to remember the hide-first sequencing itself — the point being that a future capture path added to this file can't reintroduce the same bug class by simply forgetting a step.

**Deliberately untouched:** the `grim -g` geometry math in `onReleased`. That's your own hardware-verified fix (`df4298d`) for the separate, already-resolved offset bug — this change touches none of it, only the ordering of hide vs. capture.

### Honest assessment
- **The settle delay (`motionBDuration`, 120ms) is a reasoned default, not hardware-verified.** It's the right *category* of token (§6.5: "state transition... high frequency... short") and a real render pipeline (property write → Qt Quick render → Wayland commit → compositor composite+present) plausibly completes well within it, but I have no way to confirm the actual minimum safe value on your hardware. If a capture is still *occasionally* tinted (not every time — that would mean this fix didn't land), this is the one number to try raising.
- **Triggering two captures within that 120ms window drops the first one silently.** `_prepareCapture` calls `captureSettle.restart()`, so a double-tap of a capture keybind (or two IPC calls close together) makes the second request win and the first's `fn` never runs. I judged this the right behavior (last request wins, matching "the user changed their mind") rather than queuing both, but it's worth knowing about if a capture ever seems to silently not happen.
- **OCR/QR now unmaps and remaps this surface on every capture**, since clearing `resultText` in `_prepareCapture` (to avoid leaking a stale result into the next screenshot) also drives `root.visible` false until the new OCR/QR result arrives and writes `resultText` again. This should be behaviorally invisible (nothing here holds keyboard focus — no `Services.LayerFocus` on this surface — and the window was already toggling `visible` on `mode`/`resultText` before this change), but it's a genuine new code path worth watching for.
- **Untested — this is QML I cannot run** (`phi-shell/CLAUDE.md`: "You cannot run this. Every visual result is verified by the user with a screenshot").
- I did not do a wider "clean up the whole screenshot feature" pass beyond this bug and the dim-area-at-the-bar fix from earlier today (see below) — I read the rest of the file (recording, OCR, QR, clipboard-copy) looking for the same class of "our own UI/state leaks into the next operation" bug and found nothing else of that shape. If you had something more specific in mind for "clean up," say so and I'll take another pass.

### How to test it
1. Trigger an area screenshot (`qs ipc call screenshot area`, drag a selection, release). Open the resulting PNG (`~/Pictures/Screenshots` or `$XDG_PICTURES_DIR/Screenshots`) — it should show only the screen content under the selection, no pink/accent tint anywhere in it.
2. Trigger OCR on a selection (`qs ipc call screenshot ocr`), read the result panel, but **don't close it** — immediately trigger another OCR capture on a different area. The first result panel should NOT appear in the second capture's image, and the result panel should update to the new capture's text (not silently fail to update, not show both).
3. Trigger a fullscreen capture (`qs ipc call screenshot fullscreen`) right after leaving an OCR/QR result panel open from a previous capture — the saved PNG should not show that leftover result panel.
4. General regression check: window capture (`qs ipc call screenshot window`) and recording start/stop should behave exactly as before — these paths weren't buggy, just now also routed through the same hide-and-settle step (window capture) or untouched (recording, which was never affected).

---

## Autostart Hyprland on TTY1 login

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** 175e947 zsh: exec start-hyprland on tty1 login in the desktop profile
- **Original TODO:** start-hyprland should be automated on startup

### What was asked
Stop having to type `start-hyprland` by hand after every login.

### What was done
A new `profiles/desktop/home/.config/zsh/.zprofile` (desktop profile only —
`zotac` and `razer`; `mini` never receives it). As a login shell it execs
the Hyprland wrapper when it is the console login on TTY1 and no Wayland
session is already running:

```
[[ $(tty) == /dev/tty1 && -z ${WAYLAND_DISPLAY:-} ]] && exec start-hyprland
```

- **Why here:** phiOS has no display manager (Sec662 — agetty on a VT is
  the login screen), the zsh login chain reads `.zshenv` → `.zprofile` →
  `.zshrc`, and `ZDOTDIR=~/.config/zsh` is set in `.zshenv`
  (`profiles/base/home/.zshenv:1`). The `.zshenv` comment already named
  Hyprland as what the login shell inherits `PHI_DOTFILES` for.
- **Why `start-hyprland` and not the bare binary:** it is the hyprland
  package's own wrapper — imports the shell environment and starts the
  systemd-integrated session (portals), which is exactly what the install
  procedures already tell the user to run in step 13.
- **Why TTY1-gated:** a login on TTY2 (recovery, console work) stays a
  plain shell; an SSH login runs no TTY so is unaffected; `exec` means
  quitting the session drops you back to getty, so the compositor restarts
  cleanly on the next login.
- **Scoped deliberately:** this starts Hyprland only. `hyprland.lua`'s
  start hook already brings up phi-shell, hyprsunset and btop, and
  pipewire/wireplumber are persistent user units. No systemctl anywhere.

### Honest assessment
- The user still types their password on the TTY. Automating past the
  credential prompt would be a getty autologin drop-in (the architecture's
  §662 option A end-state, `profiles/…/system/` material applied by hand)
  — I treated that as out of scope since "on startup" was read as "once
  I'm logged in"; say the word if you want the full autologin instead.
- It is not applied until the next `phios-install` run, and the first
  compatibility check is real only on the next reboot — which I cannot do
  (machines are off-limits).
- If you ever need a plain shell on TTY1, log in on TTY2 (or press
  Ctrl+Alt+F2 from inside a session).

### How to test it
- Apply the new symlink: run `bin/phios-install --dry-run` and check it
  lists the `.zprofile` link, then run `bin/phios-install` (or just logout
  and re-login on TTY1 — `.zprofile` is read from the live `~`).
- Reboot (or logout and log back in on TTY1): instead of dropping to a
  prompt, the desktop should come up on its own. Before this change you
  had to type `start-hyprland` by hand.
- Inside the session, pressing the logout key (or `exit`ing the
  compositor) should return you to the getty login on TTY1.
- Sanity: log in on TTY2 (Ctrl+Alt+F2) — you should get a normal zsh
  prompt, no Hyprland.
- `mini` is unaffected: nothing was added to `base`, and a server host
  composes only `base` (+ `server`) profiles.

---

## Scratchpad toggle icon in the workspace strip

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** ea7a883 bar: add a scratchpad toggle at the end of the workspace strip
- **Original TODO:** add an icon icon in the list of desktop to toggle the hyprland scratchpad

### What was asked
Add a small icon at the end of the workspace list in the status bar that
toggles the Hyprland scratchpad (the same thing MOD+A does in
hyprland.lua).

### What was done
Two edits in phi-shell, both in the workspace strip module:

1. `Bar/modules/Workspaces.qml` — a `Widgets.Segment` (same isle style as
   the workspace digits: squared, bare glyph on the wallpaper) appended to
   the strip's `Row`, after the workspace Repeater. Clicking it calls
   `Services.HyprlandBridge.dispatch("togglespecialworkspace scratch")` —
   the same `special:scratch` workspace `hyprland.lua` toggles with MOD+A.
   Uses the compositor's own IPC socket, no subprocess.

2. `Bar/glyphs.js` — added `glyph: Glyphs.console` (nf-md-console).

**Deliberately no active-state highlight.** ADR 134 records why the old
specialWorkspaces module failed: a numeric workspace and the special one
could both read as "active" at once, so a lit toggle lied half the time.
This button only ever dispatches; it never claims to show whether the
scratchpad is open.

### Honest assessment
- The nf-md-console codepoint is unverified against the font on hardware —
  the existing glyphs.js entries carry the exact same caveat ("renders as
  a box on real hardware" = one-line fix). If it shows a box, swap the
  codepoint.
- No state indicator (by design, see above). If you want a "scratchpad is
  open" light, it needs a correctly-detected monitor/visibility signal,
  not the workspace `active` flag.
- QML not runnable here; syntax verified by eye against the adjacent
  delegate.

### How to test it
- The shell hot-reloads on save in that directory; otherwise restart with
  `pkill -x qs; qs -p ~/.config/quickshell/phi`.
- On the bar, look at the right end of the numbered workspace strip: a
  console glyph button should sit after the workspace digits.
- Click it: the scratchpad window (or empty special workspace) should
  appear/disappear, exactly like pressing MOD+A. Press MOD+A and confirm
  the button does the same.
- Send a window there: focus a window and press MOD+SHIFT+A, then click
  the button — the window should appear. Click again — it should hide.
- The glyph should render as an icon, not a replacement box (□).

---

## Screenshot: dim area no longer trimmed below the status bar

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** f31cc43 screenshot: raise the selection overlay to WlrLayer.Overlay
- **Original TODO:** when applying an area screenshot, the dim area is trimmed below the status bar

### What was asked
When selecting an area to screenshot, the dimmed backdrop doesn't reach the strip where the status bar sits — it looks cut off / trimmed right at the bar.

### What was done
`Screenshot/Screenshot.qml`'s `PanelWindow` was never raised off the default `Top` layer-shell layer — every other modal-style overlay in this repo (`Settings.qml`, `Launcher.qml`, `Cheatsheet.qml`, `AltTab.qml`, `Sidebar.qml`, `AgentPanel.qml`) explicitly sets `WlrLayershell.layer = WlrLayer.Overlay` in its own `Component.onCompleted`, and this file was the one outlier. On the default `Top` layer, the bar's own `exclusiveZone` (`Bar/Bar.qml`: reserves `bar.height` while not auto-hidden) reduces this surface's *available region* to stop short of the bar strip — this is a region/geometry effect, not a z-order occlusion, so neither the dim `Widgets.Scrim` nor the selection `MouseArea` could ever reach that strip at all (you also couldn't drag a selection starting there). `AltTab/AltTab.qml` already carries a header comment documenting the identical symptom and fix on real hardware: "raised to `WlrLayer.Overlay` + `exclusiveZone -1` ... so the dim covers the status bar too" — this commit applies the same pairing (both the layer bump AND `exclusiveZone: -1`, not the layer alone) to `Screenshot.qml`.

`Screenshot/ColorPicker.qml` (the separate colour-picker surface, no TODO entry of its own) had the identical gap — same `PanelWindow` shape, same missing layer bump, same consequence (a click anywhere under the bar strip couldn't reach its `MouseArea`). Fixed in the same commit rather than left for a second bug report, since it's the exact same one-line pattern.

The grim capture geometry math itself (`root.screen.x/y + selectionRect...`, already hardware-verified separately — see below) is untouched and unaffected: `root.screen` reflects the Wayland output's own bounds, not this surface's available region, so this change only extends how much of that output the selection UI can actually reach and dim.

### Honest assessment
**Untested — this is QML I cannot run** (`phi-shell/CLAUDE.md`: "You cannot run this. Every visual result is verified by the user with a screenshot"). The whole mechanism here is compositor region allocation (how Hyprland divides output space between layer-shell surfaces based on `exclusiveZone`), which I can reason about from this repo's own prior hardware-verified fixes (`AltTab.qml`'s identical case) but cannot verify myself.

**One thing worth specifically checking:** before this fix, the selection `MouseArea` could never reach the bar strip, so a drag starting *at* the very top of the screen was never exercised there. With `exclusiveZone: -1`, that's now possible. The grim math should handle it correctly (it's output-relative, not region-relative), but it's the one way this change could surface a latent offset bug — worth a test.

**Found, not touched: the OCR/QR offset TODO looks already fixed.** While reading this code I found `df4298d` ("fix: verification round 2 (screenshot offset, spotlight, launcher, chroma)"), already on `dev`, authored directly by you. Its message quotes the exact symptom from the other open TODO entry ("area selection in screenshot, OCR and QR reading is never right. The offset changes as the size and position of the area change") almost verbatim, and the fix (removing an incorrect `devicePixelRatio` multiplication in the same `_captureGeometry` calculation this task's code sits next to) reads as a direct, hardware-verified fix for it. I didn't touch that TODO entry or do any work toward it — since I didn't do that work, it's not mine to close out — but it looks stale. Worth checking whether it's already resolved for you and can just be deleted.

### How to test it
1. Trigger an area screenshot (`qs ipc call screenshot area`, or whatever keybind/launcher entry triggers it) and start dragging a selection so it visually overlaps where the status bar sits.
2. Before this fix: the dim backdrop stops short right at the bar, leaving that strip undimmed/uncovered. After: the dim should extend all the way to the true top edge of the screen, behind/through the bar strip too.
3. Drag a selection that starts exactly at the very top edge of the screen (in the bar's strip) and release. Open the resulting PNG (in `~/Pictures/Screenshots` or `$XDG_PICTURES_DIR/Screenshots`) and confirm its top edge lines up with where you started dragging, not with where the bar visually ends.
4. Trigger the colour picker (`qs ipc call colorpicker pick`) and click a pixel under/near the bar strip — before this fix that click could not be registered at all; after, it should read and copy that pixel's hex value normally.

---

## ESC closes the agent panel, but blurs a focused field first

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** b2ad3fc agent-panel: close on Escape when nothing inside has focus
- **Original TODO:** ESC key should close open overlays and panels. Sometimes ESC might just remove focus from an element (eg. The chat text field) so it should only close a panel if nothing is focuses inside of them

### What was asked
Escape should close open overlays/panels in general, but for a panel with a text field inside (the chat text field is the named example), Escape should not blow away what you're doing — it should just remove focus from the field first, and only close the panel once nothing inside it is focused.

### What was done
Scoped to `Panels/AgentPanel.qml` (Dashboard / Chat / Coding sessions / Memory proposals), because it's the literal named example and, before this change, it had **no** Escape handling anywhere — not even a blur. Pressing Escape while typing a chat message did nothing at all.

- `Widgets/TextField.qml` (the one shared text-entry widget, used by Dashboard's project-name/search fields, ProjectView's instruction/material/folder fields, and PersonalityEditor's name field) now blurs on Escape instead of ignoring it, and emits a new `escaped()` signal. Escape also suppresses the field's own `committed(text)` signal — Qt's `TextInput.editingFinished` fires on *any* focus loss, not just Enter, so without an explicit guard, Escape would have silently committed whatever half-typed text was in the field (a partial hex color reaching `Config.ThemeOverrides`, a partial path reaching a firewall rule). Escape now means cancel, not commit.
- Chat.qml's message field, ProjectView's description field (a `TextEdit`, not the shared widget), and PersonalityEditor's system-prompt field are raw `TextInput`/`TextEdit` (not `Widgets.TextField`), so each gets the same local blur-then-signal treatment directly.
- `AgentPanel.qml` gets a `keyScope` item mirroring `Overview.qml`'s own precedent (`grid { focus: root.shown; Keys.onEscapePressed: root.setShown(false) }`): it holds keyboard focus by default and closes the panel on Escape. A field that's clicked into outranks it while focused; when that field blurs itself on Escape, a chain of re-emitted signals (through Dashboard → ProjectView → PersonalityEditor, and Dashboard/Chat directly) tells `keyScope` to reclaim focus explicitly, so the *next* Escape closes the panel. `focus: root.shown` alone isn't enough to guarantee this — QML doesn't restore a binding once something else has broken it by taking focus — so `onShownChanged` and `onSectionChanged` also call `keyScope.forceActiveFocus()` imperatively, the same belt-and-braces shape `Overview.qml`'s `setShown()` already uses for its own grid.

### Honest assessment
**Settings is affected too, deliberately.** `Widgets/TextField.qml` is also used by `Settings/sections/{Theme,Keybindings,Connectivity,Notifications}.qml` (colour pickers, thresholds, VPN import, firewall rules, etc.). Those fields now blur on Escape as a side effect. This does not change any close behavior in Settings — clicking into one of those fields already steals keyboard focus away from `Settings.qml`'s own always-focused search field, so Escape already did nothing there before this change; now it blurs the field instead of doing nothing. Worth checking on real hardware: type a partial hex into a Theme colour field and press Escape — the colour should **not** change (this was the main risk in this change and is the thing I'd most want confirmed).

**Left alone on purpose — six panels that already close directly on Escape:** Settings, Launcher, Clipboard, ColorPicker (screenshot), Overview, and Cheatsheet all auto-focus a search field the instant they open (`Settings.qml:58` and `Clipboard.qml:155` both call `forceActiveFocus()` on open) and close immediately on Escape from that field. That's correct as-is for a launcher-style single-purpose field — a two-stage blur-then-close model there would mean Escape never closes on the first press, which would read as broken, standard launcher UX (macOS Spotlight, etc.) closes on the first Escape. I did not touch these.

**Left alone on purpose — no keyboard focus at all:** `BarPopout.qml`, `Calendar.qml`, `Spotlight.qml`, and `Magnifier.qml` have no `Services.LayerFocus` and accept no keyboard focus today (they're mouse/gesture-driven popouts). Wiring Escape into them means granting them keyboard focus in the first place, which would steal keys from whatever app the user is actually in when they click a bar icon (volume, brightness, wifi, etc.) — a materially different, riskier change than this task, left out.

**Untested — this whole file is QML I cannot run** (`phi-shell/CLAUDE.md`: "You cannot run this. Every visual result is verified by the user with a screenshot"). The focus-reclaim logic (`keyScope.forceActiveFocus()` on shown/section-change, and the re-emitted `blurred()`/`escaped()` chain through five files) is reasoned through carefully and modeled directly on `Overview.qml`'s own hardware-verified precedent, but it has several moving parts across `AgentPanel.qml`, `Chat.qml`, `Dashboard.qml`, `ProjectView.qml`, and `PersonalityEditor.qml` that only a real run can fully confirm.

### How to test it
1. Open the agent panel (Super+P, or the bar's Φ segment), on the Dashboard section, with no field clicked into. Press Escape → the panel should close.
2. Reopen, switch to the Chat section, click into the message field, type a few characters. Press Escape once → the field should lose its cursor/focus ring, the panel should stay open, and your typed text should still be there (not sent, not cleared). Press Escape again → the panel should close.
3. Reopen, click into the Chat field again, then click the "Dashboard" item on the left nav rail (switching sections while the field has focus). Press Escape → the panel should close (this exercises the `onSectionChanged` reclaim — without it, Escape would silently do nothing here).
4. Reopen, click into the Chat field, then close the panel by clicking outside it (not with Escape). Reopen the panel and immediately press Escape → the panel should close (this exercises the `onShownChanged` reclaim — without it, Escape would be permanently dead after this sequence until you clicked a field and pressed it twice).
5. Open Dashboard → a project → Settings gear "Edit / new…" personality, or any of the instruction/material/folder/project-name fields; click in, type, press Escape → the field should blur without saving/adding anything, and a second Escape should close the panel.
6. Open Settings → Theme, click into a colour field (hex input), type a partial value (e.g. "#a1"), press Escape → the field should lose focus and the actual theme colour should **not** change to anything derived from "#a1". This is the regression check for the commit-suppression fix.

---

## Alt+Tab: fix stale active-window selection race

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 2432ecc alttab: guard against stale active-window responses
- **Original TODO:** alt+tab does not work: when releasing alt it does not select the window nor it closes the overview. When clicking a windows in the overview it does not select it. It's always the first window to be selected when opening the overview, not the actual active one.

### What was asked
Three symptoms bundled in one report: (1) releasing Alt neither confirms the selection nor closes the overview, (2) clicking a window in the overview doesn't select it, (3) the overview always opens with the first window selected rather than the actually-active one.

### What was done
Only symptom (3) is addressed. Reading `AltTab/AltTab.qml`, the active-window lookup (`_applyStartSelection`) is asynchronous — it takes two `hyprctl` round-trips (`clients -j` then `activewindow -j`) — while `_selectStartWindow` already sets a provisional `flat[0]` selection the instant the client snapshot lands, so the overview never opens with nothing selected. That gap contains two real, hardware-independent races, either of which leaves the provisional `flat[0]` standing instead of the asynchronously-computed "next after active" window: a fast second Tab press (`_cycle()`) firing before `activeProc` returns, and Alt being released (`_close()`) before `activeProc` returns. Fixed by adding a `_snapshotSeq` sequence counter (bumped in `_open()`, tagged onto each `Process` via a `forSeq` property) and a `_userMoved` flag (set once the user actually cycles), so a late `activeProc` response is applied only if it's for the current open and the user hasn't already moved the selection themselves — the same shape as `Launcher.qml`'s existing `queryProc.queryArg === root.queryText` staleness guard. Also cleared `selectedAddress` in `_close()` so reopening on the same window set doesn't briefly show the previous session's selection before the async lookup corrects it.

### Honest assessment
Symptoms (1) and (2) were **not** fixed — deliberately left. Both look compositor-level: `focuswindow address:` (the mechanism the overview's click-to-select would use) is already proven working elsewhere in this codebase via `Launcher.qml`'s `activateWindow` action, and the Alt-release/confirm bind was already moved to the global keymap with `submap_universal` in a prior hardware-verified round of fixes, referencing a real upstream bug (hyprwm/Hyprland#15785) about modifier-release not firing inside a submap when the modifier was held from before entering it. Neither can be diagnosed further from source reading alone; both need the real machine (`phi-shell/CLAUDE.md`: "You cannot run this").

For symptom (3): the two races fixed here are real, but I want to be upfront that they may not be the exact mechanism behind the report. Losing either race requires a second Tab press or an Alt release to land inside a single-digit-millisecond window (a local `hyprctl` round-trip), which is fast even for a quick gesture. So this is a genuine bug fix, not a confirmed diagnosis of "always the first window" — if the symptom persists after this lands, the cause is elsewhere (most likely also compositor-level, alongside 1 and 2).

### How to test it
1. Open several windows across more than one workspace.
2. Hold Alt and tap Tab twice quickly (second tap before you'd expect any visible delay) to cycle to a specific window, then release Alt.
   - Before the fix, a late `hyprctl activewindow` response could silently snap the selection back to whatever was active before opening — check that the confirmed window is the one you cycled to, not a different one.
3. Open the overview fresh (Alt+Tab once, no extra taps) on a window set where the currently-active window is not first in `hyprctl clients -j` order, and confirm the overview highlights the actually-active window's neighbor (the "next after active" window) rather than always the first item in the list.
4. Symptoms (1) Alt-release not confirming/closing and (2) click-to-select not working are unchanged by this commit and still need to be checked/reported separately on real hardware.

---

## Full-content preview on clipboard hover / selection dwell

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** 6637efe clipboard: show a full-content preview on hover or selection dwell
- **Original TODO:** clipboard should show an overlay with the complete command and extra informations when the selection is held for a while (or on mouse hover after some time)

### What was asked
When an entry in the clipboard tab is "held" — dwelt on — a preview should
appear showing the complete, untruncated content plus extra information
beyond what the card itself shows (the card truncates to 2 lines and only
shows a minute-resolution timestamp). The TODO names two ways to trigger
it: holding the selection, or hovering the mouse for a while.

### What was done
Read "the selection is held" as the *keyboard* selection
(`highlightedIndex`) sitting still for a while, not a mouse press-and-hold
— this file's own header says the search field always holds focus and the
list itself never does, so there's no separate per-row focus a press could
"hold." A long-press gesture was considered and deliberately not built:
Qt's `TapHandler` still fires `tapped()` on release even after
`longPressed()` has already fired for the same press, so a long-press
would also need to suppress the existing tap-to-copy-and-close afterward —
exactly the kind of interaction-timing behaviour this environment cannot
verify, and getting it wrong risks breaking the working copy action, not
just the new feature.

So there are two triggers, both driving the same dwell: the mouse
hovering a card (a new `HoverHandler` per entry, added alongside the
existing `TapHandler`s without conflict), or, when nothing is hovered, the
keyboard-highlighted entry. Either one changing restarts a 700ms timer
(`previewDelay` — an undocumented placeholder, the same way the shell's
existing but unused `Tooltip.qml` component has its own placeholder
`delay: 500`); once it fires, a panel fades in (using the same motion
category — B, "state transition... high frequency" — already used for
every other panel/drawer fade in this shell) showing:
- the complete text, read from disk on demand (the in-memory entry list
  only ever carried the first line — Services/Clipboard.qml's own header
  says so), capped at 4000 characters with a "truncated" note past that,
  since these are raw clipboard dumps and an unbounded paste landing in a
  `Text` item is a hang, not a cosmetic overflow;
- an actual image thumbnail for an image entry, not just "[image]";
- an exact (seconds-resolution) timestamp, the mime type, and pinned
  status.

**Positioning is a deliberate deviation from "overlay near the item."**
The natural reading of "overlay" is a small popup next to the hovered row,
but each card lives inside a scrolling, clipped `Flickable`, and
positioning something outside that clip at the *correct, scroll-aware*
coordinate needs `mapToItem` math against a moving target this
environment has no way to verify. Instead the preview is anchored to the
tab's own bottom edge, covering the bottom portion of the list while
shown — the same shape `Launcher.qml`'s already-shipped `richWrap` uses
(a fixed anchor beside a fixed reference point, not a per-row floating
tooltip), reused here for the same reason: it's the one form of "show
detail alongside the list" this session has already gotten right.

Also wired into the same-session clipboard reset fix: `reset()` (which
clears stale search/selection state on reopen) now also clears the
preview's own state, for the same reason that fix existed — a value with
visible state that survives a close/reopen looks broken.

### Honest assessment
- **Not visually verified** — phi-shell's own rule applies here as it did
  to every other change this session. Specifically unseen: whether the
  overlay covering roughly the bottom half of the list (rather than
  floating beside the hovered row) reads as intentional or as a mistake in
  practice — if it reads wrong, the fix is to build the `mapToItem`
  version this entry deliberately avoided, not a small tweak.
- 700ms may feel like the wrong dwell length either way; it's a guess, not
  a measured value, same as `Tooltip.qml`'s own placeholder.
- Rapid arrow-key navigation through the list triggers a 120ms fade-out
  per keypress (the dwell timer restarts before the fade-in threshold, so
  the overlay never actually shows, but the *opacity Behavior* still fires
  toward 0 on every change). Reasoned to be in-category (B is specifically
  documented for "high frequency" events) rather than a violation of the
  "category-C effect on a frequent event is a bug" rule, but not seen in
  practice.
- Two implementation bugs were caught and fixed during review, before this
  was committed, not shipped and left for the user to find: a click-
  swallowing `MouseArea` on the preview panel (mirroring a pattern used
  elsewhere in this shell) would also have swallowed *hover*, causing the
  overlay to flicker show/hide in a loop right under the cursor — removed
  before commit. The image thumbnail's height was first computed as
  `Math.min(implicitHeight, ...)`, which doesn't actually cap the
  rendered size (`implicitHeight` is the source image's pixel height, not
  the size it scales to) — fixed to a plain fixed height with
  `PreserveAspectFit` doing the scaling.
- An empty `FileView.path` (when nothing should be previewed) is assumed
  to fail harmlessly via `onLoadFailed` rather than error loudly — not
  confirmed against a real Quickshell runtime, though this is a low-risk,
  low-consequence assumption if wrong (worst case: a benign warning).

### How to test it
1. Build `phi-shell` from this branch and reload Quickshell (`pkill -x qs;
   qs -p ~/.config/quickshell/phi`), or save any `.qml` file to trigger
   its hot reload.
2. Open the panel onto the Clipboard tab (`Super+Shift+V`) with at least
   one entry whose content is longer than what the card shows (more than
   2 lines, or just a long line).
3. Move the mouse over that card and hold it still for a bit under a
   second — confirm a panel fades in from the bottom of the tab showing
   the complete text (not truncated), an exact date/time with seconds, the
   mime type, and pinned status if pinned.
4. Move the mouse away — confirm the panel fades back out (falling back to
   whichever entry is keyboard-highlighted, after another short dwell, if
   that's a different entry).
5. Without touching the mouse, use the arrow keys to move the keyboard
   selection to a different entry and leave it there for a bit under a
   second — confirm the same preview panel appears for that entry.
6. Copy an image to the clipboard (a screenshot, or copy an image in a
   browser) so an image entry appears — hover or select it and confirm the
   preview shows an actual thumbnail image, not just the card's "[image]"
   placeholder text.
7. Close the panel and reopen it onto the Clipboard tab again — confirm no
   preview is showing immediately; it should only reappear after hovering
   or dwelling again, same as the first time.

---

## Align tailscale/vpn overlay and connectivity buttons

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** c2534c0 shell: align popout buttons and connectivity spacing
- **Original TODO:** tailscale/vpn overlay should align its content better. Connectivity as well (especially the buttons)

### What was asked
The tailscale/VPN overlay (the "network" popout under the bar) and the
Connectivity settings section have content and buttons that look
misaligned. Buttons in particular.

### What was done
Two sets of fixes in phi-shell:

1. **`Panels/BarPopout.qml`** — every `SmallButton` in the popout sections
   (volume "Sound settings…", brightness "Display settings…", wifi
   "Manage networks…" / "Show in settings…", bluetooth "Manage
   devices…" / "Show in settings…", network "Show in settings…") now has
   `width: parent.width`. Previously they rendered at natural content
   width, left-aligned, floating under the full-width `ListRow` /
   `ToggleRow` rows above them — the network (tailscale/VPN) card was the
   worst case with a single orphaned small button. Now every button
   stretches to the card width and aligns flush with the rows above.

2. **`Settings/sections/Connectivity.qml`** — the four hardcoded `spacing:
   4` / `spacing: 6` (bluetooth device list, the VPN import row, the
   firewall "Open ports" column, the "Recently blocked" column) were
   replaced with `root._gap` (the section's 2ch rhythm already used
   everywhere else in the same file). This makes the button rows and
   lists share one consistent vertical rhythm.

### Honest assessment
I could not view the reference images (the model has no image input) and
cannot run the compositor, so the fix is based on code reading, not on a
screenshot. The most visible change is the popout buttons stretching to
full card width — that is a deliberate visual change, and if the desired
look was compact left-flushed buttons instead, it can be reverted. The
spacing unification only affects the four named columns in the
Connectivity section; `Theme.qml` and other sections retain their own
hardcoded small spacings (out of scope here). QML is not compiled in
this environment; syntax is trivially verifiable by eye, but a runtime
QML parse error is only checkable on the machine.

### How to test it
- Reload the shell (Quickshell hot-reloads on save; otherwise restart the
  session) so the new QML is live.
- Click the network bar button to open the tailscale/VPN popout: the
  "Show in settings…" button at the bottom should now span the full card
  width, aligned with the Tailscale and VPN rows above it.
- Open the volume/brightness/wifi/bluetooth popouts: each section's
  buttons should likewise span the full card width.
- Open Settings › Connectivity: vertical gaps inside the bluetooth list,
  the VPN import row, the "Open ports" column and the "Recently blocked"
  list should be even and match the pitch of the rest of the section
  (previous: two visibly tighter pitches, 4px and 6px).
- If the shell fails to load (black screen / no bar), tell me — a QML
  parse regression is possible and must be fixed.

---

## Make printed manual steps copy-pasteable

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / master
- **Commits:** 1c5a4cd install: drop profile suffix from printed manual steps
- **Original TODO:** Manual steps: remove the "(base)" as i can't copy-paste-run

### What was asked
The installer prints manual steps annotated with the owning profile as a
trailing suffix, e.g. `  sudo install -Dm644 .../issue /etc/issue  (base)`.
Pasting such a line fails because bash parses `(base)` as a subshell
running the command `base`. The suffix must go so the printed steps are
directly runnable.

### What was done
`phios_manual_report()` in `bin/lib/system.sh:107` now prints each step
bare (`printf '  %s\n' "$step"`), dropping the `  (%s)` profile suffix.
The root cause was in the installer, not in the manual.txt files — those
were already clean. Only the manual-steps emitter was touched; the
services and "no longer declared" reports keep their suffix because they
print unit/file names, not runnable commands. The profile variables and
loop order are unchanged, so the section order is still deterministic.

### Honest assessment
Clean and minimal. One behaviour to be aware of: with the suffix gone,
the printed manual-steps output no longer shows which profile each step
came from. Commands are self-contained paths so this is a cosmetic loss,
and it is exactly what the user asked for. I chose not to also strip the
same suffix from the services report (`system foo.service (base)`), since
those lines are unit names, not paste-to-run commands; say the word if
the consistency matters.

### How to test it
- From any machine with the dotfiles checkout,
  run `bin/phios-install --dry-run` (read-only, touches nothing).
- In the `manual steps` section of the output, confirm every line is now
  the bare command with no trailing `(base)`-style suffix.
- Copy one of those lines into a shell and run it — it must not fail with
  a `base: command not found` / subshell parse error.

---

## Make overlay button borders visible

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / master
- **Commits:** 34e8d91 design: increase borderWidth from 1px to 2px for visible button borders
- **Original TODO:** the overlay use the buttons with borders that are notte visible, so the text appears not aligned.

### What was asked
Buttons in the overlay panels ("the overlay") have borders that are barely
visible, which makes the text inside them look misaligned. The borders
should be perceivable.

### What was done
Changed `PHI_BORDER_WIDTH` in `phios-dotfiles/design/tokens.common.sh` from
`1px` to `2px`. This is the token consumed by StyledButton, SmallButton
(chrome states), Segment, TextField, Toggle and every other stroke-width
consumer, so the fix is global and stays inside the token system. No QML
or widget code changed.

### Honest assessment
This width token also affects non-overlay controls (toggles, text fields,
the launcher, the lock screen). The user's complaint was specifically
about the overlay buttons, but the token is intentionally global ("a
universal UI constant"), so a whole-class change was the least invasive
fix within the rules. If 2px feels too heavy elsewhere, the alternative
is a button-specific border token — but that would overrule the
deliberate universality documented at that token. The perceived
misalignment itself is unchanged (text stays centred in the full
control); a wider border is expected to make the outline read correctly.
Cannot verify visually without a running compositor.

### How to test it
- Run `phi theme set dark` (or `phi theme set light`) to regenerate
  `Config/Tokens.qml` from the updated tokens.
- Open any overlay panel that has buttons (notification sidebar, a bar
  popout like volume/brightness, the agent panel).
- Buttons that previously had a 1px hairline (or none, for SmallButton at
  rest) should now show a clearly visible 2px outline.
- Check that text inside buttons still looks aligned to the border.
- Also glance at non-overlay controls (toggles in Settings, launcher) for
  any regressions from the wider stroke.

---

## Reduce overlay panel gap from status bar

- **Date:** 2026-09-11
- **Repo / branch:** phios-dotfiles / master
- **Commits:** 57e0595 design: reduce panelGap from 4px to 2px
- **Original TODO:** overlay panels are still way too distant from the status bar: they should be few pc below the bar

### What was asked
The overlay panels (sidebar, agent panel, calendar, bar popouts) sit too
far below the status bar. The user wants them closer — "few pc below the
bar."

### What was done
Changed `PHI_PANEL_GAP` in `phios-dotfiles/design/tokens.common.sh` from
`4px` to `2px`. This is the single design token that all four overlay
panels read for their `anchors.topMargin` offset below the bar's visible
content bottom. No QML logic was changed — the panels already consume the
token correctly via `Services.BarMetrics.contentBottom +
Config.Appearance.panelGap`.

### Honest assessment
Clean. The change is data-only (one token value). The four panels all
consume the same token so the fix is uniform. Cannot verify visually
without a running compositor — needs `phi theme set dark` (or light) on
hardware to confirm the gap looks right.

### How to test it
- Run `phi theme set dark` (or `phi theme set light`) to regenerate
  `Config/Tokens.qml` from the updated tokens.
- Open any overlay panel (e.g. notification sidebar, bar popout, calendar).
- Visually confirm the panel top edge sits closer to the bar's drawn
  content than before (previously ~8 logical px at 2× scale, now ~4 logical
  px).
- The gap should be small but present — panels should not touch the bar.

---

## Shrink the launcher to fit its results, top edge held fixed

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** c778f51 launcher: shrink to fit the result count, top edge held fixed
- **Original TODO:** the runner should resize it's height when there are not enough options to fill it. (Anchored on the top)

### What was asked
The launcher box always opens at its full ~20-row height, even for a query
with only one or two matches — a tall mostly-empty box below a short
result list. It should shrink to fit however many results there actually
are, and do so without the box's top edge (where the search field sits)
moving — only the bottom edge should move as the height changes.

### What was done
This reverses a deliberate earlier decision (OOP-12, in the historical
log): the box used to be a fixed height specifically "so the box opens at
full height and never grows/shrinks as results change." The TODO entry is
the newer instruction on the same question, so `Launcher/Launcher.qml`'s
comments were updated to say so explicitly, not just changed silently.

The result list (`resultFlick`) now sizes to
`root.currentListBoxHeight`, which is `resultList.implicitHeight` (however
many rows are actually showing, or the "no results" label's height, or 0
when nothing is shown) capped at the unchanged `maxListBoxHeight` — the
same ~20-row / 62%-of-screen limit as before, so a full or near-full
result set renders exactly as it did previously.

The harder part was the "top edge held fixed" half. The box
(`panelWrap`) is centred on screen via `anchors.verticalCenter`; before
this change its height was bound to the visible panel's own height, so a
shorter panel would re-centre and its top edge would drift downward.
Fixed by decoupling the two: `panelWrap`'s height is now pinned to
`root.maxPanelHeight` (the box's full height at maximum size, used only
for this positioning calculation — panelWrap itself draws nothing), while
the visible `panel` still sizes to its own, possibly smaller, actual
content and sits explicitly at `panelWrap`'s top edge
(`anchors.top: parent.top`, made explicit — it previously relied on the
Item default of (0, 0), which was harmless before because panelWrap and
panel were always the same height). Two other places that assumed
panelWrap's bounds matched the visible panel's needed the same fix:
`panelWrap`'s own click-swallowing `MouseArea` (now sized to `panel.height`
instead of filling all of the now-taller `panelWrap`, so a click just
below a shrunk box still falls through to close the launcher, as a click
outside it should) and the rich-result card's narrow-screen anchor (now a
`panelWrap.top` anchor with `panel.height` folded into the top margin,
since `richWrap` is a sibling of `panelWrap`, not of `panel`, and QML only
allows anchoring to a parent or a sibling — an actual bug hit and fixed
during review, not a hypothetical).

Checked one interaction before treating this as safe: `setShown(false)`
(the launcher's close path) already clears `queryText` alongside
`results`, so reopening the launcher always starts in browse mode (every
installed app, alphabetically — a long list) rather than a leftover
empty-results state that this change could otherwise have turned into a
visible "sliver" on reopen. No change was needed there.

### Honest assessment
- **Not visually verified** — phi-shell's own rule: "you cannot run this,"
  every visual result needs the user's own screenshot. This is layout/
  anchoring logic, reviewed by tracing the QML by hand (including
  confirming `Widgets/Panel.qml` really is a plain, non-self-anchoring
  `Item`, and that the rich-card anchor change above is legal QML — an
  earlier draft of this fix anchored `richWrap` directly to `panel.bottom`,
  which is illegal since they aren't parent/sibling; caught before
  committing, not left as a shipped bug), not by running it.
- Specifically worth checking on hardware: (1) with a short result list,
  does the box's search field visibly stay in the same screen position as
  it does with a long one, only the bottom edge moving; (2) with a short
  result list on a narrow screen, does the rich-result card (when a
  calculator/plot result is highlighted) sit right below the shrunk box,
  not floating with a gap where the old full-height box used to end; (3)
  clicking just below a shrunk box should close the launcher, not swallow
  the click.
- `PROGRESS.md` was not updated — §5's Launcher row is architectural
  ("Launcher — a renderer only...") and doesn't change with this fix; this
  is the fourth commit in this session's run that didn't touch it, noted
  here explicitly rather than left silent.

### How to test it
1. Build `phi-shell` from this branch and reload Quickshell (`pkill -x qs;
   qs -p ~/.config/quickshell/phi`), or save any `.qml` file to trigger
   its hot reload.
2. Open the launcher (`Super` or whatever it's bound to) with nothing
   typed — confirm it looks exactly as before: full height, browsing every
   installed app.
3. Type a query that matches only one or two things (a specific app name,
   or an arithmetic expression like `2+2`). Confirm the box is now short —
   just tall enough for those few rows — rather than a tall box with empty
   space below the results.
4. While that short box is showing, note where its top edge (the search
   field) sits on screen. Clear the query back to nothing (full list) and
   back to the short query again — confirm the top edge is in the same
   place both times; only the bottom edge should have moved.
5. On a narrow window/screen, highlight a calculator result (e.g. type
   `2+2`) so the rich-result card appears — confirm it sits directly below
   the (now short) box, not with a gap.
6. Click in the empty space just below a shrunk box (where the box used to
   extend to before this fix) — confirm the launcher closes, the same as
   clicking anywhere else outside it.

---

## Reset the clipboard tab every time the panel opens

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** ccf5477 clipboard: reset selection, filter and scroll every time the panel opens
- **Original TODO:** clipboard should reset the current selection every time it's opened, starting back from the top.

### What was asked
Every time the notification panel is opened on the Clipboard tab, it
should start from a clean state: no leftover search filter, the first
entry selected, scrolled to the top — not whatever was left over from the
last time it was open.

### What was done
Found the cause in `Panels/Sidebar.qml`: the tab content is a `Loader`
whose `sourceComponent` only changes when the active tab index changes —
opening and closing the whole panel just toggles `PanelWindow.visible`
upstream, it does not touch the Loader, so the Clipboard tab's `Item` is
never destroyed by a plain show/hide. That means `Component.onCompleted`
(where the reset already happened) only ever ran the very first time the
Clipboard tab was opened in a session; every later reopen — panel closed,
then reopened while still parked on that tab — kept the old search text,
selection and scroll offset.

`Panels/tabs/Clipboard.qml`: moved the existing reset logic into a
`reset()` function, called from `Component.onCompleted` as before, and
now also from a `Connections { target: Services.NotificationPanel;
function onShownChanged() { ... } }` block that fires on the `shown`
transition to `true` — the same `Connections`/`onXChanged` shape already
used the same way in `Settings.qml`, `Spotlight.qml` and `Launcher.qml`,
so nothing new was introduced stylistically. Also added `list.contentY =
0` to the reset (`list` is the id given to the entry `Flickable`, which
previously had no id) — nothing previously reset the scroll position, only
`highlightedIndex`, so "starting back from the top" was only half true
even within a single session.

### Honest assessment
- **Cannot verify visually** — phi-shell's own rule: "you cannot run
  this," every visual result needs the user's own screenshot. This is a
  logic fix (state reset on a property-changed signal), not a visual one,
  so it was reviewed by reading the surrounding code and cross-checking
  the `Connections` pattern against four other files that already use it
  the same way, not by running it.
- One behaviour to be aware of, not a bug: opening the panel straight onto
  the Clipboard tab (`Super+Shift+V`, which sets the tab index *and*
  `shown` together) can run `reset()` twice in a row (once from
  `Component.onCompleted` as the Loader creates the item, once from the
  `Connections` handler as `shown` becomes true right after) — harmless
  since `reset()` is idempotent, just a redundant `Services.Clipboard.refresh()`
  call, not a state problem.
- Switching tabs away from Clipboard and back while the panel stays open
  already reset correctly before this change (a tab switch gives the
  Loader a new `sourceComponent`, so a fresh `Item` is created either
  way) — untouched by this fix, still works the same way.

### How to test it
1. Build `phi-shell` from this branch and reload Quickshell (`pkill -x qs;
   qs -p ~/.config/quickshell/phi`), or just save any `.qml` file to
   trigger its hot reload.
2. Copy two or three different things to the clipboard so there's more
   than one entry.
3. Open the panel onto the Clipboard tab (`Super+Shift+V`), type a few
   characters into the filter box, and press Down/Tab a couple of times so
   a later entry (not the first) is highlighted.
4. Close the panel (click outside it, or `Super+N`) without selecting
   anything.
5. Reopen it onto the Clipboard tab again (`Super+Shift+V`). Before this
   fix: the filter text and the previously-highlighted entry were still
   there. After this fix: the filter box is empty, the first entry
   (topmost, pinned entries first) is highlighted, and if the list had
   been scrolled, it is back at the top.

---

## Recognise phi verbs in the launcher without the "phi " prefix

- **Date:** 2026-09-11
- **Repo / branch:** phi / dev
- **Commits:** 3e7d49a query: recognise phi's own verbs without the leading "phi "
- **Original TODO:** runner bar should read phi commands without writing the phi prefix (eg. "theme set dark" is recognised as "phi theme set dark")

### What was asked
Typing a `phi` verb straight into the launcher, e.g. `theme set dark`,
should be recognised as if `phi ` had been typed first, and offered as a
result that runs `phi theme set dark`.

### What was done
Added `PhiCommandProvider` (`internal/query/phicommand.go`): it fires when
the query's first word matches one of phi's own verb names, and offers a
result whose action runs `phi <the whole query>` in a terminal — the same
`ActionExecTerminal` action `CommandProvider` already uses for "phi theme
set dark" typed in full (so it fires because `phi` itself resolves as a
PATH binary), so output stays visible either way.

The verb list comes from `view.Commands` — the single list `phi help`,
zsh completion and the man page already render from — so a verb added
there needs nothing else touched. It's passed in by `internal/cli` rather
than imported straight into `internal/query.Providers`, because
`internal/view` already imports `internal/query` (to render
`QueryResults`); the reverse import would be a cycle. `Providers()` picked
up a second parameter for this (`phiVerbs map[string]bool`); it has
exactly one call site (`internal/cli/query.go`), now updated.

Placed in the same `tierAction` band as `CommandProvider`, `system`, `ssh`
and `directory` (from the ranking fix earlier in this same session — see
the entry above).

### Honest assessment
- **Verb match is on the first word only**, case-insensitive, with no
  minimum query length — typing just `doctor` recognises `phi doctor`
  exactly as `theme set dark` recognises `phi theme set dark`. But for a
  *bare single-word* verb with no other candidate competing (an app, a
  file, a window), a **pre-existing, unrelated quirk in the calculator
  engine** (`internal/mathx`) often wins instead: it treats any single
  unrecognised word as a one-variable expression and offers to *plot* it
  (`evalNumeric` in `internal/mathx/engine.go` — "if there is exactly one
  free variable... the useful answer is a plot of it"). E.g. `phi query
  doctor` today ranks `y = doctor` (a spurious plot) above `phi doctor`,
  because that path sits in this session's own math tier, above the
  action tier `phi doctor` sits in. Multi-word verb invocations like
  `theme set dark` are unaffected — the calculator's parser doesn't treat
  three bare words as one plottable expression, so it produces nothing
  there. Left alone rather than fixed here: it's a mathx behaviour with
  its own separate cause, not something this TODO entry named, and
  narrowing what mathx treats as "one free variable worth plotting" is a
  bigger, riskier change than this entry asked for. Worth its own backlog
  entry if it bothers you in practice.
- Not run against `phi-shell`'s actual launcher UI (no compositor here) —
  verified with `go build ./...`, `go vet ./...`, `go test ./...`, and
  manual `phi query "<text>"` runs from a terminal.

### How to test it
1. From a terminal, on a machine with this branch: `phi query "theme set
   dark"` (or, with the shell running, type the same into the launcher).
   Confirm a result titled `phi theme set dark` appears, and selecting it
   opens a terminal running `phi theme set dark`.
2. Try a few more: `phi query "vpn status"`, `phi query "firewall status"`
   — each should offer to run the equivalent full `phi …` command.
3. Try a bare single-word verb, e.g. `phi query "doctor"` — see the
   Honest Assessment above: today this may rank a spurious calculator
   plot above the `phi doctor` result rather than putting it first.
4. Try a word that is not a phi verb, e.g. `phi query "firefox"` — no `phi
   …` result should appear at all.

---

## Rank launcher results by category before match quality

- **Date:** 2026-09-11
- **Repo / branch:** phi / dev
- **Commits:** 6b5f4c9 query: rank by category tier before match quality
- **Original TODO:** ranking for the runner should be rearranged in a reasonable way. Currently it has latest features appearing first (like the calculator) but it does not make sense. Apps should be always first, non hidden files second, math when obvious,

### What was asked
The launcher's result ranking felt wrong — the calculator was showing up
above things like applications, which doesn't match how the launcher is
actually used. The requested order: applications first, always; non-hidden
files second; math results third, and only when the query is unambiguously
math.

### What was done
`phi query`'s ranking (`internal/query/rank.go`) previously scored every
provider on one shared 0–100-ish scale. `CalculatorProvider` and
`CurrencyProvider` trust their own confidence and set a flat `Score: 100`
(matchWeight can't judge a numeric answer like "4" against the query "2+2"
that produced it), which routinely tied or beat a genuine exact-title app
match — that's the reported bug.

Added a `providerTier` band per provider category, spaced 1000 apart (well
clear of the largest possible per-query contribution: 100 from matchWeight
+ 15 from frecency), added on top of whatever score a provider already
computed. Category now always dominates; match quality and frecency only
decide order *within* a category. Order, highest first: applications, open
windows, files, math (calculator + currency), then the narrower/deliberate
providers (system actions, ssh hosts, zoxide, run-command), then web
search last.

Two things not explicitly named in the TODO entry, decided by judgment:
- **Windows sit just under apps**, not with files. `query.go`'s own header
  already calls switching to an open window "likely the most frequent
  launcher action on a tiling compositor" — closer in kind to launching
  than to a file search.
- Everything else the TODO entry didn't name (system actions, ssh hosts,
  zoxide, run-command, web search) kept its previous *relative* order
  (already established by each provider's own flat Score), just moved
  below math as a block, since each is a narrower, more deliberate action.

"math when obvious" is read as already true today: `CalculatorProvider` /
`CurrencyProvider` only produce a result once `mathx` actually parses the
query as math or a currency conversion — this change only affects where
that result ranks once it exists, not whether it appears. "Non hidden"
files come from `fd`'s own default (it excludes dotfiles/gitignored paths
unless told otherwise) — no explicit flag was added.

### Honest assessment
- **Consequence worth flagging:** typing the exact name of an app that is
  already open now always ranks "launch a new instance" above "switch to
  that open window", because `tierApps` unconditionally beats
  `tierWindows`. That follows literally from "Apps should be always
  first," but it may not be what's wanted day-to-day — easy to swap
  (`tierApps`/`tierWindows` are two lines in `rank.go`) if so.
- The tier boundaries for the categories the TODO entry didn't name
  (system/ssh/zoxide/command all share one "action" tier, below math) are
  a judgment call, not something requested — flag if any of those feel
  wrong once used for real.
- Not run against real launcher usage or `fzf` (`rank_test.go`'s own
  header already notes this limitation predates this change) — verified
  with `go test ./...`, `go vet ./...`, and manual `phi query` runs from a
  terminal, not on real hardware with the shell attached.
- Confirmed `phi-shell`'s `Launcher.qml` never reads `Result.Score` (it
  only renders the list `phi query` already returned in order), so scores
  moving from ~0–100 to ~0–5115 is safe — it's an internal ranking value,
  not part of the JSON contract the shell interprets.

### How to test it
1. On a machine with `phi` built from this branch (or after the next
   package build once this reaches `main`), open the launcher and type an
   application name that also happens to look like it could match another
   category — e.g. a query that both an app title and a calculator
   expression could answer.
2. Confirm the application result appears above any calculator/currency
   result, regardless of how exact the app-title match is.
3. Type a partial file name (something under `$HOME`, at least 2
   characters) that also loosely matches an installed application's title
   — confirm the application still ranks above the file, and the file
   ranks above any calculator result.
4. Type a plain arithmetic expression, e.g. `2+2` — confirm it still
   appears (math results are unaffected when nothing else matches).
5. From a terminal, `phi query "<your query>" | jq .` also works without
   the shell — each result's `score` field shows the new tier bands
   (5000s = apps, 4000s = windows, 3000s = files, 2000s = math, 1000s =
   the rest, 0s = web search) if you want to see the ordering directly.

---
