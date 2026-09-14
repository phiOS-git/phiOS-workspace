# TODOs

The user's backlog. An agent that starts on an entry prefixes it with
`[taken]`; when the change is committed the entry is removed from here and
written up in `VERIFICATION.md`. See `AGENTS.md` — *The TODO / VERIFICATION
loop*.

Full hardware-verified research and dead-end investigation notes behind the
entries below live in `docs/investigations.md`, so this file stays quick to
scan — an investigated entry ends with a pointer there instead of the full
writeup.

## Open Questions

Quick index of every entry below still waiting on a decision. Answer
directly here or on the matching entry (add an **Answer:** line the way
the sensor/permission entry already has) — either way, keep this index and
the entries in sync: when a question is answered, update or remove it in
both places.

1. **Search-any-file provider:** indexed (`plocate`) vs. a live `fd` over
   an explicit extra-roots list — and which roots per host?
2. **Scratchpad bar icon:** reopen ADR 134 to give the scratchpad its own
   independent active-state, polled via `hyprctl monitors -j`?
   **Recommendation (2026-09-14, style pass):** yes, buildable — Hyprland's
   documented `hyprctl monitors -j` schema gives each monitor object a
   `specialWorkspace.name` field, empty when none is open and (per the
   toggle command already in use, `toggle_special("scratch")`)
   `"special:scratch"` when the scratchpad is. A `Process` + `Timer` poll
   in `Services/HyprlandBridge.qml`, same shape as this project's other
   `Quickshell.Io.Process` bridges, would let `Bar/modules/Workspaces.qml`
   bind the scratchpad Segment's `active` to
   `specialWorkspace.name === "special:scratch"` for its own screen — ADR
   134's actual concern (a numbered workspace and the scratchpad both
   reading "active" at once) doesn't apply, since Segment's `active` is
   per-button, not a single shared flag. NOT implemented this pass: this
   would be a new always-on background poll and a JSON field this project
   has not confirmed against `hyprctl monitors -j` on real hardware — this
   session's own Lua-eval `dispatch()` bug (see `Services/
   HyprlandBridge.qml`) is a direct example of this exact Hyprland build
   deviating from documented/typical behaviour, so shipping this without a
   real check felt like repeating that mistake rather than learning from
   it. Next session with terminal access to a live Hyprland instance: run
   `hyprctl monitors -j` with the scratchpad open and closed, confirm the
   field name/value, then wire it up as above.
3. **Trash feature:** which package/integration, and does it need a `phi`
   verb / runner integration?
4. **System file picker:** a native portal backend, a picker built into
   phi-shell itself, or both?
5. **Chat/notification gesture:** trigger on 4 fingers, or 3 fingers + a
   held modifier, since 2-finger and edge-start aren't available?
6. **Always-empty workspace:** what was the cut-off part of the request,
   and is reopening the dynamic-workspaces decision (§2.3) acceptable?
7. **Default wallpaper + palette:** want a few candidate palettes proposed
   (WCAG-checked) before one is committed?
8. **VPN panel restructure:** single master row + picker — exclusive
   (switching configs brings the old one down) or independently toggleable?
   **Answer (2026-09-14, style pass):** independently toggleable — this is
   already how `Services.Vpn`/`wg-quick` actually work (each tunnel is its
   own independent interface; nothing about running two at once is
   incorrect or conflicting), and the Settings page and bar popout already
   render it that way, per-tunnel. No restructure needed beyond the one
   real bug found: `Panels/BarPopout.qml`'s "network" card showed a
   disabled-but-visible switch when zero tunnels existed, reading as "on
   and transparent" — replaced with plain status text (the Settings page's
   own disabled-with-reason pattern stays, unchanged, since that page has
   room to explain why and already applies that pattern to every
   capability-gated group, not just VPN).
9. **Scrim/dim split:** what does "the scratchpad" dim refer to (nothing
   implements a scratchpad dim today), and is it acceptable for Clipboard
   to share whatever change is made to the Notifications panel's dim?
   **Partial answer (2026-09-14, style pass):** the two-intensity half is
   done — `PHI_OVERLAY_SCRIM_STRONG` (a new design token, both variants) for
   the "covers the bar" surfaces (screenshot selection, Alt-Tab/overview,
   battery/timer alerts, and — a judgment call — a destructive
   confirmation), `PHI_OVERLAY_SCRIM` unchanged for everything else. The
   "does/doesn't cover the bar" half is still open — see the Style section's
   own bare entry on it, split out separately since a real fix needs a
   Wayland layer-shell change this session could not verify.
10. **Dotfiles "Better separation":** which part of the installer/profile
    split reads as poorly separated today?
11. **"Remove AI shenanigans":** which files/directories/artifacts,
    specifically?
12. **`~/.local/share/phios` relayout:** worth doing even though it can
    only be verified with a real reinstall — and should the installer
    auto-migrate an existing old-layout install?
13. **Installer:** what specifically is lacking about the current one?

## Bug Fixing / Improvements

### New and Urgent

1. In the notification panel, all the clear buttons (single, group, all) don't work until i run `phi theme set` at least once. Investigated 2026-09-14: no code defect found — `clearAll`/`clearApp`/`clearEntry` (Services/Notifications.qml) update `history` in-memory before ever touching disk, so a persistence failure alone can't explain the buttons visually doing nothing; the click-wiring in Panels/tabs/Notifications.qml and Widgets/SmallButton.qml/StyledButton.qml reads correctly by inspection, and no ancestor sets `enabled: false` anywhere in Panels/Sidebar.qml. Traced what `phi theme set` actually does to phi-shell specifically (`phi/internal/theme/set.go` + `phios-dotfiles/design/adapters.txt`): for phi-shell's row the reload command is `-` (none) — its only effect is writing `Config/Tokens.qml`, which Quickshell's own file-watcher then hot-reloads. So the working theory is a stale-binding/startup-race bug that a hot-reload happens to clear, not something `phi theme set`'s content is actually responsible for — but this is unconfirmed, could not reproduce without running the shell. Next time this happens: capture `qs -p ~/.config/quickshell/phi` stdout/stderr at the moment a clear button is clicked and does nothing (any QML warning at that instant is the missing clue), and check whether the DND toggle / group-collapse controls (different widgets, same tab) work at that same moment — narrows whether this is Notifications-tab-wide or specific to SmallButton/StyledButton's `clicked()`.

### Older 

- on razer the trackpad does not work after hibernation — to be tested,
  might already be solved.

- tailscale/vpn and network overlay and status bar icon should be merged
  into a single element, showing network information. It should display
  in the bar: the type of connection (LAN/WIFI), its status (enabled,
  disabled, wifi intensity, and an X on the LAN/WIFI icon if connected but
  without internet), and a VPN icon if active, tailscale icon if
  connected. The overlay panel should have 2 states: compressed and
  expanded. It should show most of the relevant network information and
  switches: type of connection, firewall, VPN, the network speed and ping
  visual, a list of active servers (grouped by source) with killswitches,
  and so on. All the advanced settings should be available in the settings
  panel, while most common interactions should be available in this panel
  as well.

- after hibernation, the screen automatically suspends after 1 minute,
  which is not the normal behavior (it should take longer). No idle-timeout
  config exists anywhere in this repo — nothing here to misconfigure.
  *(full notes: `docs/investigations.md#idle-timeout-after-hibernation`)*

