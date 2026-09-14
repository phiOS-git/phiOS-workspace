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
9. **Scrim/dim split:** what does "the scratchpad" dim refer to (nothing
   implements a scratchpad dim today), and is it acceptable for Clipboard
   to share whatever change is made to the Notifications panel's dim?
10. **Dotfiles "Better separation":** which part of the installer/profile
    split reads as poorly separated today?
11. **"Remove AI shenanigans":** which files/directories/artifacts,
    specifically?
12. **`~/.local/share/phios` relayout:** worth doing even though it can
    only be verified with a real reinstall — and should the installer
    auto-migrate an existing old-layout install?
13. **Installer:** what specifically is lacking about the current one?

## Bug Fixing / Improvements

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

- the ai agent a1 always fails starting: the broker binds correctly, but
  the chat panel reports the containment failed to start, and `phi agent
  code .` fails with a socat error connecting to the proxy socket. No code
  defect found by reading; the whole AI feature needs a real debugging
  pass on hardware (the UI also needs rework, see Style).
  *(full notes: `docs/investigations.md#ai-agent-a1-fails-to-start`)*

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

- alt+tab still does not work: it does not close when releasing alt, it
  does not start with the right window selected, it does not focus the
  selected window (neither with click, touch, enter, space or whatever),
  it does not change workspace. It's completely broken, the only part that
  works is calling it with the gesture. **Partially fixed 2026-09-14** as
  a side effect of a different investigation (see `VERIFICATION.md`,
  "Several window-management keybinds silently do nothing"): focusing the
  window and changing workspace are fixed (the dispatch calls were
  rejected by this Hyprland build's Lua config; switched to the Lua-call
  form). Still open: doesn't close on Alt release, doesn't start with the
  right window selected — a different mechanism, not yet investigated.

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

- many elements and options don't have basic UX features. This needs a
  full expert UI/UX pass. Concrete issues found so far:
  - chat panel has no settings button
  - wallpaper list has no "browse wallpaper folder"
  - most options don't have hover effects
  - cursor never changes state on clickable elements or fields
  - tabs are indistinguishable from buttons
  - some elements are clickable with no visible affordance (e.g. the
    bluetooth elements in the list)
  - lock screen has no "locked" state/timer after too many failed
    attempts, and no wrong-password visual feedback
  - no clear/clean button for searchbars
  - accordions don't differentiate the body, sometimes have the arrow icon
    and sometimes don't, and often don't align content with the title
    (should compensate for the arrow's width when present)
  - elements with the same behaviour don't share the same visual grammar
  - trigger buttons don't show loading states or result feedback; no
    skeleton loading anywhere
  - the settings panel needs its options better organised, grouped and
    ordered
  - the settings, chat and notification panels all use poor spacing/layout

  There are more issues than this list captures. Be critically honest
  about every feature and detail, and polish the system UI/UX to a
  coherent, optimal standard, focused on functionality. No element
  currently has a definitive style — everything can be reworked, but all
  elements must end up coherent, sharing the same grammar and styling
  options where possible. Map as many values as possible into the theme
  settings. `references/settings-layout-reference.PNG` is a reference
  layout to match the spirit of (generous spacing, sections clearly
  separated, an "advanced options" switch to simplify navigation, etc. —
  down to small details like the close button not aligning with the
  search bar/title).

- the status bar overlays (those that open with the status bar icons)
  should be reworked, as they don't fit the system style — overlaps the
  general UX entry above, left for that pass. They also have layout
  issues: the VPN row goes out of bound and is not aligned; it should show
  VPN and the toggle switch, then the list of configs to pick. The raw
  overflow looks very likely already fixed (VPN rows now use a widget
  built for exactly this, hardware-verified elsewhere) — worth a quick
  look to confirm before assuming it still reproduces. The restructure
  itself ("VPN + toggle, then a config list") is real, unbuilt work — see
  Open Questions #8.

- the settings-panel switch's color transition still looks like it
  finishes before the knob finishes sliding across. Investigated: no
  mismatched duration/easing found in `Toggle.qml` — every transition
  already shares the same motion tokens. Left undiagnosed rather than
  guess at a fix; a concrete diagnostic test is on file for next time this
  is looked at on real hardware.
  *(full notes: `docs/investigations.md#settings-switch-color-transition`)*

- the dim from the notification, chat panel and scratchpad should not
  overlay the status bar, while the dim from screenshot, overview
  (alt+tab) and warning/alert (eg. battery) should cover it. Have the 2
  types of dim have different intensity as well (the one that overlays
  should be stronger). Investigated: every dim surface today already
  covers the bar uniformly — no split exists in either direction yet.
  Battery alert, screenshot and alt-tab/overview are already correctly in
  the "covers" category, no change needed there. A second-intensity token
  would match an existing precedent (`PHI_BORDER`/`PHI_BORDER_STRONG`).
  See Open Questions #9.

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
