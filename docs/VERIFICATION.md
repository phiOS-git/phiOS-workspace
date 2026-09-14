# Features to be verifiedw

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.



---

## Magnifier glass shows the screen but never actually zooms in

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** 00e541e magnifier: fix the lens never actually zooming
- **Original TODO:** "the magnifier glass currently does not zoom in since the border where removed. It has to do with inconsistencies with the screen capture method. Needs to be solved. Reference this: https://github.com/Horizon0427/Glasscope" — plus the whole 2026-09-11 investigation note (two candidates, neither confirmed) that followed it.

### What was asked
Fix the magnifier lens (SUPER+Z) so it actually magnifies the screen under the cursor, instead of showing it at some other, apparently unmagnified, size.

### What was done
With the user's agreement (given specifically for this session, after the unrelated Hyprland-dispatch investigation already established live access), ran `phi-shell`'s own dev checkout as a second, standalone Quickshell instance (`qs -p <this checkout>`, a distinct config identity from the live `~/.config/quickshell/phi` one — confirmed the two never conflict) to actually see the UI render, for the first time in this project's history for this particular bug.

That surfaced two problems, not one:

1. **The checkout didn't even load at first.** `Panels/BarPopout.qml` and `Services/PowerMenu.qml` both declare a real `IpcHandler {}` element without importing `Quickshell.Io` — Quickshell's config loader aborts the ENTIRE shell (every file cascades to "Type X unavailable") on a bad type anywhere in the tree. Fixed both (one missing import line each). The live checkout in daily use predates `Services/PowerMenu.qml` entirely, which is the only reason this hasn't already broken the user's real desktop shell — it will, the next time that checkout updates past this point, without this fix.
2. **The actual magnifier bug.** With the load fixed, triggered the lens via its own IPC (`qs ipc call magnifier toggle`) and screenshotted it at 1.5×, 2.5× and 6.0× — at every zoom level, the content inside the lens was real and sharp, but the EXACT SAME apparent size as the unmagnified screen around it. That is precisely the docs/TODO.md note's own predicted signature for "Candidate 2" (`ScreencopyView` ignoring the explicit oversized `width`/`height`) and rules out "Candidate 1" (the mask/layer change) outright, since content was clearly visible, just never scaled.

  Checked `ScreencopyView`'s real type definition directly (`Quickshell.Wayland._Screencopy`'s own qmltypes, not recalled) rather than guessing further: it is a plain `QQuickItem` with NO scaling meaning attached to the inherited `width`/`height` at all. The property that actually controls the rendered content's size is `constraintSize` (`QSizeF`, read-write) — declared on the real type, never once set in `Magnifier.qml`. Set `constraintSize: Qt.size(screen.width * zoom, screen.height * zoom)` alongside the existing (now cosmetic-only) `width`/`height`, saved, and Quickshell's hot-reload picked it up live: re-screenshotted at 2.0× and 6.0× and both now show real, proportional magnification — clearly larger at 6.0× than at 2.0×, unlike before where every zoom level looked identical.