- area selection in screenshot, OCR and QR reading is never right — the
  offset changes as the size and position of the area change. Hardware-
  measured: not a coordinate bug — at integer monitor scale, capture is
  pixel-perfect at every size. At fractional scale (e.g. razer likely
  runs), larger selections show real pixel noise that also reproduces in
  a bare full-screen `grim` capture with zero phi-shell code involved —
  points to compositor/GPU dithering under fractional scaling, not an
  offset bug. No fix identified yet.
  *(full notes: `docs/investigations.md#screenshot-area-selection-offset`)*

- improve the neovim chroma integration, with as many mappings as
  possible: only valid next-keys should be backlit, colour-coded by the
  nature of the command (e.g. pressing "g" lights the numbers in one
  colour, the g in another). Currently the colours change smoothly; they
  should change instantly instead. Needs a full key-name → (row, col)
  mapping table that can only be built by hand on the real keyboard, and
  the underlying `org.razer` DBus service has never been confirmed
  reachable from any environment this project has run in.
  *(full notes: `docs/investigations.md#neovim-chroma-per-key-integration`)*

- when in full screen, the status bar does not appear by moving the
  cursor on the top edge. The bar's auto-hide/edge-reveal code looks
  correct by reading, but how a Top-layer bar interacts with a fullscreen
  window is genuinely unsettled upstream in Hyprland right now (a relevant
  PR is still in draft) — depends on the exact Hyprland version installed
  on razer, which isn't recorded anywhere in this repo.
  *(full notes: `docs/investigations.md#status-bar-not-appearing-in-fullscreen`)*

