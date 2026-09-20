phiOS backlog — features to add, fixes, directives and open questions.
Cross-references use `[#Section]` anchors.

# NextSteps

Ordered. Each entry is a pointer; the detail lives in its own section.

1. Consolidation — [#Consolidation]
2. AI agent rebuild — [#AiAgent]
3. Neovim — [#Neovim]
4. Bug fixing — [#KnownBugs]
5. Features — [#Server], [#Desktop], [#Extras], [#Additions]
6. Styling and keybinding coherency — [#StyleDirectives], [#Keybindings]

Outside the order: [#OpenQuestions] collects what is still undecided, and
[#Ideas] holds proposals to discuss before any of them is implemented.

[#ExternalPackages] is answered and in progress [WIP] — see
`docs/external-packages-plan.md`. It unblocks step 3 (plugin manager), step 2
(the agent replacement) and parts of step 5 (extra-packages manager, WiVRn).

# Consolidation

Reduce redundancy and settle where things live. No new features here.

## XDG layout

Adopt a single `phios/` umbrella across the XDG roots.

- `~/.config/phios/{phi,agent}/` — hand-authored and precious only: WireGuard
  configs, provider keys, `firewall.json`, `code-blocklist`.
- `~/.local/state/phios/` — derived and regenerable: the state manifest, agent
  sessions, and `dotfiles-root`.
- `~/.local/share/phios/` — agent data.
- `~/.cache/phios/`.
- `~/.cache/phi-packages` stays outside the umbrella: it is a build-host
  artifact of the packaging repository, not a runtime component.

Reasoning to preserve:

- The real defect is a misfiling, not the folder count. `bin/lib/env.sh`
  already documents `dotfiles-root` as "derived machine state, not repository
  content", yet it sits in the config bucket. Moving it is the fix; the
  umbrella rename rides along with it.
- The split that matters is precious vs. derived, not `phi` vs `phios`. A
  secret must never sit in a directory that tooling is entitled to regenerate.
- Create a subdirectory only when something needs it. Do not pre-create a
  `{phi,dotfiles,phi-agent}` taxonomy under `.local/share`; only the agent has
  content there today.

Migration — the installer should auto-migrate, with two hazards handled:

- `~/.config/phi-agent/a1/provider-key` is not repo-owned, so the installer's
  "remove a path that left the repository" pass orphans it silently. The
  failure surfaces much later as "No provider key configured". Move
  non-repo-owned files explicitly, first.
- `~/.zshenv` reads `dotfiles-root`, so a half-finished move leaves a login
  shell that cannot find the checkout. Write the new pointer before removing
  the old, and keep reading the old location as a fallback for one release.
- Touches three submodules: `phi` (path constants), `phi-shell`
  (`Services/AgentInfra.qml`, `Services/Agent.qml`), `phios-dotfiles`
  (`profiles/desktop/home/.config/phi-agent`, `bin/lib/env.sh`).

## phi scope

Do not split `phi`.

- `mathx` is not a command: no dispatch case in `internal/cli/cli.go`, absent
  from `internal/view`'s command table, imported as a library by
  `internal/query`. "Command or component script" is a false choice.
- Do not extract separate binaries. Each costs a PKGBUILD, a tag cadence, a
  signed release built by hand, and either duplicated or extracted
  `tokens`/`view` — for no gain at the CLI surface, since nothing there is
  user-visible today.
- Do not move logic into component scripts. A script gets no design tokens, no
  tests, and forks the moment a second caller appears.
- Placement rule for anything new: testable, stateful or policy-bearing goes in
  `phi`; presentation goes in the shell; a script is never the answer.
- Document that `phi` is deliberately two surfaces under one name — a
  user-facing CLI (`doctor`, `pkg`, `update`, `vpn`, `firewall`, `fan`) and the
  shell's stateless backend (`query`, `wallpaper`, `state`). `phi` is a fresh
  process per keystroke; the shell holds session state.
- The real reduction is scope, not packaging: delete `mathx`'s computer algebra
  (`solve.go`, `integrate.go`, `deriv.go`, `plot.go` — roughly 1200 LOC).
  Nothing exposes it, and a launcher calculator does not need symbolic
  integration.
- Leave `internal/query` alone. Its providers are a parse-and-rank layer with
  one thin stateless provider each, not fifteen features.

## Shell cleanup

- Rename Overview to AppSwitcher.
- Clean up Dialogs.
- Clean up Popout.
- Decide whether the wallpaper belongs as a background: Thunar's "set
  wallpaper" option does not work in the current arrangement.
- Improve wallpaper organisation: `/dynamic` is hardcoded to be skipped, which
  makes no sense.
- Optimise the system ticks and timers: night mode, dynamic wallpaper, timers,
  reminders and the rest.
- Clear the settings panel of useless settings — see [#OpenQuestions].

# AiAgent

Rebuild from scratch: a `pi` + `opencode` setup, keeping the option to plug in
other engines such as Claude Code.

- `opencode` is already a T0 package, so only `pi` is non-official. The
  rebuild is smaller than it reads.
- [WIP] `pi` is a test target of `docs/external-packages-plan.md`. Its
  distribution channel has to be confirmed before it can be tiered.

# Neovim

Two configurations over a shared core.

- Use `NVIM_APPNAME` to select between `nvim-ide` and `nvim-notes`. It is built
  into Neovim and needs no plugin.
- Keep the shared layer in a third directory, prepended to `runtimepath` by
  both configurations. Do not duplicate it.
- `theme.lua` stays a single adapter line in `design/adapters.txt`, rendering
  into the shared directory. Two adapter lines would mean two generated
  artifacts to keep in sync and would double the cost of every token change.
- `phi_chroma.lua` ("never edit this file") must reach both configurations
  through the same shared-runtimepath mechanism.
- Keep the current plugin-free `nvim` as a third, minimal configuration that
  always works — useful when a plugin manager breaks during an update.
- IDE: TBD.
- Notes: zettelkasten, image and other media render and drop, website render,
  grammar checking.
- Keybindings: TBD.
- Chroma integration needs a redesign. The transition is smooth today and
  should be instant, and it only expresses two states. It should describe far
  more: the valid keys with their commands, and colours that make the current
  mode readable — input, navigation, commands and so on. This needs advanced
  Neovim knowledge and has to integrate with both nvim-ide and nvim-notes.
- Spellchecking matters most here — see [#Additions].

[WIP] Plugin sourcing is a test target of `docs/external-packages-plan.md`.
`lazy.nvim` git-clones plugins at runtime, so it needs a tier. Check what Arch
ships in `extra` first — `:packadd` over T0 packages keeps the plugin-free
property intact and needs no exception at all. The notes configuration is the
one that will force the decision.

# ExternalPackages [WIP]

ANSWERED. The policy is rule 1 in `AGENTS.md`; the implementation plan is
`docs/external-packages-plan.md`. Everything below is settled — kept here
because other sections point at it.

- Official first. A candidate is pushed as high up the tier ladder as it will
  go: T0 official, T1 `[phi]`, T2 Flatpak, T3 contained, T4 bare, plus TC for
  rootless containers on the server.
- T0 and T1 are declared in `packages.txt` as usual; only TC, T2, T3 and T4 go
  in `external.txt`. `mini` carries one too, holding its containers.
- Anything permanent to phiOS goes in `[phi]` as a signed package rather than
  a language package manager. That is the single largest simplification.
- Everything non-T0 is declared in `profiles/*/external.txt` with a source, a
  pinned reference, a checksum where one applies, and a reason. Never "latest".
- `npm`, `pip`, `cargo` and `go` are project-local only. A global or user-wide
  install is a violation on every host, and their landing paths are asserted
  empty.
- The invariant becomes zero **undeclared** rather than zero foreign. Drift is
  reported in both directions, plus leak checks and checksum verification.
- Change detection is a polled fingerprint stored in the state manifest, with a
  re-baseline action. No watcher daemon — real tamper detection is a
  file-integrity tool's job and a separate decision.
- Containment reuses `phi-agent-contain`, generalised. bubblewrap is already a
  declared package and already the agent's containment mechanism, so T3 costs
  no new dependency. Whether a given target can actually run contained is
  answered per target, not assumed.
- `mini` stays T0 and rootless containers only.
- Nothing is implemented per ecosystem until a real need appears. The npm and
  Flatpak listers stay the placeholders they already are; the mechanism is what
  gets built.
- Monitoring and management need a visual, interactive surface in the settings
  panel, not only a CLI command. The existing Updates section's Packages group
  is the place. Its current read-only rule is narrowed rather than dropped: the
  panel may perform non-interactive, non-privileged actions, and still hands
  interactive privileged transactions to a terminal.

# Server

- Cloud file manager.
    - Sync.
    - Placeholder files on the client for offload, like `.icloud` files.
- Indexing for movies, series and music.
    - API to remotely add music to Navidrome, movies and series from sources,
      and videos from sources (YouTube, web video and audio — mostly public
      podcasts).
- Git remote manager APIs.
    - APIs to quickly generate new remotes from client machines.
- Calendar events and reminders. TBD what lives on the server and what stays
  local.
- Password manager sync (mirrored on clients). TBD to be discussed

# Desktop

- Media Fn keys.
- Colour picker — possibly a secondary mode of Magnifier.
- Launcher ranking: avoid deep `fd` results and system folders until they match
  strongly, or until the query is longer than a few letters.
- Gestures: add a two-finger edge swipe and four-finger inward and outward
  gestures, as on macOS.
- Sound feedback: more of it, and configurable. Battery-full currently sounds
  the same as connecting or disconnecting power, and plugging in and out are
  not differentiated. Which others are worth having is open — see
  [#OpenQuestions].
- Joining a secured Wi-Fi network from the shell needs a password path that
  keeps the secret off the process command line. `nmcli device wifi connect
  <ssid> password <pw>` puts the password on argv, readable through
  `/proc/<pid>/cmdline` by any local user, which is not acceptable. The
  argv-free mechanism (`passwd-file` via `nmcli connection up`) needs a prior
  `connection add` with the right `wifi-sec.*` fields per security type, and
  WPA-PSK, WPA3-SAE and WEP differ — not verifiable without real hardware.
  Already-known and open networks need no secret and already work; this is only
  the secured-and-not-yet-known case.
- Tiling: enable the placeholder feature in StatusPopout.
    - Replace the active status with triggers.
    - Retile every window in the workspace as selected, or make them floating.
    - Settled: of the six modes in the grid (X scroll, Y scroll, Tile, Centre,
      Fair, Floating) only Tile and Floating map to a real Hyprland dispatch.
      The other four exist only in third-party plugins (hy3, hyprscroller), and
      rule 1 stands — they stay visual-only with no backend. Nothing to do here
      unless that decision changes.
- Floating windows: need a wrapper or another way to move and resize. The
  design deliberately has no window bar (work is mostly tiled). See the
  draggable window wrapper in [#Additions] — the imv wrapper is a first,
  incomplete implementation.
- [WIP] Extra-packages manager for AppImage, repos, AUR, npm, Flathub and
  similar — see [#ExternalPackages] and `docs/external-packages-plan.md`. It is
  the settings-panel surface over the declaration and monitoring mechanism,
  not a second package manager.
- Add the `~/Cloud` folder.

# Extras

- [WIP] WiVRn. A test target of `docs/external-packages-plan.md`. Needs GPU
  and headset access, so whether it can run contained is answered there.
- LocalSend, handoff, shared clipboard.

# StyleDirectives

To discuss first: a complete overhaul of the style — how to improve it as a
whole while keeping coherence and avoiding unoriginal concepts.

## Widgets

- Select (dropdown) widget is missing. Use it for single-option items in the
  settings panel (for example sounds), and build it to allow multi-selection
  too.
- Switch:
    - On and off states should have the same opacity. Use different colours to
      make the state obvious; thumb and borders cannot change colour.
    - Opacity is reserved for the disabled state.
    - Remove the delay between the colour change and the thumb movement.
    - Add a hover transition on the thumb.
- Label element (add if missing): focuses its related switch or input on both
  hover and activation, and shows a pointer cursor. Integrate everywhere,
  keeping the current spacing.
- Button — TBD.
- Remove the informative text that fills the panels. Keep a status line only
  where an option or state genuinely needs explaining, and make it minimal and
  clear; much of it is obvious AI-work residue. Text that reports a TODO or a
  placeholder stays, but in a warn colour.
- Many informative elements, especially in settings and popouts, have a hover
  effect and pointer cursor but no click interaction.
- Do not add a setting when there is nothing to configure. Chroma's "power
  button range" is the example: the power button is a single key, and only that
  one should change colour for the battery.
- Roll `Widgets/ContextMenu.qml` out to more elements that would benefit from
  one. Clipboard entries (restore, pin, delete) and the empty-desktop
  right-click (run, terminal, files, browser, settings) use it so far.
  Candidates not yet wired: notification cards (per-entry delete, mute this
  app), the other overlay lists, and settings rows whose reset action is buried
  behind a small button. Each site needs its own judgment on which actions
  belong in the menu rather than staying a visible control — not a mechanical
  copy of an existing menu's rows.

## Status bar and popouts

- Line separators in status bars should use the full colour rather than a
  shade, and be taller.
- Unify the hover and active states across every status bar item. Workspaces
  are the only exception, with their width change; nothing else changes size.
- Add right-click actions to the status bar items: night mode on the display
  icon, DND on the notification icon, mute on the sound icon, low power mode on
  the battery icon.
- Stats popout:
    - Move disk usage into the usage section.
    - Temperature should use dotted bars, with CPU and GPU inverted in
      direction (see btop).
    - Only one mounted disk is shown — see [#KnownBugs].
- Speedtest element should use bars (btop dotted bars).
- NetworkPopout:
    - The speedtest graph should be visible on Ethernet too, as long as there
      is an internet connection.
    - Use dotted bar graphs, not lines (see btop).
- Notification popout:
    - Group by time range first, then by source.
    - Clicking opens the source and deletes the notification.
- Notification toast:
    - An x button to close.
    - Clicking clears it and opens the source.
    - A two-finger swipe closes it.
    - Animation: the icon first, then the text with expansion, with in and out
      animations and configurable on-screen timing.
- System modal: rework.
- Scratchpad should slide in and out from the bottom.
- AppSwitcher:
    - The selection is indistinguishable.
    - Workspaces should be larger, have a background, show a clear selection
      state, and list their windows as small icons.
    - Windows should be — TBD; consider changing or adding macOS overview
      behaviour.

## Runner bar

- Add colour and glyph properties to tags — the words that activate a custom
  ranking, such as `app`, `file`, `ask`, `web`, `phi`, `run`, `yt`, `wiki`,
  `arch`. When a tag is activated:
    - The tag in the runner is highlighted with its colour.
    - The runner bar transitions to that colour.
    - The phi glyph changes, with a transition.
    - Deleting stops before the tag. Removing it takes a double backspace, or a
      first press that selects it.
- Runner bar text can overflow. It stays on one line normally, but with the
  `ask` tag active the field extends vertically while typing to fit the
  content, with vertical scrolling past a limit.

## Applications

- Terminal: add a "header" and autocompletion.
- Thunar: customisations do not work.
- Librefox: https://www.reddit.com/r/unixporn/comments/1dl1xzx/oc_shyfox_theme_for_firefox_i_made/
- Plymouth and TTY.
- fastfetch:
    - Redesign coherently — fewer penguins, more phi.
    - Avoid wrapping, or make sure it fits the smaller terminals.
    - Apply the phi ASCII mark with colours.

## Lock screen and screensavers

- Lock screen:
    - Reference: https://unixporn-dots.github.io/assets/dotfiles/rklyz_dotfiles/thumbnail.png
    - Pre-input state: mouse or keyboard input enables the password field.
    - Improve validation animations.
    - Improve the lock and unlock transition.
    - Improve the screensave effects.
- Screensavers:
    - Lava lamp: complete rework. The current one is entirely wrong and must be
      deleted. Reference: https://github.com/AngelJumbo/lavat
    - Improve the customisable properties of the existing screensavers.

## Icons and motion

- Icons rework: replace the whole set with better hand-picked icons. It must be
  coherent, and has to be discussed first.
- Animated transitions for the important multi-state icons: DND, volume change
  and toggle, brightness, night mode toggle, Bluetooth toggle, VPN and firewall
  animating in and out.
- Add spawn animations for launch and unlock.

## Colour

- Infatuation colour code.

# Keybindings

- Decide the general Fn usage.
- CursorSpotlight should trigger on SUPER+SUPER held, and disable on SUPER
  release.
- Move the status popup keybindings to Fn (nice to have):
    - status: `fn+s`
    - clipboard: `fn+v`
    - notifications: `fn+n`
    - phi agent: `fn+p`
    - and so on.

# KnownBugs

- Magnifier zooms on a static image of the screen; it should work at runtime.
  If that is not achievable in Quickshell, other options can be considered. The
  result should be as close as possible to https://github.com/Horizon0427/Glasscope
- CursorSpotlight:
    - Dim mode is performance-heavy and laggy.
    - Flashlight shows lit bottom and right borders of the square at medium and
      small sizes.
    - Crosshair lines are not always visible (black on dark); it should check
      the background at each position.
    - Ring should animate a circle shrinking to the cursor, not repeating.
- Hibernation freezes the screen, then spins the fans to maximum, then turns
  off. The freeze can last 30 seconds. Sometimes it blanks the screen, turns it
  on again frozen, then finally hibernates. Fix the broken behaviour and add a
  loading state to hide it — which can become a shell item for other uses.
- After hibernating the laptop, the touchpad does not always come back; the
  touchscreen always does.
- MediaControls:
    - The title marquee does not move slowly — it jumps and sticks at the end.
    - The title is shown twice (title, then author and title). The second row
      should show author and album.
- Hovering a tab should allow scrolling in it without focus.
- The stats popout only shows one mounted disk.
- System modal:
    - The touchscreen does not work.
    - Tab should cycle, enter and space should select.
- `phi theme set dark` should ask for confirmation when "Automatic" is set,
  and disable Auto mode if confirmed.
- NotificationPopout:
    - Clearing notifications still does not remove them visually.
    - Remove the confirmation dialog when clearing notifications.
    - The toast seems to appear only on the first notification of a session —
      the pattern is unclear, but it is definitely not every notification.
- AppSwitcher (renamed from Overview):
    - The clickable area is only the icon.
    - Releasing the alt key should trigger the selection.
    - Changing workspace with a three-finger swipe should update the
      AppSwitcher's selected workspace and window, following system focus.
- SpeedTest returns unreliable values. It should measure internet speed, not
  local speed, and should not be capped.
- Dynamic Wallpaper has no transition on change.
- ClipboardPopout: the right-click context menu shows an empty, unselectable
  padding-only square. It should offer delete, copy, and pin/unpin.
- `WindowList.qml`: the selected state is unrecognisable — it has no hover and
  no visible background — and the other entries do not change focus.
- Night mode set to automatic turns itself back on at every minute check
  whenever the time condition is met, even after being disabled by hand. A
  manual disable should hold until the end of the schedule. Battery saving mode
  has the same problem.
- After hibernation, the screen suspends again about a minute after waking,
  which is far too soon. A restart is needed to restore normal suspend
  behaviour.
- Chroma:
    - Single key does not work.
    - Notification integration does not work.
    - Power integration does not work, and it blocks every chroma feature in an
      error loop — even the static colour changes stop responding.
- In fullscreen the status bar does not appear when the cursor moves to the top
  or bottom edge.
- The scratchpad icon in the top status bar has no active state.

# Additions

- Smooth scrolling with the touchpad in the shells. Touchscreen and mouse drag
  already behave that way. Leave the scroll wheel as it is, with a comment —
  how to handle it will be decided in time.
- Interactive index panel for the settings panel: appears on the right with
  some spacing, aligned to the top of the content body, showing the mapped
  inner sections.
    - The active section has a highlighter effect; inactive ones have a hover
      opacity effect.
    - They follow the scroll position automatically and can be clicked to
      activate and scroll to position.
    - It must work with the existing search bar.
    - Make it easy to configure which panels have it, and normalise how
      sections are mapped. Only Theme, Connectivity and Devices use it today.
- Draggable window wrapper for floating windows — currently used as an imv
  wrapper, usable for general floating windows or other processes.
    - Small padding left, top and right.
    - Header at the bottom: app title, a draggable area with a grab cursor, and
      extra content passed as a property.
- Quick Note feature:
    - HotCorner shell item: can be set at anchors and has a callback. The quick
      note corner sits at the bottom right of the screen, regardless of the
      status bar.
    - On hover it shows a small expanding square to hint the interaction.
    - It is invisible until hovered — 0px, or 1px if 0 does not work.
    - On activation it opens the latest file in `phios/quick_notes/` in
      nvim-notes.
    - The view is wrapped in the draggable floating window, with a "new" button
      and a note selector in the header.
    - New notes are named `timestamp_customName`, where customName is the first
      line or word.
- Music client:
    - Set up with Navidrome if possible: https://rmpc.mierak.dev — otherwise
      something similar.
    - Lyrics — probably needs server-side work too.
    - A built-in way to add music to the library, triggering the server
      indexer.
- Media centre client:
    - TUI or GUI.
    - Hidden library switch: swaps the UI completely between the public and
      hidden libraries, changing visible content, search history, suggestions,
      categories, actors and so on. Requires a password.
    - An interface to interact with the indexers.
    - Video and audio download from source — a GUI over the API.
- Spellchecking, for normal use (browser and the rest) and above all for
  nvim-notes. It should be possible to disable it by hand from the status bar.
  Whether it is worth running a central service on the server is open.
- App-permission detection and enforcement backend. `Services/SensorPermissions.qml`
  and its UI — bar icons, overlays, the settings group, the three-choice prompt
  — are built and real, but nothing populates `activeUsers`, so the prompt
  never appears on its own. It needs a reactive detect-then-kill design: no
  OS-level prior-restraint mechanism exists on a non-sandboxed desktop, so this
  is not the same shape as Flatpak or portal permissions. Microphone detection
  goes through Pipewire capture-stream nodes, where `AudioBridge.qml`'s
  existing `micInUse` mechanism is the proven starting point; camera detection
  means scanning `/proc/*/fd` for open `/dev/video*` handles, with no precedent
  anywhere in this codebase. Also needs a decision on where `rules` and
  `activeUsers` persist across restarts — they are session-only today.
- Calendar: events, TODOs and reminders.
    - Add to the calendar popout.
    - Notifications.
    - Runner implementation.
    - AI agent implementation.
    - Server sync — mostly useful if synced with the phone, otherwise of
      limited value for now.

## RequiredSettings

- Option to invert the scrolling direction, without interfering with the
  touchscreen.
- User information:
    - Editable fields only where they are safe to change.
    - User image.
    - Password change, using the system dialogue with animated live validation.
- Buttons to quickly open config files and folders.
- A file picker for wallpapers, the user image and anything similar.

## NiceToHave

- Settings and theme profiles: home, work, school.
- Weather app: either use https://github.com/ashuttl/linecast or clone its
  forecast logic for the week, the day, and rain percentage over the map. Moon,
  sunshine and sky are not needed but would be nice.
- New screensaver: a weather-based terminal, using the weather app backend.
  Storm example: https://github.com/rmaake1/terminal-rain-lightning
- Hide the cursor while typing in a terminal or in nvim, restoring it on input,
  to avoid misclicks on the touchpad — but allow the touchscreen.

# OpenQuestions

Still undecided. Answer here, or on the entry the question points at.

- Prowlarr stack on `mini` — rootless containers, greenfield, no
  `profiles/server/packages.txt` exists yet. [WIP] as a test target of
  `docs/external-packages-plan.md`; what the stack contains is still open.
- Should empty workspaces shift automatically, so they are always in order?
- Which sound feedbacks are actually worth adding, beyond differentiating
  battery-full from connecting and disconnecting power? See [#Desktop].
- Which settings in the settings panel are useless and should be removed?

# Ideas

Not to be implemented. To be discussed first.

- Log viewer.
- Customisations exportable to a single configuration file and importable from
  the same file, with a syntax check.
- A list of active ports and servers, available both in the settings under
  connectivity and in the Tailscale panel. Inspiration:
  https://github.com/ZerubbabelT/portwatch
- Vocabulary tool: a definition tool implemented natively in the runner bar. It
  accepts multiple languages; when the language is not the system language it
  also shows the translation, using the translate tool below. Settings let the
  user add languages that need no translation for the definition — the word
  itself is still translated when it is not in the system language.
- Translate tool: a translate command in the runner bar that takes an input
  string and translates it. Optional "from" and "to" arguments; otherwise the
  source language is detected and the target defaults to the system language.
  The case where "from" is the system language is out of scope for now and
  should raise an error that does not block the runner. The runner bar needs a
  custom layout for the result, showing both sides of the translation and their
  languages. The vocabulary and translate tools can work together in the runner.