### Honest assessment
Zoom is now confirmed, visually, at multiple settings — the core bug is fixed. Not verified: whether the lens PANS correctly as the cursor moves (this session has no way to synthesize real pointer movement — `ydotool`/`wtype`/`dotool` are not installed, and installing one wasn't in scope for a live test) — the pan math itself was untouched by this fix, and the file's own header already separately flags "blink-free" capture timing and click-through (`mask: Region {}`) as unverified; neither was touched or checked here either. The glass-edge rim/falloff Canvas effect was visible in every screenshot and looked reasonable but was not specifically scrutinized.

Both `IpcHandler` import fixes were confirmed the direct way — the config failed to load without them and succeeded with them, on the real Quickshell version installed on this machine (0.3.1) — not inferred from reading alone.

### How to test it
1. Pull `phi-shell` `dev` (this fix touches the checkout everyone runs, not just a dev one).
2. Press Super+Z to open the magnifier loupe.
3. Move the cursor over some text or a detailed part of the screen. The content inside the circular lens should look visibly larger than the same content around it — not the same size.
4. Press Super+Equals a few times (zoom in) — the content inside the lens should get noticeably larger. Press Super+Minus repeatedly (zoom out) — it should shrink back down. Before this fix, the zoom readout below the lens (e.g. "×2.5") changed but the actual magnified content never did.
5. Super+Z again to close it.

## SUPER+L power menu has no icons on any row but Shut down

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** 50513df bar: add real icons to the power menu's Lock, Suspend and Reboot rows
- **Original TODO:** "the new SUPER+L power menu (lock/suspend/hibernate/reboot) needs real icons on every row — only "Shut down" has one today, reusing the bar's existing power glyph. Live lookups against nerd-fonts' own `glyphnames.json` this session returned contradictory results ... Needs either a hardware screenshot showing what a candidate codepoint actually renders as, or the four exact `nf-md-*` ... names/codepoints confirmed some other way."

### What was asked
Give the power menu's Lock, Suspend, Hibernate and Reboot rows a real icon each (Shut down already has one), using the same `nf-md-*` (Material Design Icons) codepoint family every other icon in this codebase uses — without guessing, since this exact file has shipped two wrong-codepoint bugs before (Steam, the scratchpad console icon) from doing exactly that.

### What was done
`curl`'d a fresh copy of nerd-fonts' own `glyphnames.json` directly to a local file and parsed it with Python's `json` module — no AI-summarised web fetch involved anywhere, which is very likely what produced the prior session's "contradictory results" (a small model transcribing a huge minified JSON file by eye is exactly the kind of thing that flips "not found" to "found" on a retry). Matched three rows to a real, exact-named icon: `nf-md-lock` (Lock), `nf-md-power_sleep` (Suspend), `nf-md-restart` (Reboot) — added to `Bar/glyphs.js` alongside the other confirmed codepoints, wired into `Dialogs/PowerMenu.qml`'s rows via the `glyph` property `Widgets.ListRow` already supports.

<span style="color:red">**NOT DONE: Hibernate has no icon.**</span> Searched the same `glyphnames.json` systematically for "hibernate" and every close synonym that could plausibly stand in for it (sleep, power_standby, moon, bed, restart_alert, and a dozen others) — none of the ~64,000 entries in the file is named "hibernate", and none of the synonyms reads as hibernate specifically rather than something else (sleep already went to Suspend). This isn't a lookup failure to retry; the icon does not exist in this font. Re-added as its own clean, bare TODO entry asking for a deliberate substitute pick, since forcing an unrelated icon in here would repeat the exact mistake this whole task was about avoiding.

### Honest assessment
The three added codepoints are confirmed correct BY NAME against the authoritative source (nerd-fonts' own data file, fetched fresh this session) and confirmed PRESENT in the actual installed font on this machine (`fc-query`'s charset dump for `/usr/share/fonts/TTF/SymbolsNerdFontMono-Regular.ttf` covers the whole `f0001-f1af0` PUA range these codepoints fall in). `qmllint` reports no errors on the changed file (only the expected `qs.*` import-resolution warnings every file in this repo gets outside a real Quickshell build).

**Update, later the same day:** now also confirmed visually, not just by codepoint lookup. A later session (see "Magnifier glass shows the screen but never actually zooms in") got the user's agreement to run this checkout as a real, standalone Quickshell instance and screenshot it — the power menu was opened via its own IPC (`qs ipc call powerMenu trigger`) as part of that, and the screenshot shows exactly the four expected shapes: a padlock for Lock, a crescent "power-sleep" glyph for Suspend, the existing power glyph for Shut down, and a circular-arrow restart glyph for Reboot — Hibernate correctly shows no icon, matching this entry's own documented gap. Nothing renders as a blank box. This was incidental to that session's own task, not a re-verification of this entry specifically, but it directly answers the "what do they render as" gap left open above.

### How to test it
1. Pull `phi-shell` `dev`.
2. Press Super+L twice quickly (the double-tap that opens the power menu instead of locking immediately) — or however the panel is otherwise reached.
3. Look at each row: Lock should show a padlock icon, Suspend a power-button-with-crescent icon, Shut down its existing power icon (unchanged), Reboot a circular-arrow "restart" icon. Hibernate should still show no icon, text label only, same as all four looked before this change.
4. If any of the three new icons renders as a blank box instead of the described shape, the codepoint is right (confirmed against the font's own data) but something else is wrong (e.g. a stale/different font actually being used at render time) — worth a screenshot either way to close this out.

---

## Several window-management keybinds silently do nothing

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev, phios-dotfiles / dev
- **Commits:** phi-shell: dcf1db1 hyprland: fix every broken raw hyprctl-dispatch call, 0bbc1e3 Merge branch 'fix-hyprland-dispatch' into dev — phios-dotfiles: f024453 hyprland: fix broken raw-dispatcher-string keybinds
- **Original TODO:** "windows management keybinding (move, resize) do not work *to be checked first", "super+shift+left/right and super+ctrl+left/right do not do anything (not workspace change, not window focus/move) — only bare super+left/right (focus change) works...", "*Check for updates*: hyprland resize does not seem to work", "h/j/k/l alternatives for the broken super+shift/ctrl+arrow binds stil don't work...", "when a window is set to floating (using the keybind) it cannot be resized" — five entries, all one root cause, all removed. Also touches (not removed, only partially addressed — see their own entries) "the scratchpad icon does not call the scratchpad" (superseded a parallel fix, see below) and "alt+tab still does not work" (two of its four symptoms).

### What was asked
Several independent reports that a keybind or bar/panel action calling into Hyprland does nothing at all: window move/resize (arrows and h/j/k/l), workspace previous/next (Ctrl+arrows and Ctrl+h/l), the scratchpad bar icon, and (found along the way, not separately reported before this) Alt+Tab's window-focus and workspace-change, the runner's "switch to this open window" action, the AI agent panel's "focus this coding session's window", and "log out immediately" if `hyprshutdown` isn't installed.

### What was done
This session runs directly on `zotac` with a live Hyprland session reachable (`WAYLAND_DISPLAY`/`HYPRLAND_INSTANCE_SIGNATURE` set) — something no prior session on this project had, confirmed with the user before using it, and used read-only/reversible only (disposable test windows and workspaces, cleaned up after each check, nothing left on the real system).

Root cause, confirmed by sending raw requests directly over Hyprland's own IPC socket (`.socket.sock`), bypassing both `hyprctl` and Quickshell entirely so the result is about Hyprland itself, not either client: **this Hyprland build's Lua config repurposes the `dispatch` socket command to EVALUATE its argument as Lua**, instead of accepting the traditional `"<dispatcher> <args>"` string every one of the affected call sites sent. Even a single bare word with no arguments fails with `hl.dispatch: expected a dispatcher`. The fix is the Lua-call form (e.g. `hl.dsp.window.move({ direction = "l" })`), confirmed live for every case shipped here with a disposable test window/workspace before being written down (position/size read back via `hyprctl clients -j`/`activewindow -j`).

**phios-dotfiles (`hyprland.lua.tmpl`):** replaced every `hl.dsp.exec_cmd("hyprctl dispatch ...")` bind whose native form was confirmed live with that native form directly (no subprocess needed any more): `window.move({direction=...})` for movewindow (arrows and h/j/k/l), `window.center()`, `window.pin()`, `window.fullscreen()`, `focus({workspace="m-1"/"m+1"})` for the previous/next-workspace binds (arrows and Ctrl+h/l), and — since `window.resize({x=,y=})` turned out to be an ABSOLUTE size, not the old relative nudge, so no static Dispatcher table can express it — a Lua function bind reading `hl.get_active_window()` for the resize submap. Also corrected the SHIFT+M logout fallback's embedded string and the two 3-finger-swipe workspace gesture actions (same bug, `hl.exec_cmd` instead of `exec_cmd`).

**Deliberately left broken:** the comma/period multi-monitor binds (focusmonitor/movewindow-to-monitor). An initial fix attempt (`focus({monitor=-1})`) returned "ok" and looked confirmed, but `{monitor=1}` on this same one-monitor machine errored "monitor not found" while `{monitor=0}` (the real monitor) succeeded — so `monitor` is an absolute selector, not the relative cycle the old dispatcher gave, and `-1` succeeding was most likely negative-index addressing landing on "the only monitor" by coincidence, not a working relative-previous. Reverted rather than ship a second guessed-and-wrong fix in the same file (the first one is the SHIFT+M correction, see Honest assessment).

**phi-shell:**
- `Bar/modules/Workspaces.qml` — the scratchpad toggle, `AltTab/AltTab.qml` — `_focusWindow`/`_focusWorkspace`, `Launcher/Launcher.qml` — the "activateWindow" runner action, `Services/Agent.qml` — `focusCodingWindow`, `Services/HyprlandBridge.qml` — the `leaveReservedWorkspace()` fallback and the `dispatch()` function's own header comment (which asserted the broken string form as the whole contract): all switched to `Services.HyprlandBridge.dispatch()` given the correct Lua-call string.
- `Services/Agent.qml` — `openCodingSessionInTerminal` switched to a plain `Quickshell.execDetached()` kitty launch instead of routing through Hyprland's dispatch socket at all — spawning a program never needed that, every other launch in this codebase already does it directly.
- `Services/PowerActions.qml` — `logout()`'s `hyprshutdown` fallback corrected the same way as hyprland.lua.tmpl's SHIFT+M bind; confirmed `hyprshutdown` is not installed on this machine, so this fallback always ran and always silently failed.

**Superseded a parallel fix:** while this was in progress, a different session claimed and landed "the scratchpad icon does not call the scratchpad" (commits d9faba4/f130368) by swapping `Services.HyprlandBridge.dispatch()` for a `Quickshell.execDetached(["hyprctl","dispatch","togglespecialworkspace","scratch"])` subprocess — reasonable by the same convention every other affected file used (AltTab.qml, Launcher.qml, Services/Agent.qml, Services/PowerActions.qml), but that convention was itself the bug: the subprocess form sends the exact same rejected traditional string, just from a different client. The merge conflict this caused was resolved in favour of the verified Lua-call form; `Bar/modules/Workspaces.qml`'s own comment now documents why.

### Honest assessment
The multi-monitor binds (comma/period) are still broken, on purpose — see above, needs a real second monitor to find the actual mechanism. Not tested: `hyprshutdown`-present machines (none of the three, as far as this session could check, have it installed, so the corrected fallback path is what actually runs everywhere) and the SHIFT+M/logout Lua-call form itself was never dispatched live for real (ending a real session to test it would defeat the point) — it's corroborated by Hyprland's own bundled example config (`/usr/share/hypr/hyprland.lua`) using the identical line, and by every structurally-identical case elsewhere in this change that WAS tested live, but it is the one line in this whole change taken on documentation rather than direct observation.

Alt+Tab's "does not close on Alt release" and "does not start with the right window selected" are a different mechanism entirely (alt-release detection and initial-selection logic inside AltTab.qml, unrelated to dispatch) and were not investigated this pass — that entry stays open in docs/TODO.md with a note pointing back here so the next session doesn't re-diagnose the two symptoms this already fixed.

The AI agent's core reported failure (broker/containment/socat proxy socket) is untouched — `Services/Agent.qml`'s fix here only reaches two small, separately-broken pieces (focusing a coding session's window, and the terminal launch for a new one) that happened to share this exact bug; the entry describing the real containment failure is not addressed and not touched.

Everything in phios-dotfiles was checked for Lua syntax validity with `luac5.4 -p` after substituting the `${PHI_*}` design tokens with dummy values (the real install pipeline's own `envsubst` step was not run, since that needs a full profile context this session didn't set up) — passes clean. `qmllint` was run against every changed phi-shell file; it reports only the expected `qs.*` import-resolution warnings this tool always gives outside a real Quickshell build (identical warnings appear on untouched files), no errors.

Nothing here could be verified against `razer` or `mini` — only `zotac`'s currently-connected single monitor and currently-running Hyprland 0.56.2 were available. If either other host runs a different Hyprland version, or one without the Lua config plugin active, this fix might not apply the same way there — worth a quick `hyprctl version` comparison across hosts before assuming this generalizes.

### How to test it
1. Pull `phi-shell`/`phios-dotfiles` `dev`, re-render (`phi theme set <variant>` if needed) and reload Hyprland's config (`hyprctl reload`) and phi-shell (saves hot-reload; a fresh `qs` start is not required).
2. **Window move:** focus a tiled window, press Super+Shift+Left (and Right/Up/Down, and the h/j/k/l equivalents) — the window should swap position with its neighbour in that direction. Before this fix, nothing happened at all.
3. **Resize:** press Super+R to enter resize mode, then Left/Right/Up/Down (or h/j/k/l) — the active window should visibly shrink/grow by a fixed step each press, for both a tiled and a floating window. Escape/Return leaves the mode.
4. **Workspace previous/next:** press Super+Ctrl+Left/Right (and Ctrl+h/l) — the view should switch to the adjacent workspace on the current monitor and wrap around; before this fix, nothing happened.
5. **Fullscreen/centre/pin:** Super+F toggles real fullscreen; Super+Shift+F then Super+Shift+C centres the now-floating window; Super+Shift+P pins it across every workspace (a small "pinned" indicator or its presence on every workspace switch confirms it) — none of these worked before.
6. **Scratchpad:** click the scratchpad icon at the right end of the bar's workspace strip (a small console glyph) — it should show/hide the scratchpad workspace. Super+A does the same from the keyboard; Super+Shift+A sends the focused window into it.
7. **Alt+Tab:** hold Alt+Tab (or the 3-finger swipe up) to open the overlay, select a different window (arrow keys or click) and confirm — the compositor should switch to that window's workspace and focus it. (The overlay not closing on Alt release, and not pre-selecting the "next" window on open, are still open — not part of this fix.)
8. **Runner "switch to window":** open the runner (Super), search for an already-open window by title, select it — it should focus that window, including switching workspace if it's on a different one.
9. **Log out:** Super+Shift+M (or the power menu's "Log out" with no confirmation path) should actually end the session — the most destructive one to test, so confirm the others above work first as circumstantial evidence this one's identical fix is sound, rather than testing it blind.
10. Multi-monitor comma/period focus/move binds are NOT fixed — with two monitors connected, confirm they still do nothing (expected), and if picking this up, `hl.get_monitors()` plus a Lua function bind (the same technique the resize submap now uses) is the likely next step.

---

## Status bar shows no network state at all on a host without Wi-Fi

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** 821c659 bar: add an ethernet status icon alongside wifi, 28bf197 Merge branch 'add-ethernet-bar-icon' into dev
- **Original TODO:** network informations should not be exclusive to wifi, but for ethernet as well. In the status bar, the network element (unified, see next task) should also have a specific icon (with states and animations as usual) for ethernet connection.

### What was asked
The bar's existing network indicator (`Bar/modules/Wifi.qml`) only ever appears where the `wifi` capability is true — a host with no wireless card (`zotac`, `mini`) has no bar icon at all for its wired connection. Add an ethernet icon with its own connected/disconnected states and animation, the same grammar the Wi-Fi icon already has.

### What was done
Scoped to exactly this — not the separate, much larger "tailscale/vpn and network overlay ... merged in a single element" TODO entry the "(unified, see next task)" parenthetical points at, which is real, undecided design work of its own (a two-state compressed/expanded overlay, killswitches, firewall toggle, a speed/ping visual) not attempted here.

Added:
- `Services/EthernetBridge.qml` — mirrors `Services/WifiBridge.qml`'s device lookup over `Quickshell.Networking`, filtered to `DeviceType.Wired` instead of `DeviceType.Wifi` (that enum value is confirmed real from `WifiBridge.qml`'s own header, which already cites Quickshell's `device/enums.hpp` for it). No scan/connect surface — a wired link has no network to pick, unlike Wi-Fi.
- `Widgets/EthernetIcon.qml` — a hand-drawn Canvas icon (a plug body, a retention clip, four contact pins — an RJ45-plug silhouette), not a font-symbol lookup. `Widgets/WifiIcon.qml` already establishes this precedent (its own header: a simple, widely-recognisable shape is safer hand-drawn than guessed from a font this project cannot render to check) — this project has shipped wrong guessed Nerd Font codepoints twice before, and `Bar/glyphs.js`'s own header admits every codepoint in it is "UNVERIFIED against the font on real hardware," so a new guessed codepoint was not an option here.
- `Bar/modules/Ethernet.qml` — mirrors `Wifi.qml`'s shape: the interface name (e.g. `enp5s0`) when connected, `"off"` when not (matching Wi-Fi's own identity-when-up grammar, not a bare "on"). No `tone: "warn"` when disconnected, unlike Wi-Fi/Network — an unplugged ethernet port on a host that routes over Wi-Fi is not a warning state, and `Segment.qml`'s own header is explicit the bar stays "muto per default." The button hides entirely (`visible: EthernetBridge.present`) on a host with no wired NIC at all, rather than showing a permanent "off": a physical port either exists or it doesn't, unlike Wi-Fi/VPN which are always meaningful to toggle regardless of hardware. This self-hiding is a live `Networking.devices` check, not a new `phios-dotfiles` capability probe — kept the change inside `phi-shell` alone.
- Registered as a new module type in `Bar/Bar.qml`'s `componentFor()` switch and `Bar/modules.json` (position 45, right after `wifi`, capability `""` since visibility is handled live as above).
- A minimal status row in `Panels/BarPopout.qml`'s bar popout (interface name or "not connected"). Deliberately no settings deep-link — no `connectivity.ethernet` section exists yet in `Settings/sections/Connectivity.qml`, and adding one is outside what this entry asked for.

Five files changed for one new module type is `phi-shell/CLAUDE.md`'s own documented shape for adding a TYPE (ADR 078: the type is code written once; only the per-host *instance* — the `modules.json` row — is meant to be a one-file change), not scope creep.

### Honest assessment
Nothing here was run or compiled (`phi-shell/CLAUDE.md`: "You cannot run this"). Two things need the user's own screenshot to actually confirm:
- The hand-drawn RJ45 icon is small at bar-icon size — four pins at 0.05× the icon box width, with gaps between them, may render as a blur rather than distinct pins. If it does not read clearly as "an ethernet plug," it should be simplified (e.g. two pins instead of four) rather than kept as drawn.
- The module's visibility is gated on `Networking.devices`, a live model that populates asynchronously after the shell starts — on a host with a wired NIC, the icon may pop in a moment after login rather than being present at first paint, the same way `Config/Capabilities.qml`'s own probe already works. Not a defect, just not instant.

### How to test it
1. On `zotac` or `mini` (hosts with a wired NIC), start `phi-shell` and look at the right side of the status bar, after the Wi-Fi icon's normal position (or where Wi-Fi would be if this host has no wireless card). An ethernet icon (a small plug shape) should appear within a second or two of the bar loading, showing the interface name (e.g. `enp5s0`) next to it.
2. Unplug the ethernet cable. The icon should dim to its "off" resting opacity and the label next to it should change to `off`. Run `nmcli device status` at the same time — it should agree the wired device shows as disconnected.
3. Plug the cable back in. The icon should fade back to full opacity and the label should show the interface name again.
4. Click the icon — a small popout should drop below it showing "Ethernet: <interface name or 'not connected'>".
5. On `razer` (or any host confirmed to have no wired port), confirm no ethernet icon appears in the bar at all, and cross-check with `nmcli device status` that no wired device is listed — that distinguishes "correctly hidden, no hardware" from "silently failed to load."

---

## Status bar icons don't activate on a touch near their top border

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** f3899b4 segment: widen tap release tolerance to fix top-edge touch misses, dada8fc Merge branch 'fix-segment-tap-margin' into dev
- **Original TODO:** the status bar icons can be touched with touch screen near their top border, triggering the hover effect but not the activation

### What was asked
A finger tapping a status bar icon near its top edge lights up the hover/pressed highlight but the tap never activates the button (no popout opens, no toggle fires).

### What was done
`Widgets/Segment.qml`'s `tapHandler` already uses `gesturePolicy: TapHandler.ReleaseWithinBounds` (a prior fix, commit `877955e`, for a different touchscreen symptom — in-flight jitter between press and release). That policy cancels the tap if the *release* point lands outside the Segment's own `Item` bounds. A finger landing near the icon's top edge very plausibly lifts a few px past that edge by release time — outside the bounds, so `onTapped` never fires, while `pressed` alone already drove the full inverted highlight the instant the finger landed.

Confirmed against Qt's own current source (`qtdeclarative`'s `qquickpointerhandler.cpp`) that `PointerHandler.margin` is real and — critically — that `parentContains()`, the exact bounds test `ReleaseWithinBounds` itself calls, expands by that margin once it is greater than 0 (`localPosition >= -m && <= size + m`), not merely an activation-only radius as the property's own one-line doc description could be read to imply. Set `tapHandler.margin: root.paddingV` — the Segment's own existing token-derived vertical padding, not a new literal (rule 6) — so a release just outside the painted button by about that same distance still counts as "within bounds." Deliberately left off `hoverHandler`: the report says hover already fires correctly, and `BarIsle` packs Segments with zero spacing, so widening hover too would let two adjacent buttons' hover zones overlap at their shared edge.

### Honest assessment
The mechanism is verified from Qt's real source, not guessed (rule 7) — but nothing here was run or compiled (`phi-shell/CLAUDE.md`: "You cannot run this"), so it is not confirmed against the actual touchscreen. `margin` is uniform on all four sides, not just the top: it also (very slightly) widens the left/right release tolerance toward a zero-spacing neighbour button. `parentContains()`'s own code shows the initial *press* grab is margin-expanded the same way the release check is, so a press genuinely inside that few-px overlap between two adjacent icons is arbitrated by Qt's own internal grab-conflict resolution — which handler wins in that narrow case was not verified here. This is an already-tiny edge case at zero spacing made only marginally wider, but it is the one real trade-off of this fix and worth watching for on real hardware.

### How to test it
1. On `razer` (or any machine with a touchscreen), with `phi-shell` running, tap deliberately at the very top edge of a status bar icon (e.g. the wifi or bluetooth icon) several times in a row, aiming for the topmost sliver of the button.
2. Before this fix, those top-edge taps light the icon's hover/pressed highlight but nothing opens — the popout never appears. After this fix, every one of those top-edge taps should open the icon's popout, same as tapping dead centre.
3. As a control, tap the dead centre of the same icon several times — it should keep working exactly as before (this fix does not change centre-of-button behaviour).
4. As a check on the one honest trade-off above: start a tap on one bar icon and lift your finger over its immediate neighbour (two adjacent icons with no gap between them, e.g. two icons in the same island). Confirm it either activates the icon you pressed or does nothing — not the neighbour it lifted over.

---

## Scratchpad bar icon does nothing

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** d9faba4 shell: fix the scratchpad bar icon's dead dispatch call, f130368 land: fix the scratchpad bar icon's dead dispatch call
- **Original TODO:** the scratchpad icon does not call the scratchpad nor it reacts to its activation, it's broken

### What was asked
Clicking the scratchpad toggle in the bar should open/close the scratchpad, and the icon should reflect whether the scratchpad is currently shown, however it was opened (icon or MOD+A).

### What was done
Fixed the trigger half. `Bar/modules/Workspaces.qml`'s scratchpad `Segment` called `Services.HyprlandBridge.dispatch("togglespecialworkspace scratch")` — `Hyprland.dispatch()`, Quickshell's own IPC call, no `hyprctl` subprocess involved. That is the exact same mechanism the old, deleted `Bar/modules/SpecialWorkspaces.qml` used for its own special-workspace toggles, and this file's own ADR 134 comment already records that module as having "never worked on real hardware." `HyprlandBridge.qml`'s own `dispatch()` comment goes further: it admits this passthrough has never been proven at all, since the numbered-workspace strip switches through the model's own `activate()` and never needed it — it's the only real call site of that function in the whole repo. Every other Hyprland-triggering action here (`Launcher.qml`, `AltTab.qml`, `Services/Agent.qml`, `Services/PowerActions.qml`, `Services/NightShift.qml`) instead shells out via `Quickshell.execDetached(["hyprctl", "dispatch", ...])` — switched the scratchpad toggle to that same proven pattern.

<span style="color:red">**NOT DONE:** the icon still has no visual "shown" state — it looks identical whether the scratchpad is visible or not. `Workspaces.qml`'s own header explains this is not an oversight: ADR 134 deliberately left the scratchpad with no `active` binding, because sharing the numbered-workspace strip's `active` state would make it lie whenever a numbered workspace also reads as active. That's still true, and reversing it is a real decision, not something to fold into this bug fix — re-added as its own entry in docs/TODO.md, `**Question:**`ed, with a citation for the one new fact that changes the calculus: `hyprctl monitors -j` (confirmed against current Hyprland source, not guessed) exposes `specialWorkspace.name` per monitor — `"special:scratch"` when shown, `""` when not — a source outside Quickshell's own broken tracking that didn't exist as a confirmed option when ADR 134 was written.</span>

### Honest assessment
The trigger fix is a strong, precedented lead — not a confirmed-by-running-it fix (`phi-shell/CLAUDE.md`: "You cannot run this"). ADR 134's "never worked on real hardware" doesn't isolate whether the OLD module's failure was the dispatch call itself, its own separate visibility-tracking gap, or both — I'm relying on the strong circumstantial case (same broken-by-inconsistency call, zero other proven callers of that function, every other real action in this repo uses the subprocess form instead) rather than a hardware trace. If clicking the icon still does nothing after this, the dispatch mechanism was not the (or not the only) cause and this needs a fresh look with real hardware in the loop.

### How to test it
1. Open the scratchpad app if you haven't already (MOD+SHIFT+A on a focused window, or launch whatever app your scratchpad rule targets).
2. Click the scratchpad icon in the bar (the console/terminal-shaped glyph after the workspace numbers). The scratchpad should toggle into view.
3. Click it again — it should hide. Confirm this works repeatedly, not just once.
4. The icon itself still won't visually change between these two states — that's the known, separate gap described above, not something to expect from this fix.

---

## Runner bar has no prefix shortcuts, and "phi" prefixed queries don't work

- **Date:** 2026-09-14
- **Repo / branch:** phi / dev, phi-shell / dev
- **Commits:** phi: 828928f query: add the runner-bar prefix feature's routing layer, ea9173d land: add the runner-bar prefix feature's routing layer — phi-shell: 814c169 shell: add the runner-bar prefix feature (lock, chip, colour), 2a7791e shell: fix locked-empty no-results visibility and drop a redundant sync, c3b383c land: add the runner-bar prefix feature (lock, chip, colour)
- **Original TODO:** Add prefix feature to the runner bar: writing "web <anyting>" will automatically set the "search on web" first (but still perform the rest of the ranking). Make the same for: convert, math, ask (ask ai), file, app/run, phi (shows phi completion) and website specific like wiki/yt/arch/rddt. Add more if you can think of some very relevant one. Also if TAB is pressed after the prefix, the prefix will be "locked" visually as it gets background (like the highlighted option) and a "backspace" nerd icon next to it (clicking it removes it), it can also be cancelled but it requires a double click of backspace (to prevent removing it when holding down backspace). While a prefix word is selected, the only results shown will be determined by the prefix. More prefixes will be added with time, each should be configured with a color code (either a theme variable or a specific custom color), that color defines the highlight color when active and the runner bar will transition to that color for the borders when a prefix is active. — plus the companion entry: "phi prefixes in the runner bar don't seem to work (will be solved by applying the prefix feature above, any conflict must be removed in order for the prefix feature to work without issues)"
- **Requires phi rebuild:** yes — no tag covers this yet (`internal/query` and `internal/cli` both changed); tag once dev is merged to main by the user

### What was asked
Typing a keyword like "web", "phi", "math" or "wiki" before the rest of a runner query should boost that category's result to the top without narrowing anything else out. Pressing Tab should "lock" that keyword into a coloured chip with a remove button, after which only that one category answers, and the runner's border should tint to match. Two backspaces on an empty field (not one, and not a held-down key) should also cancel the lock. And the separate report that literally typing "phi ..." didn't work at all should be resolved as part of the same change.

### What was done
**phi (`internal/query`):** a new `prefixProviders` routing table (`query.go`) maps each keyword to the provider(s) it should surface, plus `detectPrefix`/`boostProviders` (move a matched category to the front of an already-ranked list without filtering anything else out — the "boost" half) and `filterProviders`/a new `lockedPrefix` parameter on `Run()` (restrict to one category — the "lock" half, wired to a new `phi query --prefix <key>` CLI flag). Each routed provider strips its own optional leading keyword before matching, so it can be reasoned about — and tested — independently of this routing layer: `websearch.go` ("web"), `command.go` ("run"), `calculator.go` ("math" — "convert" needed no change, `mathx.ParseConversion` already strips it), and `phicommand.go` ("phi" — this is the fix for the companion bug: it previously matched only the bare verb, e.g. "theme set dark", never "phi theme set dark" itself, which fell through to `CommandProvider` instead at a lower rank). Two more genuinely needed the same fix after tracing the actual behaviour by hand rather than assuming: `apps.go`'s "app" prefix and `files.go`'s "file" prefix — the first would have silently dropped every application from the result list ("app firefox" is not a fuzzy match against "Firefox" at all, no 'a' in it), the second would have searched the filesystem for a file literally named "file passwords" instead of "passwords". A new `sitesearch.go` (`SiteSearchProvider`) answers "wiki"/"yt"/"arch"/"rddt", one self-contained keyword regex per site, opening that site's own search-results page. New tests throughout (85 in the package after this change) cover every keyword's stripping behaviour, the routing/boost/lock logic in isolation, and the app/file fixes against a temp-directory fake `.desktop` entry (real hardware still needed to confirm `fd` and the real desktop-entry scan behave the same way this sandbox's fakes did).

**phi-shell (`Launcher/`):** a new `prefixes.js` table (label + a `Config.Appearance` semantic tone per keyword — grouped, since there are only five tones for twelve keywords) is the shell-side counterpart to phi's routing table; the two are kept in sync by hand, each documents where the other lives. Tab locks the keyword currently leading the typed text, stripping it from the visible field into a chip styled like the result list's own selection highlight, coloured by its tone, with a "×" to remove it. Two genuine backspace presses (not the auto-repeat stream from holding the key, detected via `KeyEvent.isAutoRepeat`) within 500ms cancel it the other way. `queryComponent` reconstructs "keyword + remainder" and adds `--prefix` when locked; the stale-response guard now checks the locked prefix too, not just the query text, so a response computed before a lock (or after an unlock) can't render into the wrong UI state. A same-geometry overlay Rectangle (not a new override on the shared `Widgets.Panel` component) tints the runner's border to the locked prefix's colour.

### Honest assessment
<span style="color:red">**NOT DONE (as literally worded):** the entry asks for a "backspace nerd icon" on the chip. This ships the plain "×" character instead — the same glyph `Settings.qml`'s own close button already uses — because no backspace/delete codepoint exists anywhere in `Bar/glyphs.js` to reuse, and this repo has shipped two wrong guessed codepoints before (Steam, the scratchpad console icon — both still named in the SUPER+L power-menu icons entry, still blocked on the same problem). The remove-on-click functionality itself is fully there; only the glyph differs, and a screenshot from the user of what a candidate `nf-md-*` codepoint actually renders as would let a follow-up swap it in.</span> The runner list's own pre-existing selection rows have no hover/pointer-cursor feedback either, and the chip's "×" matches that same existing convention rather than inventing one — the system-wide lack of hover/cursor affordances is the Style section's own separate, much larger "many elements... don't have basic UX features" entry, out of scope here on purpose. Not independently testable by me beyond `go build`/`go vet`/`go test ./...` (all clean, 85 passing) and manual `phi query` CLI runs for every keyword — this is otherwise a phi-shell UI/behavioural change and, per that repo's own rule, needs the user's own screenshot/verification for anything visual (the chip's look, the border tint, the double-backspace feel). The twelve keyword→colour groupings in `prefixes.js` are a scope call, not a verified-correct taxonomy — flagged for cheap veto/re-grouping.

### How to test it
1. Open the runner (Super) and type `web firefox settings`. The web-search result should now appear first (previously it could be crowded out — e.g. the AI-agent result outranks it by default).
2. Type `phi theme set dark` (with the literal word "phi" first) — a `phi theme set dark` result should now appear; before this change nothing from the `phi` category matched this exact text.
3. Type `wiki linux kernel`, `yt lofi beats`, `arch pacman`, or `rddt archlinux` — each should show a "Search <site> for "..."" result that opens the right site's search page.
4. Type `app firefox` (assuming Firefox is installed) — it should show the Firefox app result; before this fix it would have shown nothing from that category at all.
5. Type `web jeans`, then press Tab. The "web" word should vanish from the input and a coloured chip reading "Web" with a "×" should appear in its place; the runner's outer border should tint to that same colour; the result list should now show only web-search results.
6. Press Backspace once (field is empty after locking) — nothing should happen. Press it again quickly — the chip should disappear and the border should return to normal. Try holding Backspace down instead — it must NOT cancel the lock no matter how long it's held.
7. Lock a prefix again and click the chip's "×" — it should remove immediately, no double-press needed.
8. With nothing typed and no prefix locked, Tab should do nothing (previously dead code checked for a `"command"` result kind no provider ever produced — this is confirmed removed).

---

## Theme has no automatic day/night schedule

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** 1813727 shell: add automatic theme schedule (dark evening, light morning), fdbe023 land: add automatic theme schedule (dark evening, light morning)
- **Original TODO:** "theme auto" which changes automatically on evening time (automatic/manual time). Consider "phi theme set" restarts the qs and that cannot happen automatically, the change should be smooth and non destructive.
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
An automatic dark/light theme switch driven by time of day (a fixed schedule, or custom hours), with the entry itself flagging a specific worry: that `phi theme set` restarts phi-shell, and that can't be made to happen unattended, so any automatic switch needs to be smooth and non-destructive.

### What was done
Before writing anything, I checked whether the entry's own stated blocker is actually true of the current code — it is not, in either of the two ways it could be:
- `phios-dotfiles/design/adapters.txt` lists phi-shell's `Config/Tokens.qml.tmpl` as **class A** with reload command `-`: Quickshell watches every QML file it has loaded and hot-reloads it on save by itself. `phi/internal/theme/set.go`'s `Set()` — read end to end — never restarts anything; it writes files, runs an adapter's own reload command only when that adapter's rendered content actually changed, records the active variant, and sets the portal colour-scheme preference. There is no restart path anywhere in it, for phi-shell or otherwise.
- The only row in the whole adapter table with a *real* (non-`-`, non-`[unknown]`) reload command is Hyprland's own `hyprctl reload`. It doesn't even fire on a light/dark switch: `hyprland.lua.tmpl`'s one substitution is `XCURSOR_THEME`/`XCURSOR_SIZE`, and `design/tokens.common.sh` states outright that those are "not variant-dependent" — so that template renders byte-identical either way and `Set()` skips the reload as a no-op change.

In practice, a variant switch — manual or automatic — is just: file writes for the themed targets whose colours actually changed, phi-shell's own already-existing hot reload, and an instant `gsettings` write for the GTK/Qt portal preference. Nothing compositor-visible happens and nothing restarts. That made "smooth and non destructive" already true by construction, so the feature is the scheduling layer on top of the existing `phi theme set`, not a new safety mechanism.

- **`Services/ThemeSchedule.qml`** (new singleton): `scheduleMode` (`off`/`auto`/`custom`), a fixed default window (dark 20:00–7:00, same evening-to-morning default `Services/NightShift.qml` already uses, and the same reasoning — no location/sunset source exists anywhere in this project, so "auto" is a sensible fixed window, not a computed one) or custom hours. Re-evaluates every 60s and on every setting change; calls `phi theme set <variant>` **only on an actual transition**, tracked via its own `_appliedVariant` (seeded from `Config.Appearance.variant` once at load, advanced only after `phi theme set` exits 0) rather than read back live from `Config.Appearance.variant` — hot-reloading a singleton's source file on disk is not a verified property-change notification on an already-bound consumer, and trusting it risked either silently re-running a full theme render every single tick, or resetting this singleton's own in-memory state mid-switch. A failed `phi theme set` keeps retrying on the next tick instead of getting stuck.
- Prefs (`scheduleMode`, custom start/end hour) live in a new plain JSON file, `Config.Paths.themeSchedulePrefsFile` — not `phi state`: the variant itself is still recorded there by `phi theme set` exactly as before, but *when* to switch has no meaning to any other `phi` consumer, so this needed no phi rebuild.
- `Settings/sections/Theme.qml`'s existing "Appearance" group gets a "Schedule" row (Off / Automatic / Custom hours, the same button-picker shape as Night shift's own schedule row) plus the matching custom-hours fields. The manual Dark/Light buttons are disabled while a schedule is active (so there's no conflicting control, matching Night shift's own precedent), and now stay in sync with the live variant via a `Connections` block on `Config.Appearance.variant` — needed because the button highlight previously only updated on its own click, and a schedule can now change the variant on its own.

### Honest assessment
Clean. The scope call worth flagging: the evening/morning window is a fixed default (20:00/7:00), not a real sunset/sunrise calculation — this project has no geolocation source anywhere, the same limitation Night shift's own "auto" mode already accepted and documented. "Custom hours" is the escape hatch if the fixed default doesn't fit. Not independently testable by me — this is a phi-shell UI/behavioural change and, per this repo's own rule, every visual result needs the user's own screenshot/verification; the `hyprctl reload` / variant-independence claim was verified by reading `design/tokens.common.sh` directly (it says so in its own comment), not by running anything.

### How to test it
1. Open Settings → Theme → Appearance. Confirm the existing "Variant" row (Dark/Light buttons) and a new "Schedule" row (Off / Automatic / Custom hours) are both there.
2. Click "Automatic". The Dark/Light buttons above should grey out (disabled), and the row's own description should read "Controlled by the schedule below." A new "Automatic window" line should appear stating the fixed default hours (20:00–7:00).
3. Click "Custom hours" instead. Two number fields appear, "Dark starts at" and "Light starts at", defaulting to 20:00 and 7:00 — change them (e.g. set "Dark starts at" to the current hour) and confirm the theme switches to dark within a few seconds to a minute.
4. With a schedule active, change your system clock (or just wait) past the boundary hour and confirm the variant switches automatically, with no visible flash, glitch, or shell restart — the bar, panels and settings should keep working throughout.
5. Click "Off" again and confirm the Dark/Light buttons re-enable and manual switching works as before.
6. Restart phi-shell (`pkill -x qs; qs -p ~/.config/quickshell/phi`) with a schedule active and confirm it comes back with the same schedule mode and hours (persisted in `$XDG_STATE_HOME/phi/theme-schedule.json`).

---

## No automatic battery saving mode

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** cf09afa shell: add an automatic battery saving mode, 66b5e7e merge: add an automatic battery saving mode
- **Original TODO:** have a battery saving mode, it automatically kicks in when not in charge and lower then 20% battery (automation can be toggled in the settings, there will be an alert, see next task ), configurable in the settings panel. automatically disabled when plugged in and over the threshold (if the user activates while it's charging, it should not disable automatically, this flag is cleared once the charge is plugget off again). It must have visual feedback on the battery in the status bar and settings. The battery overlay (from the status bar) must have the switch.
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
A battery saving mode that turns on by itself when unplugged and under 20%, turns back off once charged past that or plugged in (unless the user turned it on by hand while already charging, which should stick until the next real discharge cycle), with automation toggleable in settings, visual feedback on the bar and in settings, and a switch on the battery bar overlay specifically.

### What was done
- `Services/PowerBridge.qml` gains `batterySaverAuto` (the automation on/off switch, persisted) and `batterySaverActive` (the actual current state). The auto-on/auto-off state machine matches the entry's own wording exactly, including the charging-override exemption: activating manually while charging sets a flag that blocks auto-disable, cleared the next time a real discharge cycle starts (not merely by unplugging into a still-below-threshold state). Reuses `lowPercentThreshold` (0.20, this file's own pre-existing "<20% remaining" anomaly threshold) rather than adding a second percentage field — the entry names this feature's own threshold as a plain "20%", not as something to make separately configurable.
- **`batterySaverActive` is deliberately never persisted** — only the automation switch is. It's recomputed fresh from live battery state the moment this singleton starts, so a shell restart can't leave a stale "was active" hanging around with no real battery state to justify it.
- Two real, unprivileged actions while active — this session's own scope choice, since the entry never specifies what "saving" actually does: **screen brightness is capped at 40%** (`Services/Brightness.qml`), restored to its prior value on deactivation only if nothing else changed it in the meantime (the brightness keys, the OSD or the settings slider all win over saver's own restore if the user touched brightness while it was active); and **the lock screen's ambient effect is suppressed** — as a read-side check in `Lock/Lock.qml`'s own effect loader (`&& !Services.PowerBridge.batterySaverActive`), not by writing through `Config.LockPrefs`, so the user's actual chosen effect is never touched or at risk of being silently overwritten.
- Visual feedback: `Bar/modules/Battery.qml` shows an `"info"` tone on the battery bar segment while saver is active (the existing warn/error anomaly tones still win when both apply). `Panels/BarPopout.qml`'s battery overlay gets a "Battery saver" switch — the entry's own explicit requirement for that specific surface. `Settings/sections/Devices.qml`'s existing "Battery" group gets the automation on/off toggle, with its description stating the live threshold and what activating does.
- The entry's own parenthetical "(automation can be toggled in the settings, **there will be an alert, see next task**)" is already satisfied: "next task" was the low-battery full-screen alert, landed earlier this session as `Dialogs/BatteryAlert.qml`. Its default warn threshold (15%) fires *after* battery saver's own 20% trigger on the way down — checked deliberately, that ordering (saver first, then the more urgent alert) is the sensible one.

### Honest assessment
- **The two saving actions (dim to 40%, suppress the lock effect) are this session's own scope choice**, not named in the entry at all. A more "real" power-saving mode — CPU governor, other `/sys`-level changes — would need a privileged action this project has no sudoers drop-in for yet (rule 4, and unlike `phi vpn`/`firewall`, no such drop-in exists for anything battery-related); reaching for one wasn't in scope for this entry. Flagged for veto if stronger, privileged power-saving was actually expected.
- **`batterySaverAuto` defaults to `true`** — the plain reading of "it automatically kicks in," but it means the very first time this lands on a machine that happens to be unplugged and under 20%, brightness drops and the lock effect vanishes with no prior action from the user. The Settings toggle is the way to turn it off if that's unwanted.
- **The brightness cap does nothing visible below 40%** — if the screen is already dimmer than that, capping is a no-op (correct: never *raise* brightness for a "saving" mode) and the only visible feedback is the bar tone and the lock-screen change. Worth knowing before assuming it's broken on a machine already run dim.
- **The charging-override exemption does not survive a shell restart** — `batterySaverActive`/the override flag are both session-local by design (see "What was done"), so restarting the shell while the exemption is active loses it; a fresh discharge/charge cycle re-derives correctly on its own, but a shell restart mid-exemption is a real, narrow, documented gap.
- Cannot verify on real hardware (this repo's standing constraint) — in particular, whether the `"info"` bar tone reads clearly next to the existing warn/error tones, and whether the brightness restore-only-if-unchanged check behaves as intended against `brightnessctl`'s real timing, are both unverified from here.

### How to test it
1. Pull `phi-shell`'s `dev` (or wait for hot-reload if already running against a tracking checkout).
2. Open Settings → Devices → Battery. A new "Battery saver" row should appear at the bottom of that group, with a toggle (on by default) and a description naming the live threshold (20%).
3. Click the battery icon in the status bar to open its overlay — a new "Battery saver" row with its own switch should appear below "Time left".
4. With the automation toggle on, unplug the charger and let (or force, if testable) the battery drop under 20% — the battery bar icon's text/icon should take on a distinct, calmer colour (not the warn/error red/amber used for a critically low or fast-discharging battery), the screen should dim to 40% if it was brighter, and the lock screen (Super+L, or however it's triggered) should show no ambient effect even if one is selected in Settings → Theme.
5. Plug the charger back in while still under 20% — saver should stay on (brightness stays dimmed, no ambient effect) until the charge actually climbs past 20%, at which point brightness should return to whatever it was before saver turned on (unless you changed brightness yourself in the meantime, in which case it should stay wherever you left it) and the lock screen's ambient effect should return.
6. To test the manual-override clause specifically: with the charger plugged in and above 20%, use either switch (bar overlay or the automation toggle does NOT do this — only the bar overlay's own switch, or `Services.PowerBridge.setBatterySaverActive(true)` via IPC/dev tools, forces it on) to turn saver on by hand. It should stay on even though charging and above threshold, and should only turn off if you switch it off yourself, or once you unplug and then plug back in below threshold and back above it.
7. Turn the Settings automation toggle off — saver should no longer turn itself on automatically, though the manual switch on the bar overlay should still work on demand.

---

## No way to set a timer or alarm

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev (Services/Timers.qml, Dialogs/TimerAlert.qml, Settings/sections/Notifications.qml, Settings/sections/options.js, Config/Paths.qml, shell.qml), phi / dev (internal/query/timer.go, internal/query/query.go)
- **Commits:** phi-shell: 4935e1b shell: add timers and alarms with a full-screen alert and ringtone, fd50f1a merge: add timers and alarms with a full-screen alert and ringtone — phi: 195938e query: add a timer/alarm runner provider, a5e792f merge: add a timer/alarm runner provider
- **Original TODO:** add a timer and alarm feature to phi, also add tools to the runner to quicky setup timers and alarms. They should have a custom overlay that requires to be turned off, on the higher Z index in the system. It should have a ringtone. The two features must be customisable in the settings.
- **Requires phi rebuild:** yes — no tag covers this yet. `a5e792f` is only on `phi`'s `dev` (past the currently-published `v0.16.1`, which `main` still points to); merging `dev` into `main` is a user decision (`AGENTS.md` rule 1), so no new tag was created. Once merged, tag `vX.Y.Z` on `main` for this and any other pending `phi` changes to release together.

### What was asked
A timer and alarm feature reachable from the runner bar, with a full-screen overlay that has to be dismissed when one goes off, a ringtone, and settings to customise both.

### What was done
- **`Services/Timers.qml`** (new, phi-shell): owns the state — a list of timers (relative, "N seconds from now") and alarms (absolute clock time, optionally repeating on specific weekdays), persisted as JSON. A 1-second scheduler checks for anything due; a due item is queued (more than one can be due at once, e.g. after the machine was asleep through several alarm times) and shown one at a time. A repeating alarm's next occurrence is always computed fresh from the real current time on dismiss, not by walking forward from the stale time that just fired, so a long-suspended machine gets exactly the next real occurrence rather than a backlog of missed ones. The ringtone loops via `pw-play` (the same mechanism `Services/Notifications.qml`/`Services/PowerBridge.qml` already use) until dismissed, with a guard that stops looping the instant `pw-play` itself starts failing rather than tight-looping forever on a broken command. An IPC target `timer` (`add`, `addAlarm`, `cancel`, `dismiss`) is how anything outside this file — the runner, a terminal — actually sets one.
- **`Dialogs/TimerAlert.qml`** (new): the full-screen "requires to be turned off" overlay, copied structurally from `Dialogs/BatteryAlert.qml` (same layer, scrim, fade, focus and Escape/Enter/Dismiss handling already proven for that surface).
- **`internal/query/timer.go`** (new, `phi`): a runner provider recognising `timer <duration> [label]` ("timer 5m", "timer 25m tea") and `alarm <HH:MM> [label]` ("alarm 7:30", "alarm 19:45 wake up"), 24-hour clock only. Selecting a result runs `qs ipc call timer add/addAlarm ...` against the shell — **no new `phi timer` terminal verb was added**, a deliberate reading of "add ... to phi": a timer/alarm can only actually fire from something that keeps running for the whole session, which `phi` itself never does (a fresh process on every keystroke), the identical reasoning this codebase already applies to reboot/shutdown/volume/brightness/screenshot never becoming `phi` verbs. `internal/query` is compiled into the `phi` binary, so the request is still satisfied literally, just not as a standalone CLI command. Flagged for cheap veto if a bare terminal verb was actually wanted too.
- **Settings**: a new "Timers & alarms" group in `Settings/sections/Notifications.qml` — ringtone name/volume/test, and a live list of whatever is currently running with a Cancel button per row.
- A real bug caught and fixed during this session's own verification, not left latent: the first version of the runner provider returned a result from `Query()` but it never appeared in `phi query`'s actual output — `Rank()` (`internal/query/rank.go`) drops any result whose `Score` is left at its zero default and whose `Title` does not textually fuzzy-match the raw typed query, which a generated title like "Set a timer for 5m" never will against "timer 5m tea". Fixed by setting an explicit `Score: 100` (the same thing `CalculatorProvider` already does for the same reason), verified by hand with `phi query "timer 5m tea"` actually returning the result, and covered by a new regression test (`TestTimerProviderSurvivesRanking`) that runs the result through `Rank()`, not just the provider alone — so this class of bug fails a test next time rather than only showing up empty in a manual check.

### Honest assessment
- **The runner half needs the `phi` rebuild above; the shell half does not.** `Services/Timers.qml`/`Dialogs/TimerAlert.qml`/the settings group all work today, standalone, via `qs -p ~/.config/quickshell/phi ipc call timer add 300 tea` run from any terminal — that is the actual mechanism the runner provider calls into, so it can be exercised and verified in full before rebuilding `phi` at all.
- **No standalone `phi timer` CLI verb** — see "What was done" above. This is the one place the literal wording of the request and what got built diverge; the reasoning is real (ADR 021's own precedent), but it is this session's judgment call, not something the TODO said explicitly.
- **Alarm time input is 24-hour `HH:MM` only**, no am/pm. Not asked for either way; chosen to match this codebase's existing 24-hour-by-default convention rather than add a second parsing path.
- **"Automatic" repeat scheduling exists (`repeatDays`) but nothing in the runner syntax sets it** — `alarm 7:30` always creates a one-shot alarm. A repeating alarm can only be created via the raw IPC call (`addAlarm` takes a `repeatDays` array) today, not from typed runner text. Flagged as a real, narrower gap if repeating alarms from the runner bar specifically were expected.
- Cannot verify visually or on real hardware (this repo's standing constraint) — in particular, whether `pw-play` looping reads as a real ringtone (rather than, say, an audible gap or click between loop iterations) is unverified, and the settings list's live countdown display was checked by reading only, not seen on screen.

### How to test it
1. Rebuild and reinstall `phi` from `phi`'s `dev` branch (commit `a5e792f` or later) to get the runner integration; the shell half (steps 3-7) works today without this.
2. Pull `phi-shell`'s `dev` (or wait for hot-reload if already running against a tracking checkout).
3. From a terminal: `qs -p ~/.config/quickshell/phi ipc call timer add 10 "tea"` — a full-screen overlay should appear after 10 seconds, titled "Timer done", showing "tea", with a "Dismiss" button. Click Dismiss (or press Enter/Escape) — it should close.
4. `qs -p ~/.config/quickshell/phi ipc call timer addAlarm <next minute's hour> <next minute's minute> "wake up"` (e.g. if it's 14:32 now, use `14 33`) — the overlay should appear at that clock minute, titled "Alarm done", showing "wake up".
5. While either overlay is showing, you should hear a looping sound (the default ringtone, freedesktop's "message" sound) until you dismiss it.
6. Open Settings → Notifications → "Timers & alarms". Start a longer timer (`qs ... timer add 120 "test"`) and it should appear in the list here with a Cancel button and its due time; clicking Cancel should remove it and it should never fire.
7. In that same settings group, change the ringtone field to `bell` and click "Test ringtone" — a short loop of that sound should play for about 2 seconds and stop on its own.
8. Once `phi` is rebuilt: type `timer 5m tea` in the runner bar (Super+Space) — a result titled "Set a timer for 5m" should appear at or near the top of the list; selecting it should behave exactly like step 3's manual IPC call, just for 5 minutes instead of 10 seconds. Try `alarm 7:30 wake up` the same way.
9. Type `timer` alone (no duration) in the runner bar — it should offer no timer-related result at all, not a broken or zero-length one.

---

## Night shift has to be turned on and off by hand every evening/morning

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev (Services/NightShift.qml, Settings/sections/Theme.qml), phi / dev (internal/state/state.go)
- **Commits:** phi-shell: a68020c shell: add an automated schedule to night shift, 19fc248 merge: add an automated schedule to night shift — phi: a3e501d state: add nightmode.schedule keys for automated night-mode scheduling, d95360d merge: add nightmode.schedule keys for automated night-mode scheduling
- **Original TODO:** add option for automated night mode (automatic time at nighttime or manual hours range), with settings
- **Requires phi rebuild:** yes — no tag covers this yet. `d95360d` is only on `phi`'s `dev` (past the currently-published `v0.16.1`, which `main` still points to); merging `dev` into `main` is a user decision (`AGENTS.md` rule 1), so no new tag was created. Once merged, tag `vX.Y.Z` on `main` for this and any other pending `phi` changes to release together.

### What was asked
Night shift (the evening warm-colour display shift, `Services/NightShift.qml`) currently only turns on/off by hand. Add a way for it to switch automatically — either at some automatic nighttime, or on a manually-set hour range — with settings to control it.

### What was done
- `Services/NightShift.qml` gains `scheduleMode`: `"off"` (unchanged — the existing manual toggle), `"auto"` (a fixed 20:00–07:00 default window turns night shift on/off automatically), or `"custom"` (the same automatic on/off behaviour, using a user-set start/end hour instead of the fixed default). A 60-second `Timer` (matching the existing True Tone ambient-light timer's own interval) re-evaluates the schedule and flips `enabled` when it disagrees with the current wall-clock hour, handling a window that wraps midnight (the normal case — the "auto" default included).
- This is a clock-driven feature, distinct from and independent of True Tone just below it in the same settings group (which reacts to ambient light, not the time of day) — both can be on at once, same as before.
- Three new `phi state` keys (`nightmode.schedule`, `nightmode.schedule-start`, `nightmode.schedule-end`) since `phi state`'s key set is closed (`internal/state/state.go`), same shape as the pre-existing `nightmode.temp`/`toggle.night-mode`/`toggle.true-tone` rows.
- `Settings/sections/Theme.qml`'s "Night shift" group gets a mode picker (Off / Automatic / Custom hours, the same button-row picker already used for the ambient-effect and spotlight-effect choices elsewhere in this file) and, for Custom hours, start/end hour fields. The manual toggle is disabled (greyed via the same `WidgetStates` mechanism the pre-existing True Tone toggle already uses for its own disabled state) whenever a schedule is active, since the schedule owns `enabled` in that case.

### Honest assessment
- **`Requires phi rebuild` above is not optional context — it changes what "done" means for this feature.** Until the user rebuilds and reinstalls `phi` from `d95360d` (or later), `phi state set nightmode.schedule ...` is rejected by the currently-installed binary. The schedule still *works* within a running shell session (nothing here depends on the state file round-tripping mid-session), but the chosen mode and hours will not survive a shell restart — they'll reset to "Off" / 20:00–07:00 every time, silently, except for a `console.warn` in the shell's own log. Rebuild first, or expect the setting to not stick.
- **"Automatic" is a fixed 20:00–07:00 default, not a real sunset/sunrise calculation.** No geolocation source exists anywhere in this repo (`phi-shell` or `phi`) to compute an actual "nighttime" for wherever the machine is — building one would mean either a location permission/config surface that doesn't exist today or a network geolocation call, both out of scope for what this entry asked for. A fixed default was the scoped reading of "automatic time at nighttime." Flagged for veto — if a real sunset-based schedule was actually wanted, this doesn't deliver it, only "Custom hours" does (by hand).
- **Setting `scheduleStartHour === scheduleEndHour` is treated as "always on,"** not "always off" — documented in the source; a zero-width window has no other non-dead reading given hours only run 0–23.
- **Turning the schedule back to "Off" leaves `enabled` wherever the scheduler last set it**, rather than resetting to any particular state — flipping to Off at 3am while the schedule had it on leaves night shift on until the manual toggle is used. This matches how the toggle already behaved before this change (it always just holds whatever it was last set to); flagged in case a reset-on-Off behaviour was expected instead.
- Cannot verify visually (this repo's standing constraint) — in particular, whether `hyprctl hyprsunset` actually applies/reverts audibly-on-schedule the way it does for the existing manual toggle is assumed, not newly re-verified, since this reuses the exact same `_apply()`/`setEnabled()` path the manual toggle already exercises.

### How to test it
1. Rebuild and reinstall `phi` from `phi`'s `dev` branch (commit `d95360d` or later) — the new state keys will not save without it. Building here only produced a local `/tmp` binary for the round-trip check below; the user does the real install per `phi/CLAUDE.md`'s Releasing section.
2. Once reinstalled, pull `phi-shell`'s `dev` (or wait for hot-reload if already running against a checkout tracking it).
3. Open Settings → Theme → "Night shift". A new "Schedule" row should show three buttons: Off, Automatic, Custom hours.
4. Click "Automatic" — a new "Automatic window" line should appear below it reading "Fixed default — 20:00 to 07:00. …". The main "Night shift" toggle above should grey out and stop responding to clicks; its description should change to "Controlled by the schedule below."
5. Click "Custom hours" instead — two number fields, "Starts at" / "Ends at", should appear (0–23, step 1). Set them to something that includes the CURRENT hour (e.g. if it's 14:00 now, set Starts at 13, Ends at 15).
6. Within about a minute, the main "Night shift" toggle (still greyed/non-interactive) should flip to its "on" position on its own, and the display should visibly warm (same effect the manual toggle already produces) — no need to touch anything else.
7. Change the hours so the current hour falls OUTSIDE the window — within about a minute, night shift should turn itself back off and the display should return to normal.
8. Click "Off" — the toggle should become clickable again, staying at whatever state it was last in.
9. `phi state get nightmode.schedule` (and `-start`/`-end`) from a terminal should reflect whatever was last chosen in the UI, confirming step 1's rebuild actually took.

---

## No quick way to jot down a persistent scratch note

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** b3949d4 shell: add a persistent quick note corner tab, 7a3b584 land: add a persistent quick note corner tab
- **Original TODO:** add a quick note: when clicking the bottom right corder a quick floating editor window appears, it persists (save it in a specific folder in Documents). Positioning the mouse in the corner should have show a small transition (inspired by macos corner note) * this can be built using the default editor, however an improved version might be provided by the note app

### What was asked
A small, always-present corner surface that opens into a floating text
editor when clicked, growing/transitioning when the mouse approaches the
corner (the macOS "Notes" hot-corner gesture named in the TODO), whose
content is saved to a specific folder under Documents and survives
closing/reopening.

### What was done
- `Services/QuickNote.qml` (new): owns the note's text and open/closed
  state, debounced autosave (800ms after the last keystroke) to
  `$HOME/Documents/phiOS Quick Notes/quick-note.md` via a plain
  `Quickshell.Io.FileView` — the same mechanism already used for every
  other runtime-state file in this repo. Scoped as **one persistent
  note**, not a multi-note system: a separate, bigger "Notes app" idea
  already sits in `docs/TODO.md`'s own Ideas section as a distinct concept,
  and this entry's own wording treats that as a possible future upgrade,
  not what this task is building.
- `Panels/QuickNote.qml` (new): a small corner tab, always present,
  anchored to the true bottom-right screen corner with no margin (so the
  hot-corner fling the TODO describes actually lands on it), that grows on
  hover and expands into a full `Widgets.Panel`-based editor on click.
  Follows `Notifications/Toast.qml`'s established shape for small,
  non-blocking corner surfaces (a content-sized window, not full-screen,
  so it never intercepts clicks elsewhere on screen) rather than the
  full-screen-modal shape used by this repo's confirm/alert dialogs.
  `PanelWindow.implicitWidth`/`implicitHeight` are animated between the
  tab size and the editor size with a `Behavior`, gated on the fade-out
  actually finishing (not on the open/closed flag directly) so the window
  doesn't shrink out from under its own closing animation.
- `Config/Paths.qml` gains the note's directory/file paths, rooted at
  plain `$HOME/Documents` (not an XDG-user-dirs lookup — see Honest
  assessment). `shell.qml` registers one shared instance on the primary
  screen, same as every other focused/toggled (not per-monitor) surface
  in this repo.

### Honest assessment
Everything here is a deliberate scope decision, not a shortcut, but check
each one:
- **One note, not a note library.** If what was actually wanted is
  multiple named notes, this is the wrong shape — that's the separate
  "Notes app" idea the TODO itself points at.
- **`$HOME/Documents` is hardcoded**, not resolved through XDG user-dirs
  (`~/.config/user-dirs.dirs`). A user whose Documents folder is relocated
  gets a note written to the wrong place. Fixing this properly would need
  either a new package dependency (`xdg-user-dirs`, not currently declared
  anywhere in `phios-dotfiles`) or async file parsing this repo's
  `Config/Paths.qml` deliberately avoids elsewhere. Documented as a known,
  narrow gap rather than fixed blind.
- **Animating a `PanelWindow`'s own `implicitWidth`/`implicitHeight` via
  `Behavior` is new in this repo** — every other surface here is either
  fixed-size or full-screen; nothing else animates a layer-shell surface's
  own geometry. Whether Hyprland renders that resize smoothly or snaps it
  is genuinely unverified from here (see below).
- **Single instance on the primary screen, not per-monitor** — flagged for
  cheap veto, same standing caveat every prior single-vs-per-screen
  surface in this repo carries.
- Cannot verify visually at all (this repo's standing constraint) — doubly
  true here given the novel animated-window-geometry technique above, with
  no prior sibling in this repo to sanity-check the approach against.

### How to test it
1. `pkill -x qs; qs -p ~/.config/quickshell/phi` to get a fresh process
   (or just wait for hot-reload after pulling `dev`).
2. Look at the bottom-right corner of the primary screen — a small,
   semi-transparent accent-coloured square tab should be visible, sitting
   flush in the true corner.
3. Move the mouse over it — it should grow noticeably and brighten.
4. Click it — it should expand into a floating panel titled "Quick note"
   with a text editor, growing/animating rather than appearing instantly.
5. Type some text, then click "Close" (or press Escape). The panel should
   shrink back down to the small corner tab.
6. Run `cat ~/Documents/"phiOS Quick Notes"/quick-note.md` — it should
   contain the text just typed (autosave fires ~800ms after the last
   keystroke, so check a second or two after typing, not instantly).
7. Click the tab again — the editor should reopen with the same text still
   there (seeded from the saved file / the in-memory value, whichever is
   current).
8. Restart the shell (`pkill -x qs; qs -p ~/.config/quickshell/phi`) and
   reopen the note — the text should still be there, confirming the save
   actually persisted to disk rather than only in memory.

---

## Lock screen ambient effect: no way to add more types, no live preview in settings

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** c8f49d1 lock: add plasma and life ambient effects, live preview in settings, 43b0eb4 merge: add plasma and life ambient effects, live preview in settings
- **Original TODO:** ad settings specific for the "ambient effect". Add more types to pick, taking inspirations by cool terminal effects or screensavers (always only played in the lock screen). Also add a live preview of the effect in the settings when one is selected

### What was asked
More lock-screen ambient effect choices (the existing set was lava lamp,
matrix rain, starfield), inspired by terminal effects/screensavers, plus a
live preview in Settings so picking one shows what it looks like without
having to actually lock the screen.

### What was done
- Two new effects, both classic terminal/screensaver references:
  **Plasma** (`Lock/Plasma.qml`) — the demoscene/XScreenSaver plasma
  effect, three overlaid sine waves on a coarse grid, coloured through
  the same accent/info pairing the existing lava lamp already uses.
  **Life** (`Lock/Life.qml`) — Conway's Game of Life (the real inspiration
  for several actual terminal screensavers), standard rules on a
  wraparound grid, advancing one generation every 10 redraw ticks (not a
  new timing value — a frame-skip ratio layered on the same shared redraw
  interval every existing effect already uses) so it reads as a pattern
  rather than flicker, with cells fading between states. A board that
  dies out completely reseeds itself rather than going permanently blank.
- Both wired into `Config/LockPrefs.qml` (the known-effects list) and
  `Lock/Lock.qml` (the effect loader), the exact same shape the three
  existing effects already use.
- `Settings/sections/Theme.qml`: a new "Ambient effect preview" group
  (same `preview: true` treatment as the existing "Colour preview" group)
  runs the currently-selected effect live, in a fixed-size box, right
  below the picker — updates instantly when a different effect is chosen.

### Honest assessment
Which two effects to add was not specified by the TODO — "cool terminal
effects or screensavers" named no particular ones, so Plasma and Life are
my pick, not a literal instruction. Landing exactly two, not more, was
also a judgment call — each addition is small and mechanical (a new
Canvas file following the established contract, one switch case, one
picker entry), so more are a cheap follow-up if two isn't enough variety.

The preview box's aspect ratio is a plain wide rectangle, shorter and
wider than a real lockscreen. Plasma's grid is a smooth colour field, so
it should still read fine at that ratio; **Life's 48×27 grid may render
as visually noisy, squashed slivers in the shorter preview box** — its
cell math is unchanged from what runs on the real lock screen, only the
box it's rendered into is a different shape. If it looks bad in the
preview specifically, the fix is sizing the preview box itself (or
deriving each effect's grid from the box's own aspect ratio), not a
rewrite of the effect.

The preview runs continuously (Canvas repainting roughly 41 times a
second) for as long as the Theme settings page is open — fine on a
desktop, worth knowing about for battery use on `razer` if the Theme page
is left open.

Cannot verify any of this visually — the usual `phi-shell/CLAUDE.md` "you
cannot run this" limit, doubly true here since these are the first two
effects in this project with no prior hardware-verified sibling to sanity
against (lava/matrix/starfield all have real usage history; plasma/life
do not).

### How to test it
1. Pull `phi-shell` `dev` and reload Quickshell.
2. Open Settings → Theme → "Lock screen". The "Ambient effect" row should
   now show six buttons: None, Lava lamp, Matrix, Starfield, Plasma, Life.
3. Click "Plasma". A new "Ambient effect preview" group should appear
   right below (or update if already showing) with a live, moving
   colour-field animation inside a framed box.
4. Click "Life". The preview should switch to a grid of cells appearing,
   surviving, dying and reappearing — check whether it reads as a
   recognisable pattern or just noise at this box size (see the honest
   assessment above).
5. Click "None" — the preview group should disappear entirely.
6. Lock the screen (however you normally do — SUPER+L, double-tap, per
   the entry above) with Plasma or Life selected, to confirm the same
   effect actually plays full-screen on the real lock surface, not just
   in the settings preview.

---

## SUPER+L locks immediately, with no way to suspend/hibernate/shut down/reboot from the keyboard

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev, phios-dotfiles / dev
- **Commits:** phi-shell: 392085f power: SUPER+L opens a power menu, double-tap still locks instantly, bddfe6e merge: SUPER+L opens a power menu, double-tap still locks instantly — phios-dotfiles: 9d47b9a hypr: SUPER+L dispatches to the new power-menu IPC target, aacdf9e merge: SUPER+L dispatches to the new power-menu IPC target
- **Original TODO:** when pressing SUPER+L instead of locking immediatly, evoke an overlay menu with options (lock, suspend, hibernate, shutdown, reboot). Use a smart UI/UX grammar and hierarchy, add icons with hover animations. SUPER+L+L (double click) will instantly lock (same behavior as now).

### What was asked
SUPER+L should open a power menu (lock/suspend/hibernate/shutdown/reboot)
instead of locking straight away, styled with icons and hover animation.
A quick double-press of SUPER+L should still lock instantly, matching
today's behaviour, without the menu getting in the way.

### What was done
- `phios-dotfiles/hyprland.lua.tmpl`: SUPER+L's bind now dispatches
  `qsIpc("powerMenu", "trigger")` on every press, unconditionally — the
  same shape as the direct-lock call it replaces. No timing/double-tap
  logic lives in Hyprland at all.
- `phi-shell/Services/PowerMenu.qml` (new): owns the double-tap timing.
  Every press calls `_onTrigger()`; if a second press lands within 350ms
  of the first, it's treated as a double-tap — cancels the pending
  menu-open and locks instantly via `Services.PowerActions.lock()`
  (the same call `Panels/BarPopout.qml`'s existing power card already
  uses). Otherwise, after 350ms with no second press, the menu opens.
  Deliberately a new file with a new IPC target (`"powerMenu"`), not an
  addition to `Lock/Lock.qml`'s own IPC handler — that file is the one
  place the lock state ever flips true, and keeping it untouched means
  nobody has to re-verify that security-critical path around new timing
  logic.
- `phi-shell/Dialogs/PowerMenu.qml` (new): a full-screen modal (same
  `WlrLayer.Overlay` + scrim + layer-focus shape as the existing
  `ConfirmDialog`/`BatteryAlert`), five rows (lock/suspend/hibernate/
  shutdown/reboot) using the existing `Widgets.ListRow` — which already
  animates its own background on hover, so "hover animations" needed no
  new mechanism. Shutdown/reboot still go through the existing
  `Services.ConfirmDialog` "this cannot be undone" step, matching how the
  bar's own power card already handles those two.

### Honest assessment
<span style="color:red">**NOT DONE: icons on four of the five
rows.**</span> Only "Shut down" has one (reusing the bar's own existing
power glyph). The TODO explicitly asked for icons throughout, and I could
not responsibly add the other four: this session tried to confirm real
Nerd Font codepoints against `nerd-fonts`' own `glyphnames.json` (the
established, hardware-tested method `Bar/glyphs.js`'s own comments cite
for its prior fixes) and got genuinely contradictory results across
several attempts — a lookup that said "not found" on one try and "found"
on a retry, and a claim that this project's own already-shipped `nf-md-*`
codepoint family isn't in the source file at all, which can't be right
since a dozen of them are already live in the bar. `Bar/glyphs.js`'s own
history is two separate user-reported bugs (the Steam icon, the
scratchpad console icon) from a past session guessing a codepoint instead
of confirming it — repeating that risk here, blind, seemed like the worse
choice. Every row still shows its full text label regardless, so a
missing icon never means a missing or unlabeled option — same
graceful-degradation stance `Bar/glyphs.js`'s own header already commits
to. Re-added a narrower TODO entry for just this piece.

The double-tap window (350ms) is a judgment call, not a spec'd number —
easy to change in `Services/PowerMenu.qml` if it reads as too fast or
too slow on real hardware. A single SUPER+L press while the menu is
already open currently does nothing (it doesn't close it) — not asked
for either way, left as the simplest behaviour rather than guessed at.

Cannot verify any of the visual result, the timing feel, or the actual
keybind on real hardware — the Lua side got the strongest verification
available in this repo (a fresh `phi` build, `phi theme render --variant
dark`, and `luac -p` — `SYNTAX OK` on the whole rendered file), but that
only proves the config is syntactically valid and substitutes correctly,
not that the double-tap timing feels right in the hand.

### How to test it
1. Pull both `phi-shell` and `phios-dotfiles` `dev`, re-render/reload the
   Hyprland config (however you normally do after a `phios-install` run),
   and reload Quickshell.
2. Press SUPER+L once and let go. After a brief pause, a centered "Power"
   menu should appear over a dimmed screen, listing Lock, Suspend,
   Hibernate, Shut down, Reboot.
3. Click "Lock" — should lock immediately, same as SUPER+L always did.
4. Reopen the menu (SUPER+L, wait) and click "Shut down" or "Reboot" —
   should show the existing "this cannot be undone" confirmation instead
   of acting immediately.
5. Press Escape, or click outside the menu card — it should close with no
   action taken.
6. Press SUPER+L TWICE quickly (a real double-tap, not two slow separate
   presses) — the screen should lock immediately, and the power menu
   should not visibly appear first.

---

## No way to see or connect to available Wi-Fi networks from the shell

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** c97476c wifi: show available networks on click, connect to known/open ones, 37df5dd merge: show available wifi networks on click, connect to known/open ones
- **Original TODO:** clicking on the wifi icon should show the list of available wifi to connect. Same in the settings.

### What was asked
Clicking the wifi bar icon (and the equivalent place in Settings) should
show the list of nearby Wi-Fi networks, with a way to connect to one.

### What was done
- `Services/WifiBridge.qml`: Quickshell's own Network API exposes neither
  signal strength nor security type for a network (confirmed against real
  Quickshell source, `network.hpp`/`device.hpp` — a `Network` has only
  `name`/`device`/`connected`/`known`/`state`), so the scan itself shells
  out to `nmcli`, the same tool the pre-existing "Manage networks…" button
  already depends on (`nmtui`). `rescan()` triggers a real scan and
  `refreshNetworks()` parses `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY
  device wifi list` (terse mode, backslash-escaped, parsed accordingly —
  a naive `.split(":")` would break on an SSID containing a colon),
  de-duplicated by SSID and sorted connected-first then by signal.
- `connectToKnownNetwork(ssid)` joins an already-known (previously saved)
  or open network — no secret needed either way, so no security concern.
- `Widgets/WifiNetworkList.qml`: a new shared component — scan status, an
  error line, one row per network showing signal % and status (Connected/
  Saved/Secured/Open) — used by both `Panels/BarPopout.qml`'s wifi card
  and `Settings/sections/Connectivity.qml`'s Wi-Fi group, so the two
  places stay in sync instead of carrying separate copies.

### Honest assessment
<span style="color:red">**NOT DONE: connecting to a new, secured network
you have never joined before.**</span> That path needs a password, and
`nmcli device wifi connect <ssid> password <pw>` — the obvious way to
supply one — puts the password on the process's own command line, which
is world-readable to any local user via `/proc/<pid>/cmdline` for as long
as the command runs. That is a real credential leak, not a theoretical
one, and I will not ship it. I checked nmcli's own documentation for an
argv-free alternative: `--ask` is explicitly documented as interactive-
only ("do not use this option for non-interactive purposes like scripts")
and reads the controlling terminal directly, not a redirected stdin, so
it cannot be driven programmatically here. The one real argv-free
mechanism nmcli offers, `passwd-file`, only works with `nmcli connection
up` — which first needs a `connection add` carrying the correct
`wifi-sec.*` property names for whichever security type the network
actually uses (WPA-PSK, WPA3-SAE and WEP each need different fields), and
I have no way to verify that's right without real Wi-Fi hardware to test
against (`phi-shell/CLAUDE.md`: "you cannot run this"). Getting it wrong
would mean a silent connect failure on exactly the networks a user is
trying to join.

Tapping a secured network you've never connected to before is a no-op in
the new list — it shows its status ("Secured") but does nothing on click.
The existing "Manage networks…" button (→ `nmtui`, right below the list
in both surfaces) already has a real, working password prompt and is the
way to join a new secured network today. Re-added a narrower TODO entry
for this specific remaining piece, in case a safe path becomes clear
later (or someone can verify the `connection add`/`wifi-sec.*` fields on
real hardware).

Everything else (the scan, the list, connecting to a known or open
network) cannot be visually or functionally confirmed without real Wi-Fi
hardware either — the usual limit for this repo.

### How to test it
1. Pull `phi-shell` `dev` and reload Quickshell.
2. Click the wifi icon in the bar. The popout should show "Scanning…"
   briefly, then a count ("N networks found") and one row per nearby
   network, each showing a status and signal percentage (e.g. "Saved ·
   62%", "Open · 40%", "Secured · 21%", or "Connected · 80%" for the
   current network).
3. Tap a row marked "Saved" or "Open" (not the currently-connected one).
   It should attempt to connect with no password prompt — check `nmcli
   device wifi list` or the "Network" row above the list afterward to
   confirm it actually joined.
4. Tap a row marked "Secured" that you've never connected to before.
   Nothing should happen (by design — see above). Use "Manage networks…"
   below the list to join it via `nmtui` instead, the same as before this
   change.
5. Click "Refresh" — it should re-trigger a scan and, after a few
   seconds, refresh the list.
6. Repeat steps 2–5 in Settings → Connectivity → Wi-Fi → "Available
   networks" — same list, same behaviour, different surface.

---

## No overlay for low battery level

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev (no new code — see below)
- **Commits:** none — the overlay itself landed as part of the entry directly below this one (`c6e101b`/`0f54930`)
- **Original TODO:** add an overlay for low battery level, with option to set on battery saving mode if not up yet (see previous task)

### What was asked
Two things: a low-battery overlay, and — inside that overlay — an option
to turn on "battery saving mode" if it isn't already active (referencing
the sibling "battery saving mode" backlog entry, still open, directly
above this one in `docs/TODO.md`).

### What was done
The overlay half is already covered: `Dialogs/BatteryAlert.qml`, built
and landed for the separate "full screen alert should appear when battery
level is low" entry immediately before this one in this same session, IS
a low-battery overlay — same feature, described twice in the backlog from
two angles. No separate overlay was built for this entry; it would have
duplicated that one.

### Honest assessment
<span style="color:red">**NOT DONE:** the "option to set on battery
saving mode" clause.</span> "Battery saving mode" itself (the sibling
entry this one explicitly references, "have a battery saving mode, it
automatically kicks in when not in charge and lower then 20%...") does
not exist yet — there is nothing for a toggle in this overlay to turn on.
Building that toggle now would mean either wiring it to a no-op, or
building battery-saving-mode itself as an incidental side effect of this
entry rather than as its own considered piece of work. Left for whenever
the "battery saving mode" entry itself is picked up — at that point,
adding a toggle to `Dialogs/BatteryAlert.qml` (or its "danger"-severity
card specifically, which is the more natural place for it) is a small
addition on top of what already exists, not a new surface.

### How to test it
Nothing new to test here — see the "No warning when the battery is about
to run out" entry below for how to test the overlay itself.

---

## No warning when the battery is about to run out

- **Date:** 2026-09-14
- **Repo / branch:** phi-shell / dev
- **Commits:** c6e101b battery: full-screen alert at configurable warn/danger thresholds, 0f54930 merge: full-screen low-battery alert at configurable warn/danger thresholds
- **Original TODO:** full screen alert should appear when battery level is low (2 thresholds warn and danger, configurable)

### What was asked
A full-screen alert that appears when the battery is low, with two
separately configurable thresholds — a less urgent "warn" level and a
more urgent "danger" level. (Deliberately scoped to just this alert, not
the separate, still-open "battery saving mode" backlog entry — that one
needs real root/systemd actions this environment can't verify and is
tracked on its own.)

### What was done
- `Services/PowerBridge.qml`: two new configurable thresholds,
  `alertWarnThreshold` (default 15%) and `alertDangerThreshold` (default
  5%), persisted to a new `battery-alert.json` state file. `alertLevel`
  ("none"/"warn"/"danger") is computed from the live battery percentage,
  gated so it can never fire while charging, while the battery is absent,
  or on a machine with no battery capability at all (`mini`).
- A dismiss/escalation state machine: dismissing the alert silences it for
  the current severity, but if the battery keeps dropping and crosses into
  the more urgent threshold, the alert re-opens at "danger" even if "warn"
  was already dismissed. The reverse (recovering from danger back to warn)
  stays quiet. Once the battery is no longer low at all (charged back up
  or plugged in), the dismissal is forgotten, so the next time it drops
  low is a fresh alert, not permanently suppressed by one old dismissal.
- `Dialogs/BatteryAlert.qml`: a new full-screen modal — dim scrim,
  centered card, "Battery low" / "Battery critically low" title (coloured
  warn/error to match), current percentage, and a single Dismiss button
  (also Enter/Escape). Built on the exact same layer-shell plumbing as the
  existing `Dialogs/ConfirmDialog.qml` (`WlrLayer.Overlay` +
  `exclusiveZone: -1` + a scrim that covers the bar), but its own
  self-contained state rather than reusing `Services.ConfirmDialog` — that
  singleton force-closes every other open panel when it opens, which is
  right for a confirmation the user just triggered but wrong for a
  spontaneous low-battery alert that shouldn't interrupt whatever else is
  open.
- `Settings/sections/Devices.qml`: two new rows in the existing "Battery"
  group — "Warn threshold" / "Danger threshold" (both shown and edited as
  whole percent), and a "Test alert" row with "Test warn" / "Test danger"
  buttons that show the real dialog without needing to actually drain a
  battery down to 5%.

### Honest assessment
Three judgment calls worth a look, none of them hidden requirements, all
things a different call could easily be made on:

- **A pre-existing threshold now sits right next to this one, at a
  different value.** `Bar/modules/Battery.qml`'s bar icon already turns
  red (`tone: "error"`) below `PowerBridge.lowPercentThreshold` (20%,
  unrelated to this change). This new alert's own "danger" threshold
  defaults to 5% — lower. That means the bar icon will already be red for
  a while before the full-screen alert ever appears, which may read as
  inconsistent. Deliberately did NOT unify the two (see the commit
  message) since the bar's threshold is a different, already-shipped
  concern with its own history — but if a single unified threshold is
  actually wanted, say so and I'll fold them together.
- **The escalation/dismissal behaviour is invented, not specified.** The
  TODO only asked for "2 thresholds, configurable" — the rule that
  dismissing "warn" doesn't suppress a later "danger", but dismissing
  "danger" does suppress a later "warn" if it recovers, is my own call
  about what a sane low-battery alert should do, modeled loosely on how
  desktop OSes already behave. Veto/adjust if a simpler "always show,
  every time it's low" (or the opposite — dismiss once, stay dismissed
  until fully recharged) was actually wanted.
- **This is the first spontaneous surface in this repo to take keyboard
  focus.** Every other `Services.LayerFocus` consumer (Sidebar, Settings,
  ConfirmDialog, Cheatsheet) is something the user just opened themselves.
  This alert can pop up uninvited — if it fires while typing somewhere
  else, that keystroke goes to the dialog instead. This is a deliberate
  choice (a full-screen alert reads as meant to interrupt), not an
  oversight, but flagging it explicitly since it's a new category of
  behaviour for this shell.

Cannot verify any of the visual/behavioural result on real hardware — the
usual `phi-shell/CLAUDE.md` "you cannot run this" limit. The QML was
statically re-read for the two known landmines this session already hit
twice (a duplicate `Component.onCompleted` on one object, a reserved word
used as a property name) — neither is present in the new files.

### How to test it
1. Pull `phi-shell` `dev` and reload Quickshell (`pkill -x qs; qs -p
   ~/.config/quickshell/phi`, or just save any `.qml` file to trigger a
   hot reload if the shell is already running).
2. Open Settings → Devices → Battery (requires a machine with a battery —
   the whole group is disabled on `mini`). Two new fields, "Warn
   threshold" and "Danger threshold", default to 15% and 5%. Change either
   and confirm it sticks after a reload (`cat
   $XDG_STATE_HOME/phi/battery-alert.json` should show the new values).
3. Click "Test warn" in the new "Test alert" row. A full-screen dim should
   appear with a centered card reading "Battery low", the current battery
   percentage, and a Dismiss button, coloured with the warn (not error)
   tone. Click Dismiss (or press Enter/Escape) — it should fade out.
4. Click "Test danger". Same overlay, but the title reads "Battery
   critically low" and uses the error tone instead.
5. The real test: unplug the charger and let the battery actually drop
   below the warn threshold (or lower the threshold to just above the
   current battery level first, to avoid a long wait). The alert should
   appear on its own, without touching the Test buttons. Plug the charger
   back in — the alert should not reappear until the next time the battery
   genuinely drops low again.

---

## Three-finger trackpad/touchscreen gestures for overview and workspace switch

- **Date:** 2026-09-14
- **Repo / branch:** phios-dotfiles / dev (no code change — see below)
- **Commits:** none — docs-only, see the superproject commit landing this entry
- **Original TODO:** three finger gestures on trackpad and touchscreen: up/down (open/closes overview, alredy workinf), left/right (change workspace). Add more if not too error-prone.

### What was asked
Three-finger swipe up/down should open/close the overview (already working
per the entry's own text), and three-finger swipe left/right should switch
workspace — on both trackpad and touchscreen — plus "add more [gestures]
if not too error-prone" as an open-ended, optional invitation.

### What was done
No code change. Before starting, checked whether this already existed —
`profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`'s GESTURES
section already implements exactly this, landed in commit `c204c58`
("hypr: workspace prev/next on keyboard and 3-finger swipe", 2026-09-10,
well before this backlog entry was worked): three-finger up/down already
opens/closes the unified Alt+Tab/overview surface (the entry's own text
confirms this half already works), and three-finger left/right already
dispatches `workspace m+1`/`m-1` (monitor-relative, wrapping). The commit's
own message notes Hyprland 0.51+'s unified gesture engine fires the same
`hl.gesture` bind from both the touchpad and the touchscreen with no
separate per-device config needed, satisfying the "trackpad and
touchscreen" half of the request. Both binds are `pcall`-wrapped so a
Hyprland build rejecting a direction token can't abort the whole config
reload. Removed the duplicate backlog line rather than leaving it to be
rediscovered and re-investigated.

### Honest assessment
The core, concrete ask (up/down + left/right, both device classes) is
fully built and was apparently already working per the entry's own text
for at least the up/down half. The trailing "add more if not too
error-prone" is a vague, explicitly optional invitation, not a concrete
requirement — no specific additional gesture is named, so nothing further
was added. If a specific extra gesture was actually wanted (pinch to
zoom, four-finger something, etc.), re-add a bare entry naming it
specifically.

### How to test it
1. On `razer` (the only machine with both a touchpad and a touchscreen),
   swipe up with three fingers on either input — the overview/Alt+Tab
   surface should open. Swipe down with three fingers to close it.
2. Swipe left with three fingers — the focused monitor's workspace should
   switch to the next one (`m+1`), wrapping around at the highest
   workspace. Swipe right — switches to the previous one (`m-1`).
3. If any of the four directions do nothing, check `hyprctl` logs for a
   rejected gesture direction token (the left/right binds are wrapped in
   `pcall` specifically because this is a possibility on some Hyprland
   builds) — that would mean this Hyprland version needs the gesture
   syntax re-verified against its own docs, not that the config is wrong.

---

## Hyprland scratchpad doesn't slide in, has no extra spacing, focus not visible

- **Date:** 2026-09-14
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** 27d54e9 hypr: fix scratchpad focus-visibility, add slide-from-bottom + wider gaps
- **Original TODO:** the hyprland scratchpad should slde in from below, have slighlty more out spacing than other workspace and have a accent-colored border all around the screen. I think an old change made windows in the scratchpad had thiink borders, that has to be removed (i can't even see which one is focused) and restored to default, the border should be at the edge of the screen, like the whole workspace is bordered.

### What was asked
Three things about the `special:scratch` workspace: (1) it should slide in
from below the screen instead of however it currently appears/disappears,
(2) it should have slightly more outer spacing (gaps) than a normal
workspace, (3) the accent-colored border around the scratchpad window
should only apply to the focused window — right now it seems to stay
accent-colored regardless of focus, making it impossible to tell which
window (if more than one is open in the scratchpad) actually has focus.

### What was done
In `profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`, in the
existing `special:scratch` section (added by an earlier, already-verified
TODO entry that built the accent border and the recognisability behaviour):

- Added a new `hl.workspace_rule({ workspace = "special:scratch", animation
  = "slidevert", gaps_out = 30 })`. `slidevert` is Hyprland's built-in
  vertical slide animation; for a special workspace with no direction
  argument it defaults to sliding in from the bottom (confirmed via
  upstream discussion, not assumed). `gaps_out = 30` is a per-workspace
  override of the outer gap — nothing else in this repo sets a
  `general:gaps_out`, so this is a fixed 30px value, not a token; see the
  honest caveat below about whether this actually reads as "wider."
- Changed the existing `scratchpad-border` `hl.window_rule`'s
  `border_color` from the two-token form `"${PHI_ACCENT} ${PHI_ACCENT}"`
  (active and inactive both accent) to the single-token form
  `"${PHI_ACCENT}"` (active only — inactive falls through to Hyprland's own
  default border colour). This is a **deliberate reversal of part of the
  earlier, already-signed-off TODO entry** that built this border: that
  entry's own comment explains it chose the two-token form specifically so
  "the border would vanish the instant the scratchpad window lost focus,
  defeating 'recognisable'." This new entry's complaint — "i can't even
  see which one is focused" — is the opposite problem, and fixing it means
  giving back some of that earlier recognisability: when focus moves to a
  window on the underlying workspace while the scratchpad is still shown,
  the scratchpad's border now reverts to Hyprland's default inactive
  colour instead of staying accent-colored. There is no stock Hyprland
  mechanism for a workspace-level frame that stays lit while any window in
  that workspace is visible but none of its windows has focus — only
  per-window active/inactive border colour exists — so this was a genuine
  either/or, not a bug in the original implementation.

### Honest assessment
<span style="color:red">**NOT DONE (trade-off, not oversight):**</span>
the scratchpad border no longer stays accent-colored when focus leaves it
for a window on the underlying workspace — it now only lights up while a
scratchpad window is actually focused. If you want both "always
recognisable while visible" AND "shows which window has focus," that needs
a different mechanism (there isn't one in stock Hyprland for a
workspace-level frame) — say which one matters more if this isn't the
right trade.

`gaps_out = 30` is a guess at "slightly more" relative to Hyprland's
*compiled-in* default, which this repo has never overridden globally —
it is not necessarily 20px today. If the scratchpad's edge spacing doesn't
visibly read as wider than an ordinary workspace's, the fix is a one-number
bump in this same rule, not a redesign.

Verification for this change is stronger than usual for a Hyprland/Lua
config edit but still not a real render: built `phi` fresh, ran
`phi theme render --variant dark` on this exact template with real design
tokens, confirmed `border_color` substitutes to a single hex token and the
new `workspace_rule` block renders with the right field names/values, and
ran `luac -p` on the full rendered output — `SYNTAX OK`. None of that
proves the animation direction, the gap size, or the border behaviour
actually look right on screen; that still needs Hyprland running on real
hardware.

### How to test it
1. Pull the latest `phios-dotfiles` `dev` and re-render/re-apply the
   Hyprland config so `hyprland.lua.tmpl` picks up the change (however you
   normally reload Hyprland config after a `phios-install` run — e.g.
   `hyprctl reload` after `phios-install` regenerates `~/.config/hypr/`).
2. Open the scratchpad (whatever your bind is, e.g. `SUPER+S` if that's
   still the default). It should slide in from the bottom edge of the
   screen, not pop in or slide from another direction.
3. While it's open, compare its edge-to-screen spacing against an ordinary
   workspace's tiled windows. It should look visibly more spacious around
   the edges. If it looks the same or tighter, tell me and I'll raise
   `gaps_out` further.
4. With the scratchpad window focused, confirm its border is
   accent-colored (same as before).
5. Click a window on the underlying regular workspace (without closing the
   scratchpad) so focus leaves the scratchpad. Confirm the scratchpad
   window's border now shows Hyprland's normal inactive-border colour, not
   accent — and that with more than one window in the scratchpad, you can
   now tell which one is focused by which has the accent border.

---

## Backlog asked to "add a color picker"

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev (no code change — see below)
- **Commits:** 2b9cb84 todo: remove stale color-picker entry, already built and bound
- **Original TODO:** "add a color picker"

### What was asked
A bare feature request, no detail beyond the three words.

### What was done
No code change — before starting, checked whether this already existed, the same check applied to every entry this session. `Screenshot/ColorPicker.qml` already implements exactly this: a click-to-sample eyedropper that reads the pixel under the cursor via ImageMagick's `magick ... -format "%[pixel:p{X,Y}]" info:`. It's real, master-plan-named work (§8.3 surface 20, "Colour picker (capture plus pixel read)"), built in commit `d9f6d47` — well before the current backlog era, not something from a recent session — and it's live-bound: Super (screenshot submap) then C. Removed the duplicate backlog line rather than leaving it to be re-discovered and re-investigated later.

### Honest assessment
Unlike the calendar flip-clock entry earlier in this file (also initially suspected stale, but turned out to be a fresh, specific complaint about an existing feature that needed real work), this one carries no evaluative language at all — no "doesn't work," no description of what's wrong with the existing picker, nothing suggesting the user had it in mind and found it lacking. That asymmetry is the basis for treating this one as genuinely stale rather than doing the same deeper check the flip-clock entry got. If a color picker with different requirements was actually intended (system-wide outside the screenshot flow, a persistent swatch history, copy-to-clipboard format options, etc.), this removal was wrong — re-add a bare, undecorated entry describing what's actually missing from the existing one.

### How to test it
1. Press and hold Super, then press C (the screenshot submap's colour-pick bind).
2. A crosshair cursor should appear over the whole screen — no visible dim or overlay chrome, just the cursor shape change.
3. Click anywhere. Expected: the crosshair disappears (no toast or confirmation — this is deliberately silent, matching how the screenshot save flow's own clipboard copy works) and the clicked pixel's colour, as a `#RRGGBB` hex string, is now on the clipboard — paste anywhere to confirm (`wl-paste` in a terminal, or paste into any text field).

---

## Status bar overlays (bar popout, calendar) sit lower than they should, despite repeated fixes

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 2c4b01b bar: fix exclusiveZone so the bar popout and calendar overlay actually sit below the bar, 5c39e70 merge: fix exclusiveZone so the bar popout and calendar overlay actually sit below the bar
- **Original TODO:** "the status bar overlays (those that open with the status bar icons) are still lower that they should be. This has been fixed many times but changes never worked. Clean up the whole feature and make it so that the overlay is few px below the bar. The gap variable is now of few px, clearly it's not an issue of gap, they probably have a fixed position or a wrong parent relative position or something like that."

### What was asked
`Panels/BarPopout.qml` (the small card that drops from a bar icon — volume, brightness, wifi, power, etc.) and `Panels/Calendar.qml` (the calendar overlay from clicking the bar clock) sit visibly too far below the bar, and the user had already tried fixing this more than once without success — asked for the whole mechanism to be cleaned up rather than another margin tweak.

### What was done
Read every overlay-style `PanelWindow` in this repo (Sidebar, Settings, Launcher, AltTab, Cheatsheet, ConfirmDialog, Screenshot, ...) and found every single one uses `exclusiveZone: -1`, except these two, which used plain `0`. `0` and `-1` are not the same value in the wlr-layer-shell protocol: `-1` means "ignore every other surface's own reserved space, anchor from the true screen edge"; `0` only means "I reserve nothing for others" — it does not opt this surface out of being pushed around by the BAR's own reservation.

The primary evidence for what that actually does (not just a pattern match against sibling files) is `Screenshot/Screenshot.qml`'s own comment on a prior, functionally identical bug ("the dim area is trimmed below the status bar"): on a surface that isn't `-1`, the bar's exclusiveZone "reduces this surface's available region to stop short of the bar strip... the region itself stops there" — confirmed there against `AltTab.qml`'s own already-hardware-verified fix for the same symptom. That means both files' own top-anchored origin was already being shifted down by the bar's height before any QML-level anchoring ran at all — and both files then ALSO added `Services.BarMetrics.height + Config.Appearance.panelGap` via `anchors.topMargin`, on top of that already-shifted origin. A double-count of the bar's height, not a gap-token problem — matching the TODO's own observation ("clearly it's not an issue of gap") exactly.

This also explains "fixed many times, never worked": a prior fix (OOP-20, referenced in both files' own comments) replaced a hardcoded height guess with the bar's real measured height — correcting the VALUE being added, but never touching the `exclusiveZone` line, so the double-count persisted regardless of how accurate that value became. Changed both to `exclusiveZone: -1`, matching every other overlay surface's own already-proven convention; no other change was needed since the existing `barHeight + panelGap` margin math is already the same formula `Panels/Sidebar.qml` (which already used `-1`) uses successfully.

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here. The mechanism itself (`-1` vs `0`) is hardware-verified in this repo, but for OTHER files (`Screenshot.qml`/`AltTab.qml`), not independently for these two — the diagnosis is a strong inference from that precedent, not an observed fact for `BarPopout.qml`/`Calendar.qml` specifically, and both files' own comments say so and spell out the two outcomes that would mean it's wrong: the popout stays exactly where it was (the origin shift wasn't the actual cause here), or it now overlaps/sits behind the bar itself (the shift was real but in the opposite direction from this model — in that case `barHeight` should be DROPPED from the `topMargin`, not kept, as the immediate one-line follow-up).

<span style="color:red">**NOT DONE:** the TODO's own broader ask — "clean up the WHOLE feature" — reads as wanting more than a one-line-per-file fix if this turns out not fully sufficient; this change is scoped to the specific double-count bug found, not a rewrite of the popout positioning system.</span> If the fix works, no further cleanup should be needed since the underlying math was already correct.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Click any right-isle bar icon (volume, brightness, wifi, bluetooth, network, battery, gpu) or the power icon. Expected: the popout card now appears a small, consistent gap directly below the bar — not visibly further down the screen than that gap.
2. Click the bar clock to open the calendar overlay. Expected: same — it should sit just below the bar, at the same visual gap as the popout in step 1, not lower.
3. If either is now sitting even further down than before, or is overlapping/behind the bar strip itself, that's the falsifiable "wrong direction" case both files' own comments call out — the fix is to remove `+ Services.BarMetrics.height` (or the equivalent `root.barHeight` in BarPopout.qml) from that file's `anchors.topMargin`, keeping only `Config.Appearance.panelGap`, rather than reverting this commit.

---

## No customisation for sounds (battery/charging sound)

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 230b1a2 devices: customisable name/volume for the battery charging sound, 1cf2372 merge: customisable name/volume for the battery charging sound
- **Original TODO:** "add customisation for sounds (battery sound)"

### What was asked
The existing charging-plugged-in sound (Settings → Devices → Battery) only had an on/off toggle — add real customisation: which sound, and how loud.

### What was done
Added a sound name field (a freedesktop theme name like `power-plug`/`message`/`bell`, or an absolute path to an audio file) and a volume (0-100%), plus a "Test sound" button — the exact same row shape and behavior the Notifications section's own "Sound & testing" group already has, reusing its `_soundPath()`/`playSound()` pattern in `Services/PowerBridge.qml` rather than inventing a second convention.

The charging sound's persistence moved off a single `phi state` scalar key (`power.chargingSound`) onto a JSON file (`Config.Paths.powerSoundPrefsFile`, `~/.local/state/phi/power-sound.json`) — the same shape as `notification-prefs.json`/`clock.json`/`lock.json`/`chroma.json` already use. `phi state`'s key set is closed (`phi/internal/state/state.go`) and a `{enabled, name, volume}` value doesn't fit one scalar key, so adding two new phi-state keys would have needed a `phi` rebuild and a new tag for what is otherwise a phi-shell-only change — moving the whole thing to a JSON file avoided that entirely.

Since the on/off toggle was a real, already-shipped setting (not new), added a one-time migration: the first time the new JSON file is found missing, the old `phi state` key is read once and seeds the new file, so a user who had already turned the sound off on a real machine keeps it off after this change rather than silently reverting to the default (on). Guarded against the one real race this has — the migration's `phi state get` shells out and isn't instant, so the user could open Settings and flip the toggle themselves before the migration callback lands; a `_soundPrefsWritten` flag makes sure a real, fresh write always wins over a migration that started first but finished second.

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here.

The migration is the one part of this that is genuinely unverifiable from here and the one most likely to be wrong if it is: **on the machine where the charging sound was ever turned off before this change, restart the shell once and check `cat ~/.local/state/phi/power-sound.json`** — it should show `"enabled": false`. If it instead shows `true` (or the file doesn't exist), the migration did not pick up the old value and the toggle needs to be flipped off manually one more time.

The settings field's initial value has a known, pre-existing latent gap copied faithfully from the pattern it mirrors, not introduced here: `Component.onCompleted: text = Services.PowerBridge.chargingSoundName` reads whatever the property holds at that instant, but the JSON file loads asynchronously — if Settings is opened at the very moment the shell starts, before the file has loaded, the field would show the default `"power-plug"` even if a custom name is actually stored (the service's own state would still be correct once loaded; only the field's initial display could lag). Notifications' own identical sound-name field has the same gap. In practice Settings is a user-triggered panel opened well after startup, so this is unlikely to be seen, but it's a real, not-fixed-here edge case, not something asserted clean.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed. Applies to laptops only (`Config.Capabilities.battery`) — this whole group is disabled with a reason on a desktop with no battery.

1. Open Settings → Devices → Battery.
2. Type a different sound name into the "Sound" field (e.g. `bell` or `message`) and press Enter/commit. Click "Test sound" — the new sound should play instead of the old `power-plug` default.
3. Change "Volume" up or down and click "Test sound" again — it should be audibly louder or quieter than before.
4. Toggle "Play a sound when the charger is plugged in" off, then unplug and replug the charger (or however you'd normally trigger this) — no sound should play. Toggle it back on and repeat — the sound should play again.
5. Enter a nonsense sound name (e.g. `not-a-real-sound`) and click "Test sound" — the group's caption at the top should show a "Last sound error" line naming the missing file, not a silent failure.
6. Restart the shell (`pkill -x qs; qs -p ~/.config/quickshell/phi`) and reopen Settings → Devices → Battery — the name and volume set in steps 2-3 should still be there, confirming the JSON file persists across restarts.

---

## The status bar has no in/out transition on start, lock or unlock

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 6075487 bar: slide in/out on shell start and session lock/unlock, 9b57897 merge: bar slide in/out on shell start and session lock/unlock
- **Original TODO:** "add in and out transition for the status bar, to be triggered on start, lock and unlock"

### What was asked
The status bar should play an entrance transition when the shell first starts, and an exit/entrance pair around locking and unlocking the session, instead of just appearing/disappearing instantly.

### What was done
`Bar/Bar.qml` already had a slide mechanic for a different purpose — auto-hiding while the active window on that screen is fullscreen (`barContent`'s own `y`, animated by an existing `Behavior on y`). Reused that exact mechanic for all three new triggers instead of building a second, parallel animation system: a new `concealed` condition (`autoHidden || startupReveal || Services.LockState.locked`) now drives `barContent.y`, so the same slide plays whether the bar is concealing itself for fullscreen, for a fresh startup, or for a lock.

Added `Services/LockState.qml`, a minimal singleton exposing one `locked` boolean, written only by `Lock/Lock.qml` (the file already sanctioned to touch `WlSessionLock` directly) — `Bar/Bar.qml` is a separate top-level surface with no other way to observe lock state. It goes true the moment `Lock/Lock.qml` starts locking and false only once its own conceal fade finishes on a successful unlock (not at the earlier instant PAM succeeds), so a bar reveal is timed to when the desktop actually becomes visible again.

`startupReveal` starts the bar off-screen at session start. It clears from `registryFile`'s own `onLoaded` (the async load of `Bar/modules.json` that populates the isles), deferred one further `Qt.callLater` turn for the `Loader`s it creates to report a real `implicitHeight` — not plain `Component.onCompleted`, which fires before `bar.height` has settled to anything but a placeholder, which would have made the reveal slide in from a few-pixel-tall bar that only reaches its real height after the animation had already finished.

`exclusiveZone` (the strip of screen Hyprland reserves for the bar, so tiled windows don't sit under it) stays keyed to the existing fullscreen-only `autoHidden`, deliberately NOT the new, wider `concealed` — a decision made and caught in review before landing, not after: dropping the reserved zone during a lock (as an earlier draft did) would un-reserve the bar's strip and reflow every tiled window on that screen to fill it, then reflow back on unlock — a real, visible layout jump on every single lock cycle. Only the bar's own visual content slides for the lock/startup cases; the window itself keeps reserving its space throughout.

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here.

The lock-side hide is **not independently visible in practice** — worth saying plainly so it isn't tested and reported as broken. The ext-session-lock protocol requires a locked output to stay painted opaque the instant locking starts (`Lock/Lock.qml`'s own header), so the bar is already covered before any slide-out could be seen. The lock-side write to `Services.LockState.locked` still matters: it's what positions the bar off-screen so the UNLOCK side has something to visibly slide in FROM, once the lock surface's own fade reveals the desktop again. The two user-observable transitions are start and unlock; lock itself is plumbing for unlock, not its own visible moment.

The startup reveal's timing (waiting for `registryFile.onLoaded` plus one deferred turn) is a best-effort fix for a real problem caught in review — the isles' `implicitHeight` depends on `Loader`-instantiated module components, which may in principle need more than one extra event-loop turn to fully settle after `registryRows` changes. If the reveal still starts from a shorter-than-final bar height on real hardware (visible as the bar growing taller mid-slide, or the slide distance looking slightly short), that one-turn assumption is the place to revisit, not the mechanism itself.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed. The startup case specifically needs a fresh process to see, though: `pkill -x qs; qs -p ~/.config/quickshell/phi`.

1. Kill and restart `qs` as above. Expected: the status bar slides down into view from off-screen at its normal full height, rather than simply appearing already in place.
2. Lock the session (however you normally trigger `lock` — e.g. the power menu, or `qs ipc call lock lock` from a terminal). Expected: no visible bar animation at this moment — the lock screen should simply appear, covering everything at once. This is correct, not a missed case (see Honest assessment).
3. Unlock (enter the correct password). Expected: once the lock screen's own content fades away and the desktop becomes visible again, the status bar should slide down into view from off-screen, the same motion as the startup case in step 1 — not just be sitting there already.
4. With nothing locked and no fullscreen window, confirm ordinary bar behavior is unaffected: hovering near the top edge while a fullscreen app is active should still reveal the bar exactly as before this change.
5. Confirm no window layout jump happens during step 2 or 3 — any already-tiled windows on screen should stay in their exact same position and size throughout locking and unlocking; only the bar's own content should move.

---

## The calendar overlay's flip clock reads as a slot machine, not a flip

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** c3b366b flipdigit: split into a static bottom half and a top-only flap, fix reserved-word bug, b238f7d merge: split flip-digit into a static bottom half and a top-only flap
- **Original TODO:** "the calendar overlay in the status bar shows a flip clock, it should have the real flip animation, not a slot"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
The calendar overlay's big "HH:mm:ss" clock (opened by clicking the bar clock) already has a flip effect from an earlier round, but it reads as a slot-machine reel snapping over, not a real flip — fix the animation itself.

### What was done
Before touching anything, checked whether this was already done: `Widgets/FlipDigit.qml` already had a flip effect from two prior, already signed-off rounds (commits `8b4dbd8`, `5981e62`, `3634233`, `c3ba01c`, `5f32121`, all 2026-09-11), including a follow-up that changed the fold to be top-only ("it folds the number from both top and bottom, it should only be the top part folding over the bottom"). Since this TODO entry is dated after those sign-offs and describes exactly the failure mode a prior version's own VERIFICATION entry predicted as a risk ("if the single-transform version doesn't read convincingly as a flip clock once seen, the real two-piece version is a larger follow-up"), this is a fresh, real report, not a stale duplicate — advisor review confirmed the same reading before any code changed.

The actual defect: the old version rendered the WHOLE digit as one Text and squashed it toward its own bottom edge via a single `Scale`. Both the half that's supposed to move and the half that's supposed to stay still moved together as one unit — there was no genuinely motionless anchor for the eye, which is what makes something read as a slot reel rather than a flip.

Rewrote `Widgets/FlipDigit.qml` so the cell is two independent, half-height clipped `Item`s, both reading one shared `_shown` character: `topFlap` is the only piece that ever transforms (folds toward the centerline, swaps `_shown` at the fully-squashed midpoint, unfolds — the same squash-swap-unsquash motion as before, just now confined to its own half); `bottomStatic` is never transformed at all, for the whole animation. Also added `seamLine`, a thin static line at the centerline (gated to `showCard`, same as the existing `cardBorder`), matching the visible seam a real split-flap card has between its two physical pieces. `topFlap`/`bottomStatic` are new internal structure only — the widget's public API (`value`, `textColor`, `sizeStep`, `mono`, `showCard`) is unchanged, so neither `Panels/Calendar.qml` nor `Bar/modules/Clock.qml` needed any change.

Deliberately still top-only, not a true two-leg split-flap where the bottom half also visibly unfolds into place with its own motion (advisor's first-pass suggestion): the prior, already-signed-off round of this same TODO entry asked for exactly this half-static shape in the user's own words, so re-adding bottom motion would reopen a design question already settled, not fix what was flagged this time. Flagged in the file's own header as the next step up if the top-only version still doesn't read convincingly once seen.

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here, and this is a pure visual/motion change, so "does it now read as a flip and not a slot" is ultimately a judgment call only a screenshot can settle. One real bug was caught and fixed before landing, not after: the first draft used `char` as a property name on the two half-`Item`s, which is a reserved word in QML/JS and would have broken the widget on load — caught by review, fixed by dropping those properties entirely in favor of having both halves read the shared `_shown` property directly (simpler, and removes what would otherwise have been three copies of the same state that had to stay in lockstep).

The vertical split point (where `topFlap` ends and `bottomStatic` begins) is `cell.height / 2`, an exact half — worth a close look in the screenshot for whether the two halves join with a clean, single-pixel seam at rest, or whether there's a visible sub-pixel gap or overlap (a font-metrics rounding difference between `cell.half` and how the underlying font renders is the plausible source if so). This risk applies to both the calendar clock (`showCard: true`, sizeStep 4) and the bar clock (`showCard: false`, sizeStep 0, 11px) — the bar clock's digits are worth a specific check that they still sit at the same height and baseline as the static colons next to them, since that's the smaller, more rounding-sensitive case and the one place a regression would be easy to miss.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Click the clock in the status bar to open the calendar overlay. At rest, the six digits (HH:mm:ss) should each show a thin horizontal seam line across their vertical center, splitting each digit card into two halves — this is new; the prior version had no seam.
2. Watch the seconds digits tick over. Expected: only the TOP half of each changed digit visibly folds down toward the seam and back up, showing the new value once it unfolds; the BOTTOM half should not move, distort, or flicker at any point — it should look like a card's top flap flipping over a fixed lower card, not the whole digit shrinking and swapping in place.
3. Compare against the OLD behavior if you recall it (or if unsure, this is the key distinction): before, the entire digit visibly squashed as one piece toward the bottom edge and popped back — if it still looks like that (the whole glyph moving, no fixed static half), the fix did not take.
4. Look at the small clock in the status bar itself (not the overlay) during a minute boundary. Expected: still no card frame or seam line there (`showCard: false` hides both) — same flip motion as the calendar clock's top half, just without the card visuals, and the digits should sit at the same height/baseline as the static colon between them, not shifted up or down.
5. Look at any digit at rest, in both places — the bar clock and the calendar overlay. Expected: a normal, complete-looking digit with no visible gap, doubled/ghosted text, or misalignment at the seam.

---

## More than one overlay panel (notifications, agent, settings, a bar popout) can be open at once

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 7644f90 panels: close each other when notification/agent/settings/popout opens, 7ad4aa7 merge: close each other when notification/agent/settings/popout opens
- **Original TODO:** "opening the notification panel, the agent panel, the settings panel or a bar popout (volume, wifi, bluetooth, etc.) doesn't close whichever of the others is already open — more than one can be visible at once. Only the calendar currently yields to (and is yielded to by) all four; none of the four do this for each other."
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
Four overlay surfaces — the notification/clipboard sidebar, the AI agent panel, the settings panel, and a bar popout (volume/wifi/bluetooth/etc.) — should be mutually exclusive: opening any one of them should close whichever of the other three is currently open. Only the small calendar card already had this relationship with all four; the four themselves never closed each other.

### What was done
Each of the four owning singletons (`Services/NotificationPanel.qml`, `Services/AgentPanel.qml`, `Services/SettingsPanel.qml`, `Services/BarPopout.qml`) now has a reactive handler — `onShownChanged` for the first three, `onWhichChanged` for `BarPopout` (its `shown` is a derived readonly property; watching the underlying `which` matches how `Services/Calendar.qml` already watches it externally) — that, guarded on becoming *open* (never on becoming closed, which is what avoids a cycle), calls `.hide()` on the other three. `SettingsPanel` has three separate entry points that can set `shown = true` (`show()`, `openSection()`, `reveal()`); using the reactive property handler instead of patching each function individually covers all three with one block. `Services/Calendar.qml` itself was not touched — it already closes itself when any of these four opens, and (per its own header) is deliberately the one owner of that specific relationship; this change only adds the missing direction between the four non-calendar surfaces.

Each file now imports `qs.Services as Services` to reach its three siblings — the same intra-`Services/`-directory singleton cross-reference `Services/Calendar.qml` already used (proof this pattern works in this codebase, since Calendar's own Connections blocks already resolve `Services.NotificationPanel` etc. the same way).

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here. Verified by re-reading all four changed files in full for brace balance and correct binding syntax, and traced every call path by hand for a reference cycle: each handler only ever calls `.hide()` on its siblings, `.hide()` only ever sets `shown`/`which` to the *closed* value, and each handler's guard only fires on the *open* transition — so a `.hide()` call can never re-trigger another handler's closing logic, only the no-op branch. This is the same reasoning already load-bearing for `Services/Calendar.qml`'s existing four `Connections` blocks, which this change is structurally identical to.

One thing not verified: whether any of the four ever needs to be opened *without* closing the others — for example, whether the settings panel is ever meant to stay open behind a bar popout opened via a "Show in settings" button from inside it (`Services/SettingsPanel.qml`'s own header lists that exact button as one of its entry points). Read through `SettingsPanel`'s callers for such a case and found none — every bar-popout "settings" button opens settings and the popout itself both close together, no code path holds both open on purpose — but this is a judgment call from source, not something seen on screen.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Open the notification panel (click the bar bell, or Super+N). Then click a bar popout icon (e.g. volume or wifi). Before this change, both would stay visible at once; now the notification panel should close the moment the popout opens.
2. With the volume popout still open, press Super+P to open the AI agent panel. The popout should close.
3. With the agent panel open, press Super+S to open settings. The agent panel should close.
4. With settings open, press Super+N again. Settings should close and the notification panel should open.
5. Click the bar clock to open the small calendar card while any of the above is open — it should still close whichever one was open, exactly as before this change (this direction was already working and should be unaffected).

---

## Confirmation prompts (like the power menu's) are a small inline replace, not a real modal

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 93b83b4 dialogs: add a reusable centered confirmation modal, migrate power confirm, 254b4a6 merge: add a reusable centered confirmation modal, migrate power confirm, 5e82ad1 dialogs: make the confirmation modal exclusive over every other panel, 328e6dc merge: make the confirmation modal exclusive over every other panel
- **Original TODO:** "confirmation modals (like the one for power options) should be centered in the screen, with a dim and block the screen until they are resolved. Also make them a reusable component as other task (eg. the battery saving mode, see below) will use it."
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
The existing "are you sure?" step before Reboot/Shutdown/logout-via-Super+M just swapped the small bar-popout card's own content in place — no screen dim, nothing blocked outside that one small card. Replace it with a real modal: centered on screen, dimmed behind, blocking until Confirm or Cancel — and build it as a reusable component, since other backlog items (the battery-saving-mode alert is the TODO's own example) will need the same thing.

### What was done
Added `Services/ConfirmDialog.qml` (a singleton owning `shown`/`title`/`message`/`confirmLabel`/`cancelLabel`, opened from anywhere with `Services.ConfirmDialog.open({title, message, confirmLabel, cancelLabel, onConfirm})`) and `Dialogs/ConfirmDialog.qml` (the one shared full-screen surface, declared once in `shell.qml` exactly like `Cheatsheet/Cheatsheet.qml`, whose layer-shell/scrim/centered-panel/keyboard-focus plumbing this is structurally copied from — the closest existing full-screen modal in the repo). Unlike Cheatsheet/Settings/Sidebar, there is deliberately no click-outside-to-close: Confirm, Cancel or Escape are the only ways out, matching "block the screen until they are resolved." Escape and Enter are wired both on the dialog card (Enter defaults to Confirm) and on each button individually — the second part mirrors a landmine `Launcher/Launcher.qml`'s own confirm sub-view already documents: `StyledButton` has no keyboard handling of its own, so without a per-button `Keys.onReturnPressed`, tabbing to Cancel and pressing Return would fall through to the card's own handler and confirm anyway.

`Panels/BarPopout.qml`'s power section (reboot/shutdown, plus the Super+M logout confirmation) now calls `Services.ConfirmDialog.open()` instead of the old inline second-click view. That inline view is gone entirely, along with the `_confirmingAction` state that drove it. The Super+M path used to open the popout at a default corner position purely so it had somewhere to show its inline confirm (`Services.BarPopout.openConfirm()` / `pendingConfirmAction`, added specifically for that) — a centered modal needs no popout to anchor under, so that whole mechanism (now unused) was removed from `Services/BarPopout.qml` rather than left dead. Cancelling the new dialog leaves the popout's action list open underneath if it was already open (button-driven case), same as the old inline confirm did; the Super+M case never opens the popout at all now, simpler than before.

`Launcher/Launcher.qml`'s OWN separate confirm step for reboot/shutdown (reached via Tab+Enter inside the runner bar) was deliberately left untouched — it's a step in the launcher's existing keyboard-driven view-navigation stack (Tab/Enter/Escape between cards), not a small popout replaced in place, and the TODO's own wording ("like the one for power options") points at the popout's version as the thing that needed centering; converting the launcher's internal navigation to a separate floating modal would be a different, larger change nothing in the request asked for.

**Follow-up fix, same entry, commits 5e82ad1/328e6dc:** the first version above was merged without checking how it interacts with the panel-mutual-exclusion change from the previous VERIFICATION entry below. Opening the confirmation dialog did not close Sidebar/AgentPanel/Settings, all of which also raise to `WlrLayer.Overlay` and grab keyboard focus — so a Return keypress while the dialog was open could land on whichever same-layer surface the compositor happened to route it to, undefined and dangerous given a destructive Confirm button. Fixed by having `Services/ConfirmDialog.qml` close every other panel (the four plus Calendar) the moment it opens — deliberately NOT the same choice `Services/Spotlight.qml` makes (that one is meant to layer OVER an open panel, per its own header) — and by removing the card-level "Return defaults to Confirm" binding, so a stray Return does nothing until the user has actually tabbed to a button. This also means Cancel no longer returns to the power popout's action list still open underneath (the popout is now one of the panels closed on open) — a real behaviour change from what the first half of this entry described; re-opening the power icon is needed to try a different action after cancelling.

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here. Checked brace balance on every changed/new file programmatically and traced every binding by hand against the closest existing precedent for each piece (Cheatsheet.qml for the layer-shell surface itself, Launcher.qml's confirm subview for the `focus: <condition>` / per-button `Keys.onReturnPressed` pattern) rather than inventing new plumbing — but none of it has been seen on screen.

Two judgment calls, not specified in the TODO text: dialog placement is `Dialogs/ConfirmDialog.qml` (a new top-level directory, matching the existing one-directory-per-full-screen-surface convention — Cheatsheet, Screenshot, Overview, AltTab); and the primary Confirm button uses `StyledButton`'s existing `active: true` (accent-inverted) look to read as the primary action, rather than a new "danger/destructive" colour — no red/warning token exists in the design system for this today and design tokens are locked to `phios-dotfiles` (rule 6), so inventing one wasn't in scope here. Flag if a distinct destructive-action colour is wanted; that would be its own small design-token change.

Not migrated to the new dialog: nothing else in the shell currently asks for a blocking confirmation (the "delete VPN config"/"sensible settings" confirmation and the battery-saving-mode alert the TODO itself names are their own still-open backlog entries) — this change only builds the reusable piece and moves its one existing consumer over, it doesn't go looking for other call sites to convert.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Click the power icon in the bar's left isle, then click "Reboot". Before this change, the small popout card's own content flipped in place to a "Reboot now? This cannot be undone." line with two small buttons, nothing else on screen changed. Now, the popout should close and a centered card should appear over a dimmed whole screen (bar included), titled "Reboot" with the body text "This cannot be undone." and two buttons, "Reboot" and "Cancel".
2. Press Escape — the dialog should close with nothing performed. The power popout does NOT reappear (it was closed the moment the dialog opened, not preserved underneath) — click the power icon again to reopen it.
3. Open the notification panel (bar bell or Super+N), then open the settings panel (Super+S) — the notification panel should close (the earlier VERIFICATION entry below). With settings still open, trigger a confirmation (e.g. open the power popout and click Reboot). Settings should close the moment the dialog opens, and Tab then Enter on the dialog's Cancel button should cancel the dialog specifically, not fall through to anything in Settings. This is the case the follow-up fix (5e82ad1) exists for — verify it explicitly, not just the happy path.
4. Click "Shutdown", then Tab to the "Shutdown" button in the dialog and press Enter (not a mouse click, to confirm keyboard activation works) — the dialog should close and (on real hardware) the shutdown should proceed. This cannot be verified here.
5. Press Super+M — before this change, the power popout opened in the corner of the screen directly on the "Log out now?" step. Now, the popout should NOT open at all; only the centered confirmation dialog should appear, titled "Log out". Pressing Return immediately after it opens (before tabbing anywhere) should do NOTHING — this is the "no default-to-Confirm" fix; only Tab-ing to a button and then pressing Enter, or a direct click, should act.

---

## No settings-panel section for suspend, hibernate or the other power actions

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** c5ac1d0 settings: add a Power group to Devices with suspend/hibernate/etc., eadede4 merge: add a Power group to Devices with suspend/hibernate/etc.
- **Original TODO:** "add suspension/hibernation settings in the settings panel"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
A one-line backlog entry: give suspend/hibernate (and, reasonably, the rest of the power actions) a place in the settings panel — today they only exist on the bar's power popout, which `Panels/BarPopout.qml`'s own code comment already flagged as a stand-in ("Devices already hosts battery/charging, the closest existing home") for a section that didn't exist yet.

### What was done
Added a "Power" `SettingsGroup` to `Settings/sections/Devices.qml` (registered as `devices.power` in `Settings/sections/options.js`), with the same six actions the bar's power card already offers — Lock, Suspend, Hibernate, Log out, Reboot, Shut down — wired to `Services/PowerActions.qml` and, for Reboot/Shutdown, gated behind the confirmation dialog from the previous entry below (`Services/ConfirmDialog.qml`). The gating logic (`_requestPowerAction`/`_confirmAndPerform`) is a second, small copy of `Panels/BarPopout.qml`'s own identically-named functions rather than a shared abstraction — there are only the two call sites, and `PowerActions.needsConfirm` is still the single source of truth for WHICH actions confirm, so the two copies can't disagree about policy even though the wiring is duplicated. The popout's own "Settings…" button now deep-links straight to this new group (`_showInSettings("devices.power")`) instead of just opening Devices at its top.

### Honest assessment
<span style="color:red">**NOT DONE: any idle-timeout / lid-close / DPMS policy.**</span> "Suspension/hibernation settings" could also reasonably mean *when the machine suspends on its own* (an idle timer, screen-off timing, lid-close behaviour) rather than only *a button to suspend it right now*. Checked first: nothing in this project configures that anywhere today — `hypridle` is listed in `profiles/desktop/packages.txt` with an explicit comment that its config is deferred, and no `hypridle.conf` or equivalent exists, committed or templated, in any repository (the same finding this workspace's own TODO history already recorded for the separate "screen suspends too fast after hibernation" bug report). Building that policy for real would mean shipping a real `hypridle.conf` into `phios-dotfiles`, deciding real timeout values and AC-vs-battery behaviour, and adding `phi state` keys or template variables for the settings panel to drive — several genuine, unstated design decisions, not something inferable from a one-line entry. What was built instead is the half of "suspend/hibernate settings" that has real, existing state behind it (the actions themselves); a toggle for a policy that doesn't exist anywhere yet would have been a hollow control. If idle/lid policy is actually wanted, that is its own, larger task.

Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here. Checked brace balance on every changed file programmatically and read the full diff back for correctness; the `Flow`-wrapped button row mirrors an existing pattern (`Settings/sections/Connectivity.qml`'s firewall-preset buttons) rather than inventing new layout.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Open Settings (Super+S) → Devices. A new "Power" group should appear after "Battery" and before "Chroma keyboard", with six buttons: Lock, Suspend, Hibernate, Log out, Reboot, Shut down.
2. Click Lock — the lock screen should engage immediately, no confirmation.
3. Click Reboot — the settings panel should close and the same centered confirmation dialog from the entry below should appear ("Reboot" / "This cannot be undone."). Cancel should close it with nothing performed.
4. Click the power icon in the bar, then "Settings…" at the bottom of the popout — it should open Settings scrolled directly to the new Power group with a brief highlight pulse, not just Devices' top.

---

## Terminal windows have no breathing room around their text

- **Date:** 2026-09-13
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** a5be071 kitty: add generous window padding via a new design token, fc45888 merge: add generous kitty window padding via a new design token
- **Original TODO:** "terminal panels should have larger padding. reference to references/panel-reference-1.JPG and references/panel-reference-2.JPG"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
Give kitty (this project's confirmed default terminal) more inset around its text, matching the generous padding visible in the two reference screenshots (both show terminal windows with a comfortable margin between the window edge and the text).

### What was done
Read both reference images. `kitty.conf` had no `window_padding_width` set at all (kitty's own default is 0 — text flush against the window edge), so this was a real, concrete gap, not a subjective "make it bigger."

Added a new design token, `PHI_TERM_PADDING='16'`, to `design/tokens.common.sh` — its own token rather than reusing the existing `PHI_PANEL_PADDING` (phi-shell's own `Panel.qml` inset), on the same "distinct role, may diverge later" reasoning the file already uses for `PHI_BORDER_WIDTH_STRONG` vs `PHI_BORDER_WIDTH`. Unlike every other size token here it carries no unit suffix, because kitty's `window_padding_width` directive takes a bare point value — documented in the file's own PLACEHOLDERS header, matching its established convention for every other invented constant.

New `profiles/desktop/templates/.config/kitty/padding.conf.tmpl` (`window_padding_width ${PHI_TERM_PADDING}`), registered in `design/adapters.txt` with the same `[unknown]` reload gap and class B as kitty's two existing template rows (`theme.conf.tmpl`, `fonts.conf.tmpl`), and included from the base `kitty.conf`.

### Honest assessment
Verified further than most `phios-dotfiles` changes can be in this environment: built `phi` from this session's checkout and ran the real `phi theme render --variant dark profiles/desktop/templates/.config/kitty/padding.conf.tmpl` and `phi theme list` against the actual template — both work, producing valid kitty syntax (`window_padding_width 16`) and listing the new adapter row correctly. This is real end-to-end confirmation that the token resolves and the template renders, not a static read.

Not verified: the installer's own `--dry-run` couldn't be exercised on this machine — `bin/phios-install` calls `realpath -m`, a GNU coreutils flag BSD/macOS `realpath` doesn't support, so it fails immediately here with an unrelated, pre-existing platform gap (this workspace runs on macOS; the installer targets real Arch/Linux machines only). The exact `16` padding value is a placeholder chosen by eye against the two reference images, same "judgment call, flagged" status as every other invented size constant in this token file (`PHI_RADIUS_BASE`, `PHI_PANEL_PADDING`, etc.) — flag it if it reads too generous or not generous enough once actually seen in a real kitty window.

### How to test it
1. On a real machine, run `bin/phios-install` (default mode, not `--dry-run`) so the new `.config/kitty/padding.conf` template gets rendered and symlinked, or manually run `phi theme render profiles/desktop/templates/.config/kitty/padding.conf.tmpl ~/.config/kitty/padding.conf` from the `phios-dotfiles` checkout.
2. Open a new kitty window (or reload an existing one — `Ctrl+Shift+F5` reloads kitty's config in a running instance, or just close and reopen). The text should now sit with a visible, comfortable margin from every window edge, instead of touching it — compare against `references/panel-reference-1.JPG`/`-2.JPG`.
3. `phi theme set dark` (or `light`) should still regenerate the file without error, same as any other themed target.

---

## Opening a panel while on Steam/btop's workspace leaves it stranded there

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 6783bab hyprland: leave Steam/btop's dedicated workspace when a panel opens, 89266e3 merge: leave Steam/btop's dedicated workspace when a panel opens, 0299815 hyprland: derive reserved workspace ids from workspace-icons.json, fix multi-monitor scan, fe1802d merge: derive reserved workspace ids from workspace-icons.json, fix multi-monitor scan
- **Original TODO:** "opening a panel on a special workspase (11, 12), should automatiically open it in the highest possible panel up to 10"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
Workspaces 11 and 12 are Steam's and btop's own dedicated spaces (ADR 134, `hyprland.lua.tmpl`) — reserved, single-purpose workspaces, not general work. If the user opens one of the shell's panels (notifications, agent, settings, a bar popout) while parked on one of those two, the request is to switch away to a normal workspace first, rather than leaving the panel floating over a full-screen game or `btop`.

### What was done
Read `hyprland.lua.tmpl` and `Bar/workspace-icons.json` first to confirm what "11, 12" actually refers to — this is NOT the Hyprland `special:` scratchpad (`Services/Calendar.qml`'s own history already found Quickshell 0.3.1 cannot read `special:` workspace state at all, a real dead end recorded there and in this session's own memory of that investigation). 11 and 12 are ordinary, positive-id numbered workspaces pinned to Steam/`btop` by `hyprland.lua`, fully readable through `Services/HyprlandBridge.qml`'s existing `workspaces` property — no Quickshell limitation applies here.

Added `Services.HyprlandBridge.leaveReservedWorkspace()`: if `screens[0]` (every one of the four panel singletons below is single-instance, pinned to `screens[0]` per `shell.qml`) is currently on workspace 11 or 12, it switches to the highest workspace id in 1–10 that exists in Hyprland's own live model, or workspace 1 if none of 1–10 currently has one. Wired into the same `onShownChanged`/`onWhichChanged` handlers the panel-mutual-exclusion entry (below) already added to `Services/NotificationPanel.qml`, `Services/AgentPanel.qml`, `Services/SettingsPanel.qml` and `Services/BarPopout.qml` — whichever of the four opens now both closes its three siblings and leaves a reserved workspace, from the same one place per caller. This is a small, deliberate widening of `HyprlandBridge.qml`'s own stated "thin wrapper" scope — the two reserved ids are UI policy, not a Hyprland IPC primitive — justified because all four callers needed the identical ~15-line scan; the file's own new comment says so explicitly.

### Honest assessment
Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here. Verified by reading the real `Quickshell.Hyprland` usage already proven elsewhere in this codebase (`.values` on the workspaces model, `.activate()` on a workspace object, `.monitor.name` — all three already load-bearing in `Bar/modules/Workspaces.qml`/`Services/Idle.qml`/`Overview.qml`) rather than guessing at the API, and checked brace balance on every changed file programmatically.

The exact meaning of "highest possible" was a judgment call, not spelled out in the one-line TODO entry: implemented as "the highest workspace id in 1–10 that currently has at least one window" (since a non-persistent, non-special workspace with zero windows doesn't appear in Hyprland's own workspace list at all), not "most recently used" — a reasonable, literal reading, but flag it if "go back to whatever I was just doing" (workspace history) was actually meant instead.

Applied uniformly to all four panel singletons, including the small bar popouts (volume/wifi/etc.) — not just the three "main" panels — for consistency with the exact same four-surface grouping the mutual-exclusion entry below already established, even though the TODO text's "a panel" could be read more narrowly. Flag if a volume-level check shouldn't force a full workspace switch away from Steam/btop.

**Follow-up fix, same entry:** review caught two real bugs in the first version, both fixed in 0299815/fe1802d. First, `reservedWorkspaceIds` was a second `[11, 12]` literal hand-copied from `Bar/workspace-icons.json`, which already defines those same ids for `Workspaces.qml`'s pinned-app glyphs — a real drift risk if one is ever edited without the other. It's now read from that one file via a `FileView`, so there is a single source for the two ids. Second, the "highest ordinary workspace" scan had no per-monitor filter, so on a two-monitor machine (`zotac`) it could pick a workspace that actually lives on the *other* monitor; `.activate()`-ing that would just refocus the other monitor rather than clearing `screens[0]`, the opposite of the intended effect. The scan is now filtered to `screens[0]` the same way `current` already was — untested against real multi-monitor hardware, same constraint as everything else in this entry, but the logic now matches the single-monitor case's own filtering instead of being inconsistent with it.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Switch to workspace 11 (Steam) or 12 (`btop`) — click their icon in the bar, or `hyprctl dispatch workspace 11`.
2. Open any panel: click the bar bell (notifications), press Super+P (agent), press Super+S (settings), or click a right-isle icon (volume/wifi/etc.). The active workspace should switch away from 11/12 to whichever of workspaces 1–10 has windows open (the highest-numbered one with something in it), before or as the panel appears.
3. With nothing open on any of workspaces 1–10 (a fresh session), repeat step 2 — it should land on workspace 1 instead of doing nothing.
4. Open a panel while already on an ordinary workspace (say, workspace 3) — nothing should happen to the active workspace; only the panel opens.

---

## Destructive settings actions (deleting a VPN config, etc.) run with no confirmation

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 4f7e33e settings: confirm before deleting a VPN config, notification history, or all Chroma key overrides, 6063a89 merge: confirm before deleting a VPN config, notification history, or all Chroma key overrides
- **Original TODO:** "sensible settings (eg. deleting the VPN config) should ask confirmation with a blocking alert (same fullscreen blocking alert/warning used by other systems)"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
Destructive actions inside the settings panel should ask for confirmation with a full-screen blocking alert before running, the way the power actions already do (the same "used by other systems" surface the TODO points at) — the entry's own named example is deleting a VPN config.

### What was done
Wired `Services/ConfirmDialog.qml` (the reusable centered modal built for the power-confirm entry earlier this session) onto three destructive settings actions:
- `Settings/sections/Connectivity.qml`: the VPN "Forget" button — the TODO's own named example.
- `Settings/sections/Devices.qml`: Chroma's "Clear all keys" — a bulk clear of every per-key colour override.
- `Settings/sections/Notifications.qml`: "Clear all notifications" — deletes the whole notification history.

Each opens the dialog with the action's own name as the title, a short one-line consequence as the message, and the confirm button labelled with the action itself (e.g. "Forget", "Clear all") rather than a generic "Confirm" — the same convention the power actions already established.

### Honest assessment
Deliberately NOT confirmed, a scope decision this agent made rather than something specified: the single-item Firewall rule "remove" link (`Connectivity.qml`) and Chroma's "Clear this key" button (`Devices.qml`, right next to the now-confirmed "Clear all keys"). Both are one quick, trivially-reversible action — re-typing the same port number or re-picking the same key's colour undoes either in seconds — unlike the three now-confirmed actions, which are either bulk (every key, the whole history) or lose something not trivially re-enterable (a VPN config's imported state). If either of these two should also confirm, that's a one-line addition following the exact same pattern, easy to extend.

Not run against a compositor — `phi-shell/CLAUDE.md` is explicit this cannot happen here. Checked brace balance on every changed file programmatically; the `Services.ConfirmDialog.open({...})` call shape is identical to the two already-landed, already-described call sites from the earlier power-confirm and Power-settings entries, not new plumbing.

This inherits the earlier power-confirm entry's own exclusivity fix (opening the dialog closes the settings panel itself, since Settings is one of the four panels `Services/ConfirmDialog.qml` now closes on open) — clicking "Forget" closes the whole settings panel behind the dialog, not just that one row. Confirming or cancelling leaves the settings panel closed either way; reopening it (Super+S) returns to wherever it was.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Open Settings → Connectivity, import a WireGuard config if none is already managed, then click "Forget" next to it. The settings panel should close and a centered dialog should appear: "Forget <name>" / "Deletes the imported config from ~/.config/phi/wireguard. This cannot be undone." with "Forget" and "Cancel" buttons. Cancel should leave the config in place.
2. Open Settings → Devices → Chroma keyboard (needs `Config.Capabilities.chroma`, razer only) → Per-key colours, set at least one override, then click "Clear all keys". The same style of dialog should appear before anything is actually cleared.
3. Open Settings → Notifications → History, click "Clear all notifications". Same dialog, this time titled "Clear all notifications".
4. In each case, confirming should actually perform the action (config gone / keys cleared / history empty) and Cancel should perform nothing.

---

## The runner bar ranks results by feature novelty, not by a sensible category order

- **Date:** 2026-09-13
- **Repo / branch:** phi / dev
- **Commits:** 3034499 query: apply full runner ranking category order, add ask-ai-agent provider, 8aefe4f merge: apply full runner ranking category order, add ask-ai-agent provider
- **Original TODO:** "the runner's ranking needs its full category order applied: apps, HOME files (non hidden or children of hidden folders), commands, phi commands, search any file, ask ai agent, search web, math, conversion. `internal/query/rank.go` only has six category tiers today (app/window/file/math-and-currency/action/websearch), math's tier sits above commands, ssh, zoxide and web search rather than below them, and the six tiers are deliberately spaced so no per-query match quality can ever promote a result across a tier boundary — a \"perfect syntax match ranks higher across categories\" rule needs an explicit cross-tier promotion, not a bigger in-tier score. There is also no \"ask ai agent\" launcher provider at all (`internal/agent` is not wired into `internal/query`), and only one, home-directory-only file-search provider exists, not the broader \"search any file\" category the order calls for — so multi-word queries have nothing to rank a wider file search below web search / ask-ai against yet."
- **Requires phi rebuild:** yes, once this is on `main` — this is only on `phi`'s `dev` so far (current published version is `v0.16.1`); tagging is cut from `main` per `phi/CLAUDE.md`'s Releasing section, and merging `dev` into `main` is a user decision, not something this change does on its own.

### What was asked
Reorder `internal/query/rank.go`'s category tiers to match a specific priority list (apps, HOME files, commands, phi commands, search-any-file, ask-ai-agent, search-web, math, conversion), and build the two launcher categories that don't exist yet: an "ask ai agent" result and a broader "search any file" beyond the current home-directory-only search.

### What was done
`rank.go`'s `providerTiers` now has ten explicit tiers (was six) matching the TODO's order top to bottom: apps, windows (unnamed in the list, kept just under apps as before), HOME files, commands, phi commands, system/ssh/directory (also unnamed — kept grouped with commands/phi rather than dropped to the bottom, see the code comment), ask-ai-agent, search web, math, then currency/conversion at the very bottom. This is a real behaviour flip: math and currency used to outrank commands, ssh, zoxide and web search; now they're the lowest tier of all, below web search.

Added `internal/query/askagent.go` (`AskAgentProvider`, provider name `"agent"`), wired into `Providers()` in `query.go`. It follows `WebSearchProvider`'s exact shape: never answers itself (an A1 round-trip can't fit the 120ms per-provider budget), requires at least two words so it doesn't crowd every keystroke, and offers one result — "Ask AI: "<query>"" — whose action runs `phi agent ask <query>` (shell-quoted) in a terminal, the same `ask` verb `phi/internal/cli/agent.go` already exposes.

Added two new tests in `rank_test.go`: `TestRankAppliesFullCategoryOrder` (nine providers, one per named category except search-any-file, asserting the exact resulting order) and `TestAskAgentProviderRequiresTwoWords` (the word-count floor and the exact shelled-out command). `go build ./...`, `go vet ./...` and `go test ./...` all pass in this checkout (macOS, no compositor — this is Go-only, no QML involved).

### Honest assessment
<span style="color:red">**NOT DONE: the "search any file" category.**</span> The TODO's own text already flags why this isn't a small addition: a live filesystem-wide `fd` pass cannot fit the ~120ms per-provider timeout, and an indexed approach (`plocate`, official-repo, or similar) means a persisted on-disk file-path index — `files.go`'s own existing header comment already treats a persisted index as something I-08 constrains (must live on the encrypted volume, excluded from sync), which the current home-only provider avoids entirely by being a live search. I didn't want to guess at that privacy-relevant design decision, so I left the category's tier un-reserved (rank.go's comment says exactly where to add it — right below phi commands) and re-added a clean, bare TODO entry describing just this remainder, plus a question at the end of TODO.md about which approach to take.

The unnamed categories (windows; system actions/ssh/zoxide) are a judgment call, not something the TODO text specified — I kept them where they already were relative to their previous tier-mates (windows under apps, the other three grouped with commands/phi) rather than stranding them below math, which the file's own prior "unnamed categories go below math" convention would now do given math moved to the bottom. Reasoning is in `rank.go`'s comment; flag it if it reads wrong once you see real results.

`AskAgentProvider`'s tier placement, wording ("Ask AI: ..."), and two-word floor are this agent's own choices, mirroring `WebSearchProvider`'s existing pattern since none of those specifics were spelled out. The AI agent subsystem itself is still confirmed broken end-to-end per the separate `docs/TODO.md` entry — this provider is correct code that currently hands off to a feature that doesn't work yet; it will start working once that's fixed, nothing here depends on fixing it.

Not verified against a real launcher — this changes `phi query`'s output ordering, which `phi-shell`'s Launcher renders but does not itself compute (ADR 018); only `go test` was run, never the shell.

### How to test it
1. On the machine with this branch built and installed (or via `go run ./cmd/phi query <text>` from a `phi` checkout on this commit), type a query that matches an app, a file in `$HOME`, and looks like it could be math — e.g. a directory containing a file literally named `42`, with an app also named something close to `42`. The app result should now appear first regardless of match quality, the file second, and any calculator/currency result should sink to the very bottom of the list, below the web-search fallback — before this change, the calculator/currency result would have outranked commands and web search.
2. Type any two-or-more-word phrase that doesn't strongly match an app, file or command, e.g. `what is the weather`. A new result "Ask AI: "what is the weather"" should now appear near the bottom of the list, just above "Search the web for ...". Selecting it runs `phi agent ask what is the weather` in a terminal (this will currently fail or hang, since the AI agent subsystem itself is still broken per its own separate TODO/VERIFICATION entry — that's expected and unrelated to this change).
3. `cd phi && go test ./internal/query/...` should pass, including the two new tests `TestRankAppliesFullCategoryOrder` and `TestAskAgentProviderRequiresTwoWords`.

---

## Design system is missing a checkbox, radio and text-highlight effect; the switch is too wide

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** 6fea395 widgets: add Checkbox, Radio and Highlighter; fix Toggle width, 3769c4e merge: add Checkbox, Radio and Highlighter; fix Toggle width
- **Original TODO:** "add/replace to the design system: checkbox (square border with inner x), radio (square border with inner small filled square), switch (it's too wide, also the color transition is faster then the switch moving), highlighter effect (similar to the status bar hover effect, but applied to texts, not to full button or element background, it should only highlight the text, with a transition L to R, the text should change color but following the highlight like a mask, it can be used on hoverable texts. add also a highlighter-out effect closing L to R to use for triggered highlights like the search results. when unhovering it just goes back R to L)"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
Four additions/fixes to the shared widget library (`Widgets/`): a new checkbox control (a square outline with an inner X when checked), a new radio control (a square outline with an inner filled square when checked — square, not the usual circle), a fix to the existing `Toggle` switch (it reads too wide, and its colour transition looks faster than the knob's slide), and a new "highlighter" text effect — a highlighter-marker-style colour reveal that sweeps left-to-right across hoverable text, retreats right-to-left on unhover, and has a separate one-shot "closes left-to-right" version for a highlight that gets triggered rather than hovered (the TODO's own example: a search result).

### What was done
Added `Widgets/Checkbox.qml` and `Widgets/Radio.qml`: both reuse `Widgets/WidgetStates.js`'s existing seven-state resolution (hover/focus/disabled/invalid all read exactly like every other control in this directory — a `Checkbox`/`Radio` sitting next to a `Toggle` or a `StyledButton` in the same settings row behaves identically to keyboard/mouse) and the same controlled-component contract as `Toggle` (`checked`/`toggled(bool)`, caller owns the source of truth). Unlike `Toggle`'s full-inversion "selected" grammar, both stay an outline box at every state — only `.border` from `surfaceColors()` is used, never `.bg`/`.fg` — since the TODO's own wording ("square BORDER with...") describes an outline that gains an inner mark, not a box that inverts. The checkbox's X is two rotated `Rectangle` bars (not a `Canvas` stroke — a plain X needs no curved geometry, and a `Rectangle` stays trivially colour-reactive with no repaint bookkeeping, unlike this directory's `Canvas`-drawn icons); the radio's mark is a plain filled `Rectangle` that scales in from its centre.

Added `Widgets/Highlighter.qml`: two stacked `Text` items (rest colour underneath, highlight colour on top) with the top one clipped to a `[left, right]` window (both 0..1 fractions of the text's width). Plain hover only ever moves the right edge (0 at rest, 1 hovered) — that one parameter's `Behavior` alone gives both the L→R reveal-on-hover and, played in reverse, the "goes back R to L" on unhover the TODO asks for. A separate `trigger()` function drives the "closing L to R" motion for a triggered (non-hover) highlight: opens the window fully, then sweeps the LEFT edge across to meet the right edge (closing it away from the left), then resets both edges back to rest in one uninterruptible instant (`PropertyAction`, which sets a value without going through that property's `Behavior`) so the reset itself is never visible.

Fixed `Widgets/Toggle.qml`'s width: it used the `space5` design token (6ch) against a 2ch height, a 3:1 track — the file's own header comment says it intends "a ~5:2 track" (2.5:1), so the token name (`space5`, the fifth step) was mistakenly read as "5ch" on a scale that is actually non-linear past `space4` (1,2,3,4,6,8ch). Switched to `space4` (4ch), the nearest token that actually narrows it, giving an exact 2:1 track.

### Honest assessment
<span style="color:red">**NOT DONE: the switch's "colour transition is faster than the switch moving" complaint.**</span> Read every `Behavior` in `Toggle.qml` (track colour, track border colour, knob position, knob colour) and all four already use the identical `motionBDuration`/`motionBCurve` pair — no mismatched token exists in the file to fix, and the file has exactly one commit in its history, so there is no earlier, different value either. The cause was not diagnosed, so nothing was changed for it rather than guessing. Left a comment in the file with a concrete discriminating test for whoever picks this up next (does the gap scale if `motion-b-duration` is changed in Theme settings, or stay fixed regardless), and re-added a clean, bare TODO entry for it under Style.

None of the three new widgets (`Checkbox`, `Radio`, `Highlighter`) have an existing call site — this adds them to the design system as literally asked ("add ... to the design system"), it does not migrate any current control onto them. Concretely: the Dark/Light variant picker, the lock-screen ambient-effect picker and the new clock date-style picker (all `StyledButton`-based) were NOT converted to use `Radio`; no existing settings row uses `Checkbox`; no existing hover effect (Segment's own bar-icon hover sweep, any settings-row label) was converted to use `Highlighter`. Nothing currently on screen looks different from these three additions alone — only the `Toggle` width fix changes an existing, already-visible control.

Not verified on real hardware or a compositor — `phi-shell/CLAUDE.md` is explicit this cannot be run here. Checked brace balance on every changed/new file and did a full manual re-read of all four; caught and fixed two real issues before committing (an assumption that `font: otherItem.font` group-assignment is safe, reworked to set the three sub-properties individually like every other font-matching pair in this codebase; and a reset that relied on two independent same-duration `Behavior`s happening to animate in lockstep, reworked to an explicit, deterministic animation sequence with no such assumption). One assumption still stands, not independently verified: `Highlighter`'s reset (`PropertyAction`) is relied on to bypass that property's `Behavior` rather than fight it — this is `PropertyAction`'s documented purpose (the same mechanism `Transition` blocks use to set a value without animating it), but not run here to confirm; the failure mode if it's ever wrong is cosmetic (a brief sliver on reset) and only reachable once something actually calls `trigger()`. `Highlighter`'s exact visual proportions (reveal speed, mark sizes on `Checkbox`/`Radio`) are judgment calls, not measured against anything — flag if they read wrong once seen.

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Open the settings panel, go to any section with a switch (e.g. Theme > Night shift). The switch should look noticeably shorter horizontally than before this change — about two-thirds its previous length — with its height unchanged.
2. Toggle it on and off a few times, watching specifically whether the track/knob colour still appears to finish changing before the knob visually finishes sliding across. This is the part that was NOT fixed — confirm it is still reproducible (it should be, unchanged from before), and if it is now NOT reproducible, that is worth noting since the code made no change that should have affected it.
3. `Checkbox`, `Radio` and `Highlighter` are **not testable this round** — none of them has a call site anywhere in the shell yet (see above), so nothing new appears on any existing screen for these three. They will be checkable once a future change actually places one somewhere real; verifying them now would mean editing QML by hand just to see them render, which isn't a fair ask of this test pass.

---

## Status bar clock has no format settings (12/24-hour, seconds, date)

- **Date:** 2026-09-13
- **Repo / branch:** phi-shell / dev
- **Commits:** fc93d77 bar: add clock format settings (12/24-hour, seconds, date), f3958b5 merge: add clock format settings (12/24-hour, seconds, date), c089ff4 bar: split 12-hour clock format on a literal separator, not an offset, f3ed298 merge: split 12-hour clock format on a literal separator, not an offset
- **Original TODO:** "add settings for the status bar time in the settings panel. Allow to set the format with day/number/year/second etc."
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
A way to configure how the bar clock displays the time, covering (per the TODO's own list) the day (weekday name), a day number, the year and seconds — i.e. a date/time format setting, not just the bare `HH:mm` the bar has always shown.

### What was done
Added a new `Config/ClockPrefs.qml` singleton — same flat-JSON-at-`$XDG_STATE_HOME/phi/clock.json` mechanism `Config/LockPrefs.qml` already uses for the lock screen's ambient effect (deliberately not `phi state`, whose key set is closed and would need a `phi` rebuild, and not the repository, since this is runtime UI state) — holding three settings: `hour12` (12-hour clock with AM/PM vs. the existing 24-hour), `showSeconds`, and `dateStyle` (`off` / `short` — day/month, e.g. "13/09" / `long` — weekday, day, month name, year, e.g. "Sat 13 Sep 2026"). A new "Clock" group in `Settings/sections/Theme.qml` (right above the existing "Lock screen" group) exposes all three as a toggle, a toggle and a three-way button choice, matching the exact pattern the lock screen's own "Ambient effect" row already uses. `Bar/modules/Clock.qml` reads the three settings and builds the digit/date/AM-PM segments around the existing `Widgets.FlipDigit` cells; `Settings/sections.json`'s Theme row gained clock/time/date search keywords.

Kept the default look pixel-identical to before this feature: every new segment (the date text, the seconds cell pair, the AM/PM text) is wired with `visible: <its setting>`, and Qt Quick's `Row`/`Column` positioners exclude invisible children from layout entirely (not just hide them in place) — so with every new setting at its default (24-hour, no seconds, no date) the bar renders exactly the same tree of visible elements as before this change. Caught one layout bug in my own first draft before committing: a single flat `Row` with `spacing: root.gap` would have opened a gap between every individual digit, not just between the date/time/AM-PM segments — fixed by nesting the digit run in its own zero-spacing inner `Row`, with `root.gap` spacing only on the outer one.

Scoped this to the bar clock specifically, since that's what the TODO names ("the status bar time") — the separate large flip-clock in the calendar overlay (`Panels/Calendar.qml`) is untouched and still always shows `HH:mm:ss` regardless of these new settings.

### Honest assessment
Not verified on real hardware or a compositor — `phi-shell/CLAUDE.md` is explicit that this cannot be run here ("You cannot run this. Every visual result is verified by the user with a screenshot."). Checked what static analysis is available: brace-balance on every changed/new file, and a full manual re-read of both the new `Config/ClockPrefs.qml` (line-by-line diffed against the working `Config/LockPrefs.qml` it's modelled on) and the restructured `Bar/modules/Clock.qml` render tree. No `qmllint`/`qmlformat` was available in this environment to check QML syntax any more rigorously than that.

One design call made without being asked: 12-hour mode zero-pads the hour to two digits ("09:05 AM" not "9:05 AM"), so the digit-cell count stays fixed at two `FlipDigit`s regardless of hour — say if a single unpadded leading digit was actually wanted instead.

Caught one more risk before this was verified rather than after: the 12-hour hour/AM-PM split originally used fixed `substring()` offsets on Qt's combined `"hhAP"` output, which silently assumes the AM/PM text is always exactly 2 characters — not guaranteed across locales. Reworked to format as `"hh AP"` and split on the literal space instead, which is correct regardless of the meridiem string's length. Still not run against a non-English locale.

The "long" date style's weekday/month names come from Qt's own locale-aware `ddd`/`MMM` format tokens, so they'll follow whatever locale the shell runs under rather than being hardcoded English — not verified against a non-English locale.

### How to test it
1. Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save (per its own README), so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.
2. Open the settings panel, go to Theme, and scroll to the new "Clock" group (search "clock" or "time" also finds it). It sits directly above "Lock screen".
3. Toggle "12-hour clock" on — the bar clock (bottom-right, the segment showing the time) should switch from e.g. "14:07" to "02:07 PM": two hour digits, then the existing minute digits, then a plain "AM"/"PM" label. If the hour reads as something other than two digits, or the label after it is garbled instead of "AM"/"PM", the format split broke. Toggle it back off to confirm it returns to 24-hour.
4. Toggle "Show seconds" on — a third digit pair should appear after the minutes, e.g. "14:07:32", ticking every second. Toggle it off — the bar clock should return to exactly the same width and look it had before either setting existed.
5. Click "Short" under "Date" — the bar clock should gain a date prefix like "13/09" before the time. Click "Long" — it should instead read like "Sat 13 Sep 2026" before the time. Click "Off" — the date prefix should disappear and the clock go back to just the time.
6. Click the clock itself (with any combination of the above set) — it should still open/close the calendar overlay exactly as before; the calendar overlay's own big flip clock is unaffected by these settings and always shows `HH:mm:ss`.
7. Settings persist across a shell restart: `pkill -x qs; qs -p ~/.config/quickshell/phi`, then confirm the bar clock still shows whatever format was last chosen.

---

## No way to invert scroll direction for the mouse or trackpad

- **Date:** 2026-09-13
- **Repo / branch:** phios-dotfiles / dev
- **Commits:** 9086294 hyprland: invert scroll direction for mouse and trackpad, 4fbc2b3 merge: invert scroll direction for mouse and trackpad
- **Original TODO:** "add a setting to invert the scroll wheel (mouse/trackpad)"
- **Requires phi rebuild:** none — this doesn't touch the `phi` repo

### What was asked
A way to invert (reverse) scroll direction, for both the mouse wheel and the trackpad.

### What was done
Set `natural_scroll = true` in the existing top-level `hl.config({ input = {...} })` block in `profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`, alongside the `follow_mouse` value already there. Confirmed on Hyprland's own wiki that `natural_scroll` set at this top level (as opposed to nested under a separate `input.touchpad` table, which exists only for setting the touchpad *differently* from the mouse) applies uniformly to every pointer device — mouse and trackpad alike, matching the "(mouse/trackpad)" scope of the request exactly. Verified the template still parses as valid Lua with `luac -p` (after substituting its `${PHI_*}` placeholders with dummy values, since `luac` can't parse the raw `.tmpl` file).

This is a fixed value in the shared config, not a live toggle in the settings panel — `Settings/sections/Devices.qml`'s existing "Pointer" group already documents pointer settings as living in `hyprland.lua`, not as panel-editable runtime state (its own comment cites "§9.12 perimeter"), and this follows that same, already-established boundary rather than opening a new one.

### Honest assessment
<span style="color:red">**NOT DONE (a real, deliberate scope cut, not an oversight): a settings-panel toggle.**</span> "Add a setting" was read as "add a config option" rather than "add a live on/off switch in the settings UI" — but the more this gets looked at, the less confident that reading is. The same read-only "Pointer" group's own caption ("Mouse and trackpad sensitivity are set in hyprland.lua, not runtime state") is plausibly exactly what prompted this request in the first place — a user looking at a read-only pointer section and asking for "a setting" there. `docs/TODO.md`'s own neighboring entries ("add suspension/hibernation settings in the settings panel", "add option for automated night mode") show this user uses the word "setting" for panel-editable things elsewhere. If a live panel toggle was actually wanted, this needs a new `phi state` key, a `Widgets.Toggle` in `Devices.qml`'s Pointer group, and a live `hyprctl keyword input:natural_scroll` call alongside the template default — a materially bigger feature than what shipped. Say which reading was wanted; the toggle is a separate, quick follow-up if so.

Not verified on real hardware — no compositor is available here to actually feel the scroll direction change, only Lua syntax and the Hyprland wiki's documented semantics. Applies to `zotac` and `razer` (both use the `desktop` profile this template belongs to); `mini` never renders this file (headless, no graphical session).

This inverts scroll for **both** mouse and trackpad uniformly, since that's what "(mouse/trackpad)" in the request reads as. If only one device should actually be inverted (e.g. trackpad natural-scrolling, mouse wheel traditional — a common split, since physical mice and trackpads conventionally scroll opposite ways from each other on some systems), that needs `input.touchpad.natural_scroll` set independently instead of (or in addition to) the top-level one — flag it if the uniform version feels wrong once tried.

### How to test it
1. Find your active variant (`phi state get theme.variant`, prints `dark` or `light`) and run `phi theme set <that variant>` — `hyprland.lua.tmpl` is a Class A adapter (`design/adapters.txt`), so this one command both re-renders `~/.config/hypr/hyprland.lua` from the updated template and runs `hyprctl reload` for you.
2. Scroll down on a mouse wheel, or swipe up on the trackpad the way that used to scroll content down — content should now scroll the opposite way (up) from before this change, and vice versa.
3. Check both the mouse and the trackpad on `razer` (the only host with both); check the mouse on `zotac`.

---

## Opening an image flashes a terminal window instead of showing the picture

- **Date:** 2026-09-13
- **Repo / branch:** phi / dev, phios-dotfiles / dev
- **Commits:** phi: 92d3f7a query: open images with imv explicitly, not unmanaged xdg-open, e64e474 merge: open images with imv explicitly, not unmanaged xdg-open — phios-dotfiles: cb6b49d hyprland: float and centre imv's window instead of tiling it, 4ac108e merge: float and centre imv's window instead of tiling it, 4221e39 yazi, hyprland: close the yazi image-open path, drop unverified center/size, f3279b5 merge: close yazi image-open path, drop unverified center/size
- **Original TODO:** "currently opening a image just opens a terminal window that then immediatly closes. Images should instead persist, start in floating state instead of tiled and use the layout shown in references/floating-panels-reference.JPG ."
- **Requires phi rebuild:** yes — no tag covers this yet, same situation as the runner-ranking entry below: this commit is only on `phi`'s `dev`, past the currently-published `v0.16.1` (`main`); merging `dev` into `main` is a user decision (`AGENTS.md` rule 1), so tag once that happens.

### What was asked
Clicking an image result in the launcher was opening (and instantly closing) a terminal window instead of showing the picture. Asked for the image to persist on screen, open floating rather than tiled, and roughly match the loose, scattered floating-window look in `references/floating-panels-reference.JPG`.

### What was done
<span style="color:red">**The exact mechanism that makes a terminal window flash open and close was NOT identified** — nothing in either code path this agent could find actually spawns a terminal for an image (see below), so something about how it fails on the real machine is still unaccounted for.</span> What was found and fixed instead: **both** ways this system opens a file by path bottom out in a bare `xdg-open <path>`, which resolves through a `mimeapps.list` default-application association that neither this repository nor its live checkouts configure (checked — no `mimeapps.list`, no `.desktop` file, anywhere in `phios-dotfiles`): `phi/internal/query/files.go`'s `FilesProvider` (the launcher) runs `xdg-open` directly, and yazi's own bundled default opener for `image/*` (`phios-dotfiles` ships no `[opener]` override before this change) is documented upstream as `xdg-open %s1` too (`yazi-config/preset/yazi-default.toml`, `sxyazi/yazi`). Whichever of the two the user actually hit, an unmanaged, whatever-the-machine-happens-to-resolve default is a real bug worth removing regardless of whether it explains a terminal specifically.

Fixed at both call sites by naming the real, already-installed viewer explicitly instead of going through `xdg-open` for images: `FilesProvider` now runs `imv` directly for image extensions (`.jpg/.jpeg/.png/.gif/.bmp/.webp/.tiff/.tif`, case-insensitive) with an explicit `-i phios-imv` app id (mirrors the existing `phios-btop` "-e"-wrapped-CLI-tool precedent in `hyprland.lua.tmpl`); `profiles/base/home/.config/yazi/yazi.toml` gained a `[opener]`/`[open].prepend_rules` override doing the same for yazi's `image/*` rule (verified the TOML with Python's `tomllib`, not just by eye). Everything else (non-images) is untouched, still through `xdg-open`. Also fixed a real latent bug found alongside the launcher change: `FilesProvider` never quoted the file path before handing it to `sh -c` (`Launcher.qml`'s `"exec"` action runs `Data["command"]` through a shell) — a `$HOME` path with a space or shell metacharacter would have broken — added a `shellQuote` helper, applied to both the imv and xdg-open branches.

`phios-dotfiles`: added an `hl.window_rule` in `hyprland.lua.tmpl` matching `class = "^phios-imv$"` with `float = true` — floating instead of tiled, the literal ask. An earlier draft of this rule also set `center = true` and `size = "60% 70%"`, copied from Hyprland's classic (non-Lua) `windowrule` syntax; caught before landing that Hyprland's own Lua-binding effect-field list (float/tile/fullscreen/move/size/opacity/tag, per a DeepWiki read of `LuaBindingsInternal.hpp`) has no `center` at all, and that real Hyprland users have hit hard config-parse errors from an unrecognized window-rule field (GitHub discussion #12492) — on this project's three daily-driver machines that risks the *entire* `hyprland.lua` failing to load, not just this one rule, so `center`/`size` were dropped rather than shipped on unconfirmed syntax. Verified the template's Lua syntax with `luac -p` after both the original and the follow-up edit (substituting its handful of `${PHI_*}` placeholders with dummy values first, since `luac` cannot parse the raw `.tmpl` file).

### Honest assessment
<span style="color:red">**NOT DONE / NOT CONFIRMED: the actual terminal-flash mechanism.**</span> Both `Quickshell.execDetached(["sh","-c","xdg-open "+path])` (the launcher) and yazi's own `xdg-open %s1` opener are plain, non-terminal invocations — neither obviously explains a terminal window appearing at all, let alone one that closes immediately. This fix removes the one clearly-unmanaged, whatever-the-machine-resolves behaviour common to both known paths, which is worth doing regardless, but if the real cause was something else entirely (a third path not found, or a machine-local `mimeapps.list`/`.desktop` override outside this repo's control), the symptom could still recur — worth confirming on real hardware which specific action (launcher search vs. yazi) was actually used when this was first seen, if it comes up again.

Not verified on real hardware otherwise — `phi-shell/CLAUDE.md`'s "you cannot run this" applies equally to `phios-dotfiles`' compositor-facing config; no compositor is available here. `go build/vet/test ./...` are clean for the `phi` change; the yazi TOML was validated with a real parser (Python `tomllib`); the Hyprland Lua syntax was checked with `luac -p`, but not against a live Hyprland instance, and the exact `size` field's own accepted format (string? two numbers? percent support in the Lua binding specifically?) was deliberately left unshipped rather than guessed at a second time.

Deliberately did not attempt to build the "scattered floating panels" collage look the reference image actually shows (several windows of different sizes at different, seemingly hand-placed positions) — that reads as a general "floating, not tiled, roughly like this" illustration rather than a literal per-window layout spec, and building an actual multi-window arrangement system was not asked for and would be well beyond this bug's scope. A plain floating window (Hyprland's own default placement/size for a newly-floated window, whatever that is) was read as the reasonable, literal interpretation of "floating instead of tiled" once a specific centred size couldn't be safely shipped.

The image-extension list is fixed and small (no RAW formats, no AVIF/HEIC) — extend `imageExtensions` in `phi/internal/query/files.go` (and the yazi opener's `mime` match, if it should differ) if a format actually used is missing.

The yazi opener sets `orphan = true` for imv, by inference from the upstream preset's `play` group (which sets it for its own `xdg-open`) rather than the `image/*` rule's actual `open` group, which upstream does *not* mark orphan — this is a deliberate behaviour change: with `orphan = true`, closing the kitty window hosting yazi leaves imv running rather than killing it with its parent, which seems like the right behaviour for a viewer but was not something upstream itself does for images.

### How to test it
1. Rebuild and reinstall `phi` from this commit (see "Requires phi rebuild" above — needs `dev` merged to `main` and a tag first) for the launcher half. For the dotfiles half: `~/.config/yazi/yazi.toml` is a straight symlink into the repo checkout (`phios-dotfiles`'s "home/ tree symlinked wholesale" mechanism), so pulling the repo alone is enough — no reinstall needed, yazi picks it up next time it opens. For `hyprland.lua`: find your active variant (`phi state get theme.variant`) and run `phi theme set <that variant>` — `hyprland.lua.tmpl` is a Class A adapter (`design/adapters.txt`), so this one command re-renders it and runs `hyprctl reload` for you.
2. From the launcher: search for an image file that exists somewhere under your home directory (e.g. a `.jpg` or `.png` in `~/Pictures`) and select it.
3. From yazi separately (`kitty -e yazi`, or however you normally open it): navigate to the same or another image file and press its "open" key.
4. In both cases: before this fix, one or both of these was reported to flash a terminal window open and immediately close, with no image ever visible. After this fix, both should open the image with `imv`, as a floating window (not filling/tiling the screen) that stays open until you close it yourself (`q` in imv, or closing the window normally) — it must not vanish on its own. If you can tell which of steps 2/3 was actually broken before, that is useful to know either way — it isolates which of the two fixes actually mattered for the real report.
5. As a regression check, select/open a non-image file (e.g. a `.txt` or `.pdf`) both ways — it should still open via whatever `xdg-open` resolves on that machine, unchanged from before this fix.
6. If a path under your home directory has a space in it (e.g. `~/Pictures/Trip Photos/beach.jpg`), confirm the launcher still opens it correctly rather than failing or truncating at the space — this was a separate, latent bug fixed alongside the main one.

---

## Runner bar shows a meaningless plot for ordinary words instead of the app being searched for

- **Date:** 2026-09-13
- **Repo / branch:** phi / dev
- **Commits:** 086858c mathx: stop treating an ordinary word as an implicit plot variable, 36f949d merge: stop mathx from plotting ordinary words as implicit variables, 988c4e9 mathx: clarify the implicit-plot guard's comment on Greek letters, 48537be merge: clarify implicit-plot guard comment
- **Original TODO:** "the ranking of the runner still needs revision. Almost all strings will be accepted as variable for a simple f=x, for example if i write \"stea\" i get f=stea before \"Steam\". Not only it should be ranked differently (the order should be something like: apps, HOME files (non hidden or children of hidden folders), commands, phi commands, search any file, ask ai agent, search web, math, convertion), unless the syntax is a perfect match, in that case the ranking grows. Also if it's multiple words files should be ranked less then web search and \"ask ai\". Mathx should just not consider unusual multi letter variable, unless a prefix \"math\" is used (see below)"
- **Requires phi rebuild:** yes — no tag covers this yet. This commit is only on `phi`'s `dev` (past the currently-published `v0.16.1`, which is what `main` still points to); merging `dev` into `main` is a user decision (`AGENTS.md` rule 1), so no new tag was created. Once merged, tag `vX.Y.Z` on `main` for this and any other pending `phi` changes to release together.

### What was asked
The launcher's ranking needs an overhaul. The report bundles several distinct problems: (1) `mathx` treats almost any typed string as a valid one-variable expression and plots it — typing part of an app name like "stea" produces a graph instead of nothing, letting it compete with the real "Steam" app match; (2) results should sort by a specific nine-category order (apps, home files, commands, phi commands, search-any-file, ask-ai, web search, math, conversion) rather than the current tiering; (3) an exact/perfect-syntax match should be able to outrank a result from a normally-higher category; (4) a multi-word query's file results should rank below web search and "ask ai"; (5) `mathx`'s free-variable guessing should be restricted unless an (as yet unbuilt) "math" prefix is typed.

### What was done
Fixed only (1), at the root cause in `mathx` itself rather than papering over it in the ranking layer: `internal/mathx/engine.go`'s `evalNumeric` used to fall back to plotting *any* expression with exactly one free variable that wasn't a recognized unit name — so a bare word like "stea", "cd", or "steam" became `y = stea` and returned a trusted, high-scoring calculator result. The fallback is now restricted to a single-*character* variable name (`x`, `y`, `t`, `θ`, …) — the conventional shape of an actual unlabelled unknown — so an ordinary multi-letter word is rejected outright (`Evaluate` returns an error, and `CalculatorProvider.Query` correctly turns that into no result at all, per its existing error handling). An explicit `plot <expr>` command is untouched and still accepts any variable name, of any length — only the implicit, nobody-asked-for-it fallback was narrowed. Added `TestImplicitPlotRejectsWords` / `TestImplicitPlotKeepsSingleLetterVariable` in `internal/mathx/mathx_test.go` and `TestCalculatorRejectsBareWordAsVariable` in `internal/query/calculator_test.go`.

Investigated (2)/(3)/(4) in detail before deciding not to touch them (see below) and re-filed the genuine remainder as its own `docs/TODO.md` entry.

### Honest assessment
<span style="color:red">**NOT DONE:** the nine-category ranking order (point 2), the perfect-match cross-category promotion rule (point 3), and multi-word files ranking below web search / ask-ai (point 4) are all still open — none of that was attempted this round. `internal/query/rank.go` already has a category-tier system (added 2026-09-11, before this backlog entry was even filed) with six tiers, not nine; math/currency's tier sits *above* commands, ssh, zoxide and web search, the opposite of the order asked for; the tiers are deliberately spaced 1000 apart specifically so no per-query match-quality score can ever cross a tier boundary, so "perfect match ranks higher across categories" needs a real design decision (an explicit cross-tier promotion rule) rather than a bigger number; there is no "ask ai agent" launcher provider at all yet (`internal/agent` isn't wired into `internal/query`); and only one, home-directory-only file search provider exists, not the broader "search any file" category the order calls for. Re-filed as a fresh, standalone `docs/TODO.md` entry describing just that remainder.</span> Point 5's "unless a prefix 'math' is used" clause is explicitly out of scope until the separate prefix feature (the next `docs/TODO.md` entry, "Add prefix feature to the runner bar") is built — the ticket itself says "(see below)" — but the non-prefix half of point 5 ("mathx should not consider unusual multi letter variable") is exactly what this change does.

The reported repro itself ("stea" outranks "Steam") did **not** reproduce against current `dev` before this fix — the category-tier system already makes any app match beat any math result by thousands of points. Verified with `go run ./cmd/phi query stea` before the fix: it returned `y = stea` as the *only* result (this darwin dev machine has no matching `Steam` app to rank against), and after the fix it correctly returns no result at all. The underlying defect (an ordinary word silently becoming a trusted plot result) is real and worth fixing regardless of whether the exact "beats Steam" scenario reproduces on `razer`/`zotac` today — it was very likely true against whatever `phi` build the user tested with before the tier system landed.

Not run against a live `phi query` on `razer`/`zotac` — verified with `go test ./...` (all packages pass) and manual `go run ./cmd/phi query <text>` on this development machine only, per rule 4 (the three real machines are off-limits to this agent).

### How to test it
1. On `razer` or `zotac`, pull the latest `phi` package once it is rebuilt from the tag above (or, for a quick check without a rebuild, run `phi query stea` and `phi query cd` from a terminal with a `phi` checkout that has this commit).
2. Before this fix: `phi query stea` (redirected, so it prints JSON) returns a `"provider":"calculator"` result titled `"y = stea"`. After this fix: it returns `[]` (unless a real app/file/command happens to match "stea").
3. Try `phi query x` and `phi query y` — these should still work exactly as they did before this change: `x` returns a `"kind":"plot"` calculator result (a single-letter variable is still treated as a legitimate implicit plot, unaffected by this fix). `y` returns `[]`, but not because of this fix — "y" was already excluded before this change too, because it's a recognized unit abbreviation for "year" (`UnitKnown`); it's listed here only so its `[]` isn't mistaken for a regression.
4. In the launcher itself (Super+Space or however it's bound), type a few letters of an app name that also happens to look like a short word (e.g. "cd", part of an app you have installed) — it should no longer show a graph card above or instead of the app.

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
