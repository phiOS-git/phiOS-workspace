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

- Clean up Dialogs.
- Clean up Popout.
- Decide whether the wallpaper belongs as a background: Thunar's "set
  wallpaper" option does not work in the current arrangement.
- Improve wallpaper organisation: `/dynamic` is hardcoded to be skipped, which
  makes no sense.
- Optimise the system ticks and timers: night mode, dynamic wallpaper, timers,
  reminders and the rest.
- Clear the settings panel of useless settings — see [#OpenQuestions].

# AiAgent [TBD]

Rebuild from scratch: a `pi` + `opencode` setup, keeping the option to plug in
other engines such as Claude Code.

- `opencode` is already a T0 package, so only `pi` is non-official. The
  rebuild is smaller than it reads.
- [WIP] `pi` is a test target of `docs/external-packages-plan.md`. Its
  distribution channel has to be confirmed before it can be tiered.

# Neovim [TBD]

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

- Colour picker — possibly a secondary mode of Magnifier.
- Gestures (touchpad): add a two-finger edge swipe and four-finger inward and outward
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

- Fullscreen: when a window goes fullscreen, it should get its own workspace, inserted at the index position between its starting workspace and the next one (shifting all the others).
    - When the fullscreen is disabled, it should return to the starting workspace index
    - the StatusBar in Workspaces.qml shouls show the icon of the window next to the number when it's dedicated to a fullscreen window

# Extras

- [WIP] WiVRn. A test target of `docs/external-packages-plan.md`. Needs GPU
  and headset access, so whether it can run contained is answered there.

- LocalSend, handoff, shared clipboard. [TBD]

# StyleDirectives

To discuss first: a complete overhaul of the style — how to improve it as a
whole while keeping coherence and avoiding unoriginal concepts.

## Widgets
## Status bar and popouts
## Runner bar

## Applications

- Terminal: add a "header" and autocompletion.

- Thunar: customisations do not work. While the theme colors are applied, none of the other style rules are used. The GUI should be coherent with the rest of the system, and it should also improve the overall feel of the thunar GUI to a modern file manager GUI. I provided some references: `references/filemanager1.jpg` (this is the best example), `references/filemanager2.webp`, `references/filemanager3.jpeg`, `references/filemanager4.png`. Here are some features i want
    - remove the text-based status bar, all menus should still be available
    - view icons: icons to change the view style, like on macos
    - split view icon
    - color-based separation between the side bar and the body
    - great use of colors and icons for folder and file types, prefering outlines over filled icons
    - visually distinct separation for sections in the sidebar (see the reference 1, it has logic order, separation, diifferent icon usage, etc: for example the trash is separated from quick directories, syste directories are separated from bookmarks, devices are on top and visually distinct (with even extra informations), etc.)
    - features should have transitions, hover and active states, etc.
    - selection in the sidebar is blue while selection in the body uses the accent. (see the section #Colour to see how different shades of the accent should be used)

- Librefox: it should be way more modern, taking strong inspiration from Arc or Zen browsers. This is a great exammple: https://github.com/Naezr/ShyFox ( https://www.reddit.com/r/unixporn/comments/1dl1xzx/oc_shyfox_theme_for_firefox_i_made/ ). I want:
    - sidebar
    - transitions
    - all GUI elements disappear to provide a larger area for the actual browsing
    - *TBD many features: spit view

- Plymouth and TTY * TBD: i want to improve them, not sure how yet

## Lock screen and screensavers

- Lock screen:
    - Improve validation animations.
        - specifically the plasma effect currently has some diagonal lines appearing for all effects, that should be completely removed, instead the blobs should have a "ripple" effect and use strong color change for errors and such
    - Improve the lock and unlock transition.
    - Improve the screensave effects.

## Icons and motion

- Icons rework: replace the whole set with better hand-picked icons.
    - TUI / Tech style with elegant feel, no "fun" or "pop" icon. A great source is https://iconoir.com
    - avoid common-looking icons
    - prefer elegant/detailed icons
    - The sun/moon for brightness should have a sun and fool moon (with craters) icons
    - icons in panels should use outline style rather then filled style, icons in the status bar instead prefer filled icons
    - the wifi icon is horrible
    - icons often seem to have different sizes due to how they occupy their box, this is where coherence is essential, icons from different packages should be carefully handpicked while using icons from the same pack is encouraged

## Colour

- Infatuation colour code. You can check the `references/infatuation-color-theme.json` which is a vsc theme that uses pink shades exactly the way i'd like to see, however black shades are not great in that reference (i want to keep the "monochrome" effect in phiOS).

# Keybindings

- Move the status popup keybindings to Fn (nice to have): TBD as FN keys are not allowed currently
    - status: `fn+s`
    - clipboard: `fn+v`
    - notifications: `fn+n`
    - phi agent: `fn+p`
    - and so on.

# KnownBugs

- TTY logo repeats in few seconds from startup. Probably agetty reprinting on network events.

- The Magnifier zooms on a static "screenshott", it should work at runtime instead. If that is not achievable in Quickshell, other options can be considered. The result should be as close as possible to https://github.com/Horizon0427/Glasscope

- CursorSpotlight:
    - Dim mode is performance-heavy and laggy.

- NotificationPopout:
    - Clearing notifications still does not remove them visually from the NotificationPopout.


- CursorSpotlight
    - currently the double click of SUPER perfectly works, however if i press any other key before releasing the second click (SUPER PRESS -> RELEASE -> SUPER PRESS -> "A" PRESS -> SUPER RELEASE, it does not matter if i release "A" or SUPER before), the spotlight stays on when i release the SUPER key. It only works if nothing gets pressed while the key is down. Having the spotlight on does not stop any other input and any release of the SUPER key is eligible to stop the spotlight.

- Notification Toast:
    - they don't stack, newer notifications are not shown if an older one is still showing. TBD: should have a limit and stack OR jsut show the latest?

- Context menu:
    - when the context menu is open, clicking on other shells do not closes it. Not only on interaction areas, clicking the status bar for example should close it: basically any input that's not on the context menu always closes it (withtout stopping that input propagation)

- Thunar: many default behaviours seem to require configuration like those examples, configure them:
    - imv: opening an image from thunar (or other third party software) does not use the imv wrapper and so the window closes as soon as any input (even mouse movement) is triggered.
    - terminal: running "Open terminal window here" in thunar fails with: `Failed to launch preferred application for category "Terminal emulator"`

## Hibernation

- it freezes the screen, then spins the fans to maximum, then turns off. The freeze can last up to 30 seconds. Sometimes the screen turns off, then on again frozen, then finally hibernates. Fix the broken behaviour, you can add a loading state to hide it — which can become a shell item for other uses.
- After hibernating the laptop, the touchpad does not always come back; the touchscreen always work instead.
- After hibernation, the screen suspends after about 30 seconds of inactivity, which is far too soon. A restart is required to restore normal suspend behaviour.

- The network graph shows unreliable values. It must measure internet speed, and must not be capped. Generally it seems that it's not really having a continuos speedtest and overall it has many concerning issues both of fake looking informations and it's unstable:
    - after some time it measure correctly, then it goes back to 1Kb/s (might be due to the timings of speedtest-cli, but the graph should never show false data)

## AppSwitcher

- [NOT_WORKING] Releasing the alt key should trigger the selection, currently it does not (only pressing enter or clicking triggers the selected item).
- [NOT_WORKING]: neither Alt release nor Enter selects; only a click does.
- [NOT_WORKING] Changing workspace with a three-finger swipe works, however it's not possible to swipe to change workspace while ALT is held down. 3 finger swipe fails while Alt is held; likely the keybinding, not the gesture.

## Chroma

- Single key does not work.
    - the "editor" does not show (and the logic does not work either)
- Notification integration does not work.
- Power integration does not work, and it blocks every chroma feature in an error loop — even the static colour changes stop responding.
- nvim integration should have instant transition, instead it eases

## Settings:

- Remove the file picker for new wallpapers (they automatically read the wallpaper folder)
    - currently if the theme section is open it's required to close it and reopen it to refresh the wallpaper list
    - dynamic wallaper loading show a black element, instead it should show a state (loading and failed as well)
- there are no options for the user profile image and other user's informations:
    - Editable fields only where they are safe to change.
    - User image (with a file picker)
    - Password change, using a custom system dialogue with animated live validation.

    - Option to invert the scrolling direction (only for the touchpad / mouse, not the touchscreen)

    - Buttons/links to quickly open config files and folders in the system file manager
        - also add a section with a list of all configurable softwares to quickly edit the right file/open the directory

- the panel sometimes takes a long time loading (especially the theme section, which can even turn on the fans as it's way too heavy). It correctly shows the skeleton loading but might take too long. loadings can be applied to singe sections and specific for the heavier items like previews. Lazy loading can improve the performances as well.

- the index should appear on the side of the settings panel with some spacing, without taking out space from the body of the settings panel

- the indexes can group items better (eg. wallpapers has 3 consecutive sections that can be grouped in the index as "wallpaper")

- Many options should be removed, both visually and in the logic. Chroma's "power button range" is the main example: the power button is a single key, and only that one should change colour for the battery, so having extra options makes no sense. Many other options seem to be there just to "fill space". i want an advance study on the current settings panel (as in the previous point)

- many options should be aligned better or change layout: * THOSE ARE INDICATIONS, A WIDE AND DETAILED STUDY ON THE CURRENT LAYOUT SHOULD BE MADE TO OPTIMISE USABILITY AND NAVIGATION AT ITS BEST. WHAT I REQUIRE IS A FULL STUDY THAT SHOULD RESULT IN A LOT MORE TASKS TO IMPROVE THE UI/UX AND PERFORMANCES
    - Theme should have options "dark", "light", "automatic" on the same line. Only if automatic is selected editor schedule hour is shown with a toggle "use custom hours" and the 2 time input can stay on the same line. the "Automatic window" text can be completely removed
    - The colour preview can be removed
    - Colours can be grouped in the index and can be layed out better. The accent color should be the main option (as it's the one that will get changed more often, those are the type of UI/UX reasoning i require in decisions for the settings layout design)
    - the "edited" state should be signaled with a dot next to the option title
    - the "wallpaper base" section should show only when it's actually active, and it can be part of the wallpaper macro-section
    - static and dynamic wallapers should be grouped, separated by titles, this way all other fields and option for the wallpaper can appear after the wallapeper gallery (dynamic wallpaper options visible only when active)
    - in the many sections the "reset" button has a whole line instead of being in the header (spaced from the title to the right side)
    - the typography section uses space terribly, especially the previews do not need their whole line, they can have multiple lines to fit in less width and align to a more compact selection of the fonts
    - "shape & spacing", "animations", "clock", "lock screen", "cursor spotlight", "screen magnifier" (and many other sections in the whole panel) all have the same probles regarding having a full line per option, when they could easily lay them out well and with context on less lines, using space and alignment better
    - large elements can be aligned to multiple row of options. For example the transition preview and editor can be aligned horizontally with all the 4 following options on the right, occupying 50% width and 4 rows of height (and even have the preview and text bazier below the editor to align everything better, considering those elements require more width then height)
    - the "hide preview" button is not in the header, like "resets" button this makes no sense
    - the screensaver shoud use a select to optimise space
    - the screensaver preview shouldn't be a section by itself, it's part of the screensaver (the same should be applied to many sections, that are separated for no apparent reason)
    - "per app rules" does not align entries and flags buttons
    - there is a "chroma" section for notification that takes so much space for a single switch. (even if the feature is separated, the settings panel should group and order everyhting coherently, with optionals for settings that are not always available)
    - the "ringtone" section aligns select and message on multiple lines for no reason, with volume and test taking up space as well. Why is there even a label "Test" for the verbose button "Test ringtone"? Just set a button and don't take up a whole line. there are many such cases
    - etc. A CASE STUDY MUST BE MADE TO DEFINE HOW TO PERFECTLY IMPROVE THE LAYOUT

# Additions

- Smooth scrolling with the touchpad in the shells. Touchscreen and mouse drag
  already behave that way. Leave the scroll wheel as it is, with a comment —
  how to handle it will be decided in time.

- Touchscreen gesture: add some gesture with the touchscreen:
    - 3-fingers left/right swipe: change workspace
    - 3-fingers top/down swipe: open/close AppSwitcher
    - 4-finger inward: same as in touchpad, etc.
    - generally, all gestures applied to the touchpad should work on the touchscree as well
    - the MX Master should map the "gesture" to the thumb key, allowing to change workspace and open the overview by pressing it and sliding the mouse

- Spellchecking [TBD], for normal use (browser and the rest) and above all for nvim-notes. It should be possible to disable it by hand from the status bar. Whether it is worth running a central service on the server is open.
  
- App-permission detection and enforcement backend. `Services/SensorPermissions.qml` and its UI — bar icons, overlays, the settings group, the three-choice prompt — are built and real, but nothing populates `activeUsers`, so the prompt never appears on its own. It needs a reactive detect-then-kill design: no OS-level prior-restraint mechanism exists on a non-sandboxed desktop, so this is not the same shape as Flatpak or portal permissions. Microphone detection goes through Pipewire capture-stream nodes, where `AudioBridge.qml`'s existing `micInUse` mechanism is the proven starting point; camera detection means scanning `/proc/*/fd` for open `/dev/video*` handles, with no precedent anywhere in this codebase. Also needs a decision on where `rules` and `activeUsers` persist across restarts — they are session-only today.

## Quick Note

- HotCorner shell item: can be set at anchors and has a callback. The quick note corner sits at the bottom right of the screen, regardless of the status bar.
- On hover it shows a small expanding square to hint the interaction.
- It is invisible until hovered — 0px, or 1px if 0 does not work.
- On activation it opens the latest file in `phios/quick_notes/` in nvim-notes.
- The view is wrapped in the draggable floating window, with a "new" button and a note selector in the header.
- New notes are named `timestamp_customName`, where customName is the first line or word.

## Music Client [TBD]
- Set up with Navidrome if possible: https://rmpc.mierak.dev — otherwise something similar.
- Lyrics — probably needs server-side work too.
- A built-in way to add music to the library, triggering the server
    indexer.

## Media centre client [TBD]
- TUI or GUI.
- Hidden library switch: swaps the UI completely between the public and hidden libraries, changing visible content, search history, suggestions, categories, actors and so on. Requires a password.
- An interface to interact with the indexers.
- Video and audio download from source — a GUI over the API.


## Calendar: events, TODOs and reminders. [TBD]
- Add to the calendar popout.
- Notifications.
- Runner implementation.
- AI agent implementation.
- Server sync — mostly useful if synced with the phone, otherwise of
limited value for now.

## NiceToHave [TBD]

- Settings and theme profiles: home, work, school.

- Weather app: either use https://github.com/ashuttl/linecast or clone its forecast logic for the week, the day, and rain percentage over the map. Moon, sunshine and sky are not needed but would be nice.

- New screensaver: a weather-based terminal, using the weather app backend. Storm example: https://github.com/rmaake1/terminal-rain-lightning (password verification in all states should have coherent reactions)

- Hide the cursor while typing in a terminal or in nvim, restoring it on input, to avoid misclicks on the touchpad — but allow the touchscreen.

# OpenQuestions

Still undecided. Answer here, or on the entry the question points at.

- Prowlarr stack on `mini` — rootless containers, greenfield, no
  `profiles/server/packages.txt` exists yet. [WIP] as a test target of
  `docs/external-packages-plan.md`; what the stack contains is still open.

- Should empty workspaces shift automatically, so they are always in order?
    - Answer: yes, this should also be working with the fullscreen behavior described in [Desktop]

- Which sound feedbacks are actually worth adding, beyond differentiating battery-full from connecting and disconnecting power? See [#Desktop]. 
    - Answer: taking a screenshot, adding an element to the clipboard history, startup, shutdown, input detection, etc. All those are possible sounds. You should make your own consideration on what makes sense that has a sound feedback, and have them all singularly switchable and configurable.

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