- the network speed graph (settings + bar overlay) does not show real
  numbers: it's always around 1Kb/s both upload and download. Also make it
  visually match the reference more: https://github.com/programmersd21/flow
  Hardware-verified on zotac: the rate math itself is correct (matched a
  real download's curl-reported speed almost exactly). Leading candidate:
  `NetStats.qml` measures whatever interface owns the default route — if a
  VPN/Tailscale exit node is up, it measures the tunnel's small, constant
  traffic instead of the real link. Needs checking, mid-bug, on whichever
  host reproduces this: does `ip route show default` name the real NIC or
  a tunnel?
  *(full notes: `docs/investigations.md#network-speed-graph-wrong-numbers`)*

- zsh in dark theme has the directory in black on black. Traced
  end-to-end and **does not reproduce on zotac** — real renderer, real
  tokens, and a real zsh session all render the correct colour; on-disk
  config matches. May be razer-specific. Diagnostic for next time: is the
  OTHER prompt segment (`user@host`) also black, or only the directory? If
  both, something is stripping the whole prompt at runtime; if only the
  directory, the on-disk file isn't what this repo's renderer produces.
  *(full notes: `docs/investigations.md#zsh-black-on-black-directory`)*

- wifi speed graph does not show real values, it's stable at 1kb/s with
  5kb/s peaks (it should be ~20Mb), both upload and download — same bug as
  "the network speed graph ... does not show real numbers" above
  (`Services/NetStats.qml` is the one singleton behind both surfaces); see
  that entry rather than duplicating it here.

- the scratchpad bar icon has no visual "shown" state — it always looks
  the same whether the scratchpad is currently visible or not. This was a
  deliberate choice (ADR 134 in `Workspaces.qml`): a numbered workspace and
  the scratchpad could both read "active" at once, so a shared toggle
  state would lie half the time. It may not be a hard blocker anymore —
  `hyprctl monitors -j` now exposes `specialWorkspace.name`, a source this
  project already polls elsewhere for state Quickshell can't read
  directly. See Open Questions #2.
  *(full notes: `docs/investigations.md#scratchpad-bar-icon-no-visual-state`)*

- the power overlay buttons show no text and don't do anything on click.
  Investigated 2026-09-13: the label binding and the full click → dispatch
  chain (`BarPopout.qml` → `SmallButton.qml` → `PowerActions.qml`) reads
  correctly wired; no defect found by reading. The confirm step this used
  to lead into is now `Services/ConfirmDialog.qml`, a separate modal.
  Needs a screenshot of the actual on-screen failure to progress further.

- the runner needs a "search any file" category (beyond the existing
  home-directory-only file search), ranked below phi commands and above
  ask-ai-agent. A live filesystem-wide `fd` pass can't fit the launcher's
  ~120ms per-provider budget — needs a design decision first. See Open
  Questions #1.

## Features

- add trash feature (package to be picked). Options (to be checked if
  they work as expected): CliFM (cli), ... — check the list on
  archlinux.org file manager. See Open Questions #3.

- system file picker required. See Open Questions #4.

- joining a new secured Wi-Fi network from the shell needs a password
  path that keeps the secret off the process command line — `nmcli device
  wifi connect <ssid> password <pw>` puts the password on argv, readable
  via `/proc/<pid>/cmdline` to any local user, not acceptable. The real
  argv-free mechanism (`passwd-file`, via `nmcli connection up`) needs a
  prior `connection add` with the correct `wifi-sec.*` fields per security
  type (WPA-PSK / WPA3-SAE / WEP differ) — not verifiable without real
  hardware. Already-known/open networks need no secret and already work
  (see `VERIFICATION.md`); this entry is only the secured-and-not-yet-known
  case.

- spotlight cursor: super+super (double tap hold). Still blocked upstream
  in Hyprland (bare-modifier-only keys never deliver a release event, as
  of v0.56.2) — not fixable here. Already worked around (bound to SUPER+G
  instead, shipped). Nothing to recheck until a newer Hyprland release
  ships.
  *(full notes: `docs/investigations.md#spotlight-cursor-super-super`)*

- consideration: usare alt come super, così avrei 2 super invece che 2
  alt. Da valutare con software che usano alt [TBD]

- add gestures to open the chat and notifications panel: 2 finger swipe
  from edge (touchpad). Make the inverted gesture to close the panel as
  well. It should move progressively with the scroll, not only a togglable
  state. Progressive/live gesture tracking is buildable (Hyprland's
  `hl.gesture()` supports live start/update/finish callbacks). The literal
  "2 finger swipe from edge" is impossible: libinput itself claims 2-finger
  movement for scrolling before Hyprland's gesture layer ever sees it, and
  `hl.gesture()` has no "starts from edge" concept at all. Three fingers is
  also already fully claimed (Alt+Tab / workspace-switch). See Open
  Questions #5.
  *(full notes: `docs/investigations.md#gesture-open-chat-notification-panel`)*

- the SUPER+L power menu's Hibernate row still has no icon. Checked
  nerd-fonts' `glyphnames.json`: no glyph named "hibernate" exists, and no
  close synonym (sleep, power_standby, moon, bed) reads as hibernate
  specifically either — needs a deliberate substitute pick, since Lock/
  Suspend/Reboot all use a real, exact-named icon.

- there should always be at least 1 workspace (other than the special
  ones), also there should always be at least an empty workspace (so if i
  ope[n...]). See Open Questions #6.

- i added `references/default-phios-wallpaper-placeholder-light.jpg` as a
  file that should be included in the phios repositories (dotfiles i
  think) for fresh installations. It should not be reapplied on updates,
  but it should be the selected one when first installing the system
  (apply a colour inversion for the dark theme, not at runtime but
  generate an inversion of the provided image). Also set the default
  light and dark colours from the colours used in that image (rebuild the
  palette starting from those, also pick a better pink, inspired by all
  the references). See Open Questions #7.

## Style

- the settings-panel switch's color transition still looks like it
  finishes before the knob finishes sliding across. Investigated: no
  mismatched duration/easing found in `Toggle.qml` — every transition
  already shares the same motion tokens. Left undiagnosed rather than
  guess at a fix; a concrete diagnostic test is on file for next time this
  is looked at on real hardware.
  *(full notes: `docs/investigations.md#settings-switch-color-transition`)*

- continue the file-by-file UI/UX read-through into whatever a session
  with more time doesn't reach: this repo has 157+ `.qml` files. Several
  rounds so far have covered the shared widget library, the bar and every
  bar module, all nine Settings sections, the sidebar/agent panel/their
  sub-tabs (including a second, deeper pass over the agent panel and the
  launcher's own result-list rendering), lock screen, clipboard, Alt-Tab,
  screenshot/OCR/QR/colour-picker, the cheat sheet, the calendar/quick-note
  corner panels, the notification toast, and every full-screen dialog
  (confirm/power-menu/battery-alert/timer-alert) — not an exhaustive audit
  of literally everything (Widgets/Segment's many icon-drawing siblings —
  BatteryIcon, GpuIcon, SunMoonIcon, etc. — were reviewed only at their
  call sites, not read individually, since they are pure rendering
  primitives with no interaction of their own to critique; the Lock
  screen's five ambient backdrop effects — LavaLamp, Life, MatrixRain,
  Plasma, Starfield — were not read at all, being pure decoration with no
  interaction surface of their own).

- add status bar icons for active sensors (microphone, camera); the
  overlay should show a list of apps with the sensor they are using and
  killswitches. Also add settings for killswitches and permission rules.
  Investigated: the microphone half is buildable now on a proven
  mechanism (`AudioBridge.qml` already distinguishes active-capture stream
  nodes from device nodes via Pipewire). The camera half has no precedent
  anywhere in this codebase (nothing touches `/dev/video*`/v4l2) and would
  need a new, unverified detection scheme.

  **Answer:** yes, the permission system must be built. It should be
  generally restrictive, always asking permission the first time an app
  requires it (granted once, always, or never).

- yazi's folder colouring only distinguishes /mnt and /srv from $HOME
  (the two non-home locations this project actually uses today) — a
  general "anything outside $HOME" rule isn't portable in yazi's static
  theme.toml (no ~/$HOME expansion in its own path matching, and this
  repo's template renderer deliberately leaves $HOME untouched). If a real
  per-user $HOME path becomes available to templates some other way,
  extend `profiles/base/templates/.config/yazi/theme.toml.tmpl`'s
  `prepend_globs` to match generally instead of by fixed path.

## Ideas (not to be implemented, have to be discussed)

- LocalSend

- update centre + Applications folder

- Log viewer

- Customisations should be exportable in a single configuration file, as
  well as importable from the same file (with syntax check).

- Weather: add an extra special workspace dedicated to weather
  information using: https://github.com/ashuttl/linecast . It should
  probably use a multiplexer to show a single view with all panels, rather
  than separated. (Or all instances of linecast go to the special
  workspace, that does not allow other apps)

- a list of active ports and servers should be available both in the
  settings under connectivity as well as in the tailscale panel. Taking
  inspiration from this https://github.com/ZerubbabelT/portwatch

- vocabulary tool: add a definition tool that provides definitions for
  words and implement it natively in the runner bar. It can accept
  multiple languages; if the language is not the system language, it
  should show the translation (using the translate tool described below).
  Settings for the vocabulary should be added in the settings, where the
  user can add more languages that don't require translation for the
  definition (still show the translation of the word if not of the system
  language).

- translate tool: add a translate command that takes an input string and
  translates it, implemented in the runner bar. It should accept optional
  arguments for "from" and "to" language, otherwise the language is
  automatically detected and the "to" language is by default the system
  language. The case where the "from" language is the system language —
  the default translation behaviour should not be handled now (throws an
  error that must not block the runner). The runner bar should also have a
  custom layout for that result, showing the from and to translation and
  languages. (Translation and vocabulary tools can work together in the
  runner).

## Custom apps and services

- Notes app

- Cloud storage [server]

- Music indexing + download [server]

- Music client

- Movies/Series indexing + download [server]

- Jellyfin hidden library feature [server]: have the option to add
  storages for hidden content, which gets indexed (actors, categories,
  titles, tags) only to users that have access, only when toggled on
  (client side option)

- Jellyfin client

## Dotfiles improvements

- Better separation. See Open Questions #10.

- Cleanup + Optimisation

- Remove AI shenanigans. See Open Questions #11.

- place all phios locals in ~/.local/share/phios/{phi|dotfiles|phi-agent}.
  See Open Questions #12.

- Installer. See Open Questions #13.
