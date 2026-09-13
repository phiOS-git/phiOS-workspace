# Features to be verifiedw

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.



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
- **Commits:** 6783bab hyprland: leave Steam/btop's dedicated workspace when a panel opens, 89266e3 merge: leave Steam/btop's dedicated workspace when a panel opens
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

### How to test it
Rebuild is not required — `phi-shell` hot-reloads every `.qml` file it has loaded on save, so once this branch's files are in place at `~/.config/quickshell/phi`, no restart is needed.

1. Switch to workspace 11 (Steam) or 12 (`btop`) — click their icon in the bar, or `hyprctl dispatch workspace 11`.
2. Open any panel: click the bar bell (notifications), press Super+P (agent), press Super+S (settings), or click a right-isle icon (volume/wifi/etc.). The active workspace should switch away from 11/12 to whichever of workspaces 1–10 has windows open (the highest-numbered one with something in it), before or as the panel appears.
3. With nothing open on any of workspaces 1–10 (a fresh session), repeat step 2 — it should land on workspace 1 instead of doing nothing.
4. Open a panel while already on an ordinary workspace (say, workspace 3) — nothing should happen to the active workspace; only the panel opens.

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
