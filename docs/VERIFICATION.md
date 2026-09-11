# Features to be verified

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.

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
