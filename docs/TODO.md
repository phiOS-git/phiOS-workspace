# TODOs

The user's backlog. An agent that starts on an entry prefixes it with
`[taken]`; when the change is committed the entry is removed from here and
written up in `VERIFICATION.md`. See `AGENTS.md` — *The TODO / VERIFICATION
loop*.

## Bug Fixing / Improvements

- on razer the trackpad does not work after hibernation

- network informations should not be exclusive to wifi, but for LAN as well. In the status bar, the network element (unified, see next task) should also have a specific icon (with states and animations as usual) for ethernet connection.

- tailscale/vpn and network overlay and status bar icon should be merged in a single element, showing network informations. It should display in the bar: the type of connection (LAN/WIFI), its status (enabled, disabled, wifi intensity, and an X on the LAN/WIFI icon if connected but without internet), and a VPN icon if active, tailscale icon if connected. The overlay pannel should have 2 states: compressed and expanded. It should show most of the relevant network informations and switches: type of connection, firewall, VPN, the network speed and ping visual, a list of active servers (grouped by source) with killswitches, and so on. All the advanced settings should be available in the settings panel, while most commont interactions should be available in this panel as well.

- after hibernation, the screen automatically suspend after 1 minute which is not the normal behavior (it should take longer) — investigated 2026-09-11: searched all of `phios-dotfiles` for anything that could set an idle-timeout/auto-lock/DPMS policy (`grep -rl "idle\|suspend\|hibernate\|sleep"`). Found only `profiles/laptop/system/etc/systemd/logind.conf.d/10-lid.conf` (`HandleLidSwitch`/`HandleSuspendKey` — LID CLOSE and the physical suspend key, unrelated to an idle *timeout*) and `hypridle` listed in `profiles/desktop/packages.txt` with an explicit comment that its config is "deferred" — **no `hypridle.conf` (or any other idle-timeout config) exists anywhere in this repository, committed or templated.** So this project sets no idle-timeout policy at all; the observed "suspends after 1 minute post-hibernation" cannot be something `phios-dotfiles` configures, since there's nothing here to misconfigure. Did not attempt a guess-based fix. Next time this happens, on the real machine (not from this repo): `systemctl --user status hypridle` (is it even running, and does `~/.config/hypr/hypridle.conf` exist there outside the repo — if hypridle IS running with some config, where did it come from), `loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}')` (an `IdleActionUSec` or similar systemd-logind-level timeout, separate from hypridle entirely), and specifically whether the 1-minute timer only starts counting fresh right after a hibernation *resume* (a session/idle-timer reset on wake, which would point at a resume-hook or systemd-logind interaction rather than a normal idle timeout misconfiguration) versus being the ordinary idle timeout just being reached faster than expected around the same time as a hibernation resume.

- windows management keybinding (move, resize) do not work *to be checked first

- the magnifier glass currently does not zoom in since the border where removed. It has to do with inconsistencies with the screen capture method. Needs to be solved. Reference this: https://github.com/Horizon0427/Glasscope — investigated 2026-09-11 (`phi-shell/Magnifier/Magnifier.qml`, `phi-shell/Services/Magnifier.qml`): the "since the border was removed" theory does NOT hold up under a close diff read, though the actual cause is still open — two competing candidates below, not confirmed either way. Pulled the exact commit that dropped the bezel (`8aacf2f`, "drop the magnifier bezel plate") and compared it line by line against the pan/zoom math: `ScreencopyView`'s `width`/`height` (`root.screen.width * root.zoom` / `* root.zoom` — this IS the zoom mechanism, an oversized capture panned under the lens) and its `x`/`y` pan offset (`root.lensSize / 2 - root.viewX * root.zoom`) are byte-for-byte IDENTICAL before and after that commit. The only things that commit changed are how the circular mask is drawn (an opaque hole-punched Canvas disc → a `QtQuick.Effects.MultiEffect` masking a `layer.enabled: true` Item) and the outer `lens` Item's own size (was `1.6× lensSize` "bezelD", now exactly `lensSize`) — the latter looked like a candidate at first (it changes the absolute screen position of the item tree) but the inner `feedClip` was correspondingly re-anchored (`anchors.centerIn` at a fixed `lensSize` size → `anchors.fill` on a now-`lensSize`-sized parent), and working through the actual pixel math by hand, `feedClip`'s absolute on-screen position and size come out identical in both versions.

  Two candidates, not one, and they predict different, checkably-different symptoms:
  1. **The mask/layer change broke rendering entirely.** `feedClip` has BOTH `visible: false` AND `layer.enabled: true`, with its rendered texture meant to be consumed by the sibling `MultiEffect`'s `source`. Tried to verify whether `visible: false` on a `layer.enabled` item still produces a live texture for another item's `source` — searched Qt's own `qtdeclarative` source for this and got zero results, so this is NOT confirmed either way, only recalled as a common pattern elsewhere. Worth flagging as actively suspect, not exonerated: `MultiEffect`'s own docs say it manages layering internally and doesn't need `layer.enabled` set on its source at all, so the explicit `layer.enabled` here is redundant at best — and pairing an unnecessary explicit layer with `visible: false` on both `feedClip` and the `lensMask` Rectangle is exactly the kind of combination that could plausibly stop content from rendering, not something ruled out. If this is the bug, the lens would show NOTHING inside the rim (transparent), not an unmagnified image.
  2. **`ScreencopyView` never honoured the explicit oversized `width`/`height` at all**, even before the bezel commit — i.e. this may be a pre-existing bug this commit gets blamed for only by timing coincidence. Already self-flagged as unverified in the file's own header comment, written when the ScreencopyView-based approach was first introduced (commit `0b4bb5b`): "whether ScreencopyView honours the explicit scaled size." If this is the bug, the lens would show real, SHARP, unmagnified (1:1) screen content — something is visibly there, it just never scales up with the zoom setting.

  Could not verify either theory without a compositor (`phi-shell/CLAUDE.md`: "You cannot run this"), and did not make a speculative code change to either the masking or the capture sizing without being able to see the result. Next time this happens: first ask (or check) the one question that discriminates the two candidates without needing any new screenshot — **is the lens currently showing nothing at all inside the rim (transparent), or is it showing real screen content that just isn't magnified?** Nothing/transparent points at candidate 1 (the mask/layer change); visible-but-unmagnified content points at candidate 2 (ScreencopyView ignoring the explicit size). If it's candidate 2, a further discriminating test: open the magnifier at a low zoom (1.5×) and a high zoom (6×) and screenshot both — if the content looks the same apparent size at both settings, that confirms ScreencopyView is ignoring the explicit size.

- the ai agent a1 always fails starting. Running `phi agent broker —instance a1` shows it binds it correctly on “127.0.0.1:8789” (after the second time it shows the address occupied). — investigated 2026-09-11: read `phi/internal/agent/broker.go` (bind/shutdown logic looks correct, no stale-socket handling gap for TCP), `phi/internal/cli/agent.go` (SIGINT/SIGTERM → graceful `srv.Shutdown`, looks correct), `phi-shell/Services/Agent.qml` (only ever issues one `systemctl start phi-agent-a1.service`, guarded against re-entrancy), and `phi-agent-broker@.service`/`phi-agent-a1.service` (no code bug found, but `Type=simple` with no readiness sync between the broker binding its socket and `phi-agent-a1.service` starting is a plausible source of a *different* failure mode — connection-refused, not the reported address-in-use). Could not find a concrete code defect, and did not want to guess at a fix to the credential-broker's systemd unit without being able to observe the actual failure — this needs the real machine. Running `ss -ltnp | grep 8789` and `systemctl --user status phi-agent-broker@a1.service` shows the service active and the server open: check ai-agent.output for the log. However the chat panel does not work "phi-agent-a1.service is not running, or the containment failed to start. Nothing runs outside the containment". Running `phi agent code .` opens the opencode session but it keeps showing an error "socat[64] E connect(, AF=1 \"run/phi-agent/net/proxy.sock\", 31): No such file or directory" and opencode does not work. opencode normally works. The entire AI feature must be debugged and corrected (and the UI must be changed, see in the styling section)

- area selection in screenshot, OCR and QR reading is never right. The offset changes as the size and position of the area change. — investigated 2026-09-11: all three modes (save/OCR/QR) already share ONE selection code path in `phi-shell/Screenshot/Screenshot.qml` (`onReleased` → `_captureGeometry` → `_doCaptureGeometry`, differing only in what runs on the resulting PNG afterwards — `tesseract`/`zbarimg`/clipboard-copy), so there's no separate bug surface between them; a fix to the shared geometry math fixes all three identically. That shared math already carries a prior hardware-verified fix (commit `df4298d`) for offset growing with the SELECTED AREA'S POSITION on a multi-monitor layout — confirmed against grim's own source (`github.com/emersion/grim`, `render.c`) that grim wants the `-g` box in logical (not physical/scaled) coordinates, which `root.screen.x/y + selectionRect.x/y` already is. Read the current formula carefully for a SEPARATE bug where offset grows with the selected area's SIZE (not position) specifically, since that's what this entry says and df4298d's own comment only discusses the position case: found no mechanism for it — x/y and width/height are computed and rounded completely independently in `onReleased`, so width/height cannot mathematically feed back into the reported x/y in the current code. Could not reproduce or measure on real hardware to find whatever mechanism does exist. Next time this happens: get exact numbers — the logical selection rect drawn on screen (x, y, width, height, and which monitor / its `scale`) vs. the actual crop `file --brief` or `identify` reports for the resulting PNG, ideally for one small and one large selection on the same monitor — so a real size-correlated formula (if one exists) can be isolated instead of guessed at.

- improve the neovim chroma integration, with as many mapping as possible. When I press a key only valid options in the keyboard should be backlit, with color codes to understand the nature of the command (eg. If I press “g” I should have the numbers in a color, the g in another color, and so on). Currently the colors change smoothly, in this integration it should be instant instead.

- ad settings specific for the “ambient effect”. Add more types to pick, taking inspirations by cool terminal effects or screensavers (always only played in the lock screen). Also add a live preview of the effect in the settings when one is selected

- super+shift+left/right and super+ctrl+left/right do not do anything (not workspace change, not window focus/move) — only bare super+left/right (focus change) works. Working alternatives exist (super+shift+h/j/k/l, super+ctrl+h/l — see VERIFICATION.md), but the arrow-key binds themselves are still broken. Root cause NOT found: four independent source-level checks against Hyprland's own code (`keybinds/Bind.cpp`'s `CBind::make`/modifier parsing, `keybinds/Resolver.cpp`'s keycode resolution, `config/lua/bindings/LuaBindingsToplevel.cpp`'s `hlBind`, and its `parseKeyString`/`CVarList2` tokenizer in `hyprutils`) found no defect — modifier names, key names ("left"/"right"), and bind-string tokenization/trimming all check out correctly for 3-token binds with word-name keys, so this isn't a config-file or Hyprland-core bug as far as static reading can tell. Next time this happens: run `hyprctl binds -j | grep -i left` on the affected machine (razer) — if the Super+Shift/Ctrl+Left/Right binds are ABSENT from that output, registration is failing at runtime for some reason not visible in source; if they're PRESENT with the expected modmask, the binds are registering fine and something else (an app stealing the shortcut, a modifier-detection quirk with this specific keyboard) is consuming the keypress before Hyprland's own matcher sees it. That single check discriminates between "config/registration bug" and "runtime/input-layer issue" and should be the starting point instead of re-deriving the source-level checks already done here.

- *Check for updates*: hyprland resize does not seem to work — investigated 2026-09-11: checked whether `hl.bind("left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"))` (and h/j/k/l/arrows siblings, `phios-dotfiles/profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`'s "resize" submap, entered via Super+R) has a shell-quoting bug — it's the only dispatch call in the file with a space inside an unquoted argument, unlike every other `hyprctl dispatch X Y` call which uses a single token. Confirmed NOT a bug: pulled `hyprctl`'s actual CLI parser (`hyprctl/src/main.cpp`, `main()`), which has an explicit exception for exactly this shape — an argument starting with `-` is only treated as a hyprctl flag if it does NOT parse as a number (the code's own comment: "For stuff like -2 or -2,"), so `-40` correctly falls through to the joined dispatcher request string instead of being misread as a flag. The submap's dispatch syntax is correct. Did not find another concrete defect in the submap definition (entry bind, four direction binds, three ways out via Escape/Return/catchall all look structurally sound) and could not reproduce or observe the actual failure without the real compositor. This entry and the "windows management keybinding (move, resize) do not work *to be checked first" entry look like the same underlying report — worth checking together. Next time this happens: confirm Super+R actually enters the submap at all (`hyprctl` has no direct "am I in a submap" query, but the cheat sheet / `hyprctl binds -j` can confirm the binds are registered), and try running the exact `hyprctl dispatch resizeactive -40 0` command directly in a terminal while the submap is NOT involved, to isolate submap-entry vs. dispatcher-execution as the failure point.


- opening a panel on a special workspase (11, 12), should automatiically open it in the highest possible panel up to 10

- when in full screen, the status bar does not appear by moving the cursor on the top edge

- when a window is set to floating (using the keybind) it cannot be resized

- the status bar overlays (those that open with the status bar icons) are still lower that they should be. This has been fixed many times but changes never worked. Clean up the whole feature and make it so that the overlay is few px below the bar. The gap variable is now of few px, clearly it's not an issue of gap, they probably have a fixed position or a wrong parent relative position or something like that.

- The network speed graph (settings + bar overlay) does not show real numbers: it's always around 1Kb/s both upload and download. Also make it visually match the reference more better: https://github.com/programmersd21/flow

- zsh in dark theme has the directory in black on black — investigated 2026-09-13: traced the whole pipeline end to end and found no defect anywhere in it. Built `phi` and ran the *real* renderer against the *real* dark tokens (`phi theme render --variant dark profiles/base/templates/.config/zsh/theme.zsh.tmpl`), which produces `PROMPT='%F{#d3a0ac}%n@%m%f %F{#d6d1c9}%~%f %# '` — `%~` (the directory) is `#d6d1c9`, `PHI_FG_0` dark, a light cream, never black in any commit of `design/tokens.dark.sh` (checked `ac8b04e`, `b97f3f4`, `08eb32d`). Fed that exact rendered `PROMPT=` line to a real zsh 5.9 and printed it (`print -P "$PROMPT"` piped through `cat -v`): it emits `\e[38;2;214;209;201m` for the directory segment, the correct 24-bit truecolor escape for `#d6d1c9`, not black. The Go substitution (`internal/theme/render.go`'s `variableRef`/`Substitute`, `internal/tokens/tokens.go`'s `tokenLine`) has no name-boundary bug — `PHI_FG_0`'s trailing digit matches fine, same code path as `PHI_ACCENT` which is not reported broken. No `LS_COLORS`/`dircolors`/`eza`/`zstyle list-colors` config exists anywhere in this repo (ruled out the completion-menu and `ls`-output surfaces entirely), no prompt framework (starship/oh-my-zsh/etc.) is installed, and `theme.zsh` is a real, declared `design/adapters.txt` row (class C, correctly sourced unconditionally from `.zshrc`).

  One genuinely new fact worth keeping: zsh's `%F{}` prompt escape is NOT forgiving of an empty argument — `%F{}` (empty color name) renders as literal ANSI black (`\e[30m`), while `%F{garbage}` (an unrecognized name) safely resets to default (`\e[39m`). So **only a wholesale-empty substitution produces black**, and this project's renderer is confirmed, by the real end-to-end test above, not to produce one for this template. This gives one sharp discriminating question for next time it happens: is the accent-coloured `%n@%m` segment ALSO black, or only `%~`? If both are black, something is stripping the whole `PROMPT` value at runtime (not this template); if only the directory is black, the rendered file on disk is not what this repo's renderer produces, and something downstream (stale `~/.config/zsh/theme.zsh` from before a token fix, or a `zsh/nearcolor` module loaded by an `/etc/zsh/zshenv` or `/etc/profile.d/` global rc outside this repo — `zmodload -L | grep nearcolor` on the affected machine turned this exact hex into `\e[39m` default-not-black in one quick test here, so it's a live but unconfirmed candidate) is overriding it. Next time this happens, on the real machine: `cat ~/.config/zsh/theme.zsh` (does the ON-DISK file actually hold `#d6d1c9`, or is it stale/truncated — this one check resolves most of the remaining uncertainty), `zmodload -L | grep nearcolor`, `echo $TERM`, and whether it reproduces outside kitty (e.g. in the Linux VT or over SSH from another machine).

- wifi speed graph does not show real values, it's stable at 1kb/s with 5kb/s peaks (it should be ~20Mb), both upload and download

- the scratchpad icon does not call the scratchpad nor it reacts to its activation, it's broken

- the power overlay buttons show no text and don't do anything on click — investigated 2026-09-13: read `Panels/BarPopout.qml`'s power section, `Widgets/SmallButton.qml` and `Services/PowerActions.qml` end to end; the label binding, the `TapHandler` → `clicked()` → `_requestPowerAction`/`_confirmPowerAction` chain, and `PowerActions.title()`/`perform()` all look correctly wired with no defect found by reading alone. Could not reproduce or observe the actual failure — needs a screenshot of what's actually on screen next time this happens, since the source doesn't show an obvious cause.

- the calendar overlay in the status bar shows a flip clock, it should have the real flip animation, not a slot

- the status bar icons can be touched with touch screen near their top border, triggering the hover effect but not the activation

- add customisation for sounds (battery sound)

- opening the notification panel, the agent panel, the settings panel or a bar popout (volume, wifi, bluetooth, etc.) doesn't close whichever of the others is already open — more than one can be visible at once. Only the calendar currently yields to (and is yielded to by) all four; none of the four do this for each other.

- h/j/k/l alternatives for the broken super+shift/ctrl+arrow binds stil don't work. none of those bindins change the workspace number . only usinf SUPER+number or clicking works. I need the keybind for changing workspace (and gesture, see later)

- alt+tab still does not work: it does not closes when releasing alt, it does not start with the right window selected, it does not focus the selected windom (neither with click, touch, enter, space or whatever), it does not change workspace. It's completely broken, the only part that works is calling it with the gesture

- [taken] the runner's ranking needs its full category order applied: apps, HOME files (non hidden or children of hidden folders), commands, phi commands, search any file, ask ai agent, search web, math, conversion. `internal/query/rank.go` only has six category tiers today (app/window/file/math-and-currency/action/websearch), math's tier sits above commands, ssh, zoxide and web search rather than below them, and the six tiers are deliberately spaced so no per-query match quality can ever promote a result across a tier boundary — a "perfect syntax match ranks higher across categories" rule needs an explicit cross-tier promotion, not a bigger in-tier score. There is also no "ask ai agent" launcher provider at all (`internal/agent` is not wired into `internal/query`), and only one, home-directory-only file-search provider exists, not the broader "search any file" category the order calls for — so multi-word queries have nothing to rank a wider file search below web search / ask-ai against yet.
- Add prefix feature to the runner bar: writing "web <anyting>" will automatically set the "search on web" first (but still perform the rest of the ranking). Make the same for: convert, math, ask (ask ai), file, app/run, phi (shows phi completion) and website specific like wiki/yt/arch/rddt. Add more if you can think of some very relevant one. Also if TAB is pressed after the prefix, the prefix will be "locked" visually as itgets background (like the highglighted option) and a "backspace" nerd icon next to it (clicking it removes it), it can also be cancelled but it requires a double click of backspace (to prevent removing it when holding down backspace). While a prefix word is selected, the only results shown will be determined by the prefix. More prefixes will be added with time, each should be configured with a color code (either a theme variable or a specific custom color), that color defines the highlight color when active and the runner bar will transition to that color for the borders when a prefix is active.
- phi prefixes in the runner bar don't seem to work (will be solved by applying the prefix feature above, any conflict must be removed in order for the prefix feature to work without issues)

- confirmation modals (like the one for power options) should be centered in the screen, with a dim and block the screen until they are resolved. Also make them a reusable component as other task (eg. the battery saving mode, see below) will use it.

## Features

- add in and out transition for the status bar, to be triggered on start, lock and unlock

- "theme auto" which changes automatically on evening time (automatic/manual time). Consider "phi theme set" restarts the qs and that cannot happen automatically, the change should be smooth and non destructive.

- add suspension/hibernation settings in the settings panel

- add a color picker

- three finger gestures on trackpad and touchscreen: up/down (open/closes overview, alredy workinf), left/right (change workspace). Add more if not too error-prone.

- add trash feature (package to be picked). Options (to be checked if they work as expected): CliFM (cli), ... * check the list on archlinux.org file manager

- system file picker required

- add a timer and alarm feature to phi, also add tools to the runner to quicky setup timers and alarms. They should have a custom overlay that requires to be turned off, on the higher Z index in the system. It should have a ringtone. The two features must be customisable in the settings.

- add option for automated night mode (automatic time at nighttime or manual hours range), with settings

- clicking on the wifi icon should show the list of available wifi to connect. Same in the settings.

- spotlight cursor: super+super (double tap hold) * blocked by issue on hyprland 0.56 *check if fixed*

- consideration: usare alt come super, così avrei 2 super invece che 2 alt. Da valutare con software che usano alt [TBD]

- add gestures to open the chat and notifications panel: 2 finger swipe from edge (touchpad) or swipe from screen edge (touchpad). Make the inverted gesture to close the panel as well. It should move progressively with the scroll, not only a toggable state.

- full screen alert should appear when battery level is low (2 thresholds warn and danger, configurable)

- sensible settings (eg. deleting the VPN config) should ask confirmation with a blocking alert (same fullscreen blocking alert/warning used by other systems)

- when pressing SUPER+L instead of locking immediatly, evoke an overlay menu with options (lock, suspend, hibernate, shutdown, reboot). Use a smart UI/UX grammar and hierarchy, add icons with hover animations. SUPER+L+L (double click) will instantly lock (same behavior as now).

- have a battery saving mode, it automatically kicks in when not in charge and lower then 20% battery (automation can be toggled in the settings, there will be an alert, see next task ), configurable in the settings panel. automatically disabled when plugged in and over the threshold (if the user activates while it's charging, it should not disable automatically, this flag is cleared once the charge is plugget off again). It must have visual feedback on the battery in the status bar and settings. The battery overlay (from the status bar) must have the switch.

- add an overlay for low battery level, with option to set on battery saving mode if not up yet (see previous task)

- there should always be at least 1 workspace (other then the special ones), also there should always be at lest an empty workspace (so if i ope)

- add a quick note: when clicking the bottom right corder a quick floating editor window appears, it persists (save it in a specific folder in Documents). Positioning the mouse in the corner should have show a small transition (inspired by macos corner note) * this can be built using the default editor, however an improved version might be provided by the note app

- i added references/default-phios-wallpaper-placeholder-light.jpg as a file that should be included in the phios repositories (dotfiles i think) for fresh installations. It should not be reapplied on updates, but it should be the selected one when first installing the system (apply a color invertion for the dark theme, not at runtime but generate an invertion of the provided image). Also set the default light and dark colors from the colors used in that image (rebuild the palette starting from those, also pick a better pink, inspired by all the references).

## Style

- many elements and options don't have basic UX features. a quick lists: chat panel has no settings button, wallpaer list has no "browse wallpaper folder", most options don't have hover effects, cursor never changes state on clickable elements or fields, tabs are indistinguishable from buttons, some elements are clickable without any feature (eg. the bluetooth elements in the list),  the lock screen has no "locked" state with timer after too many failed attempts, no wrong password visual feedback, no clean button for searchbars, accordions don't differentiate the body, accordions sometimes have the arrow icon sometimes they dont, often time the accordions don't align content with the title (when the arrow is present, they should compensate for it), many elements that have the same behavior don't have the same visual grammar, trigger buttons don't bring loading states or result feedbacks, there are no skeleton loading or loading in general, the settings panel should have options better organised, grouped and ordered in meaningful ways, the settings chat and notification pannels they all use terrible spacings and layout. There are many more issues that can be found, this task requires you to act as an expert UI/UX designer, being critically honest about each feature and every detail, and polish out the system UI/UX to optimal levels, focusing on functionality. No element in the current state has a definitive style, everything can be reworked, but all elements should be coherent and follow the same grammar, possibly using the same styling options. Also as many variable as possible should be mapped in the theme settings. I also added references/settings-layout-reference.PNG as a nice reference layout (see how options are displayed using the space, it's larger, sections are well spaced with separators, advanced options switch to make navigation easier, x button not aligned with the search bar, title, etc.).

- the status bar overlays (those that open with the status bar icons) should be reworked, as they don't fit the system style. They also have layout issues (the vpn goes out of bound and is not aligned, it should show VPN and the toggle switch, then the list of configs to pick)

- the settings-panel switch's color transition still looks like it finishes before the knob finishes sliding across

- the hyprland scratchpad should slde in from below, have slighlty more out spacing than other workspace and have a accent-colored border all around the screen. I think an old change made windows in the scratchpad had thiink borders, that has to be removed (i can't even see which one is focused) and restored to default, the border should be at the edge of the screen, like the whole workspace is bordered.

- the dim from the notification, chat panel and scratchpad should not overlay the status bar, while the dim from screenshot, overview (alt+tab) and warning/alert (eg. battery, to be introduced) should cover it. Have the 2 types of dim have different intensity as well (the one that overlays should be stronger)

- add status bar icons for active sensors (microphone, camera), the overlay should show a list of apps with the sensor they are using and killswitches. Also add settings for killswitches and permission rules

- terminal panels should have larger padding. reference to references/panel-reference-1.JPG and references/panel-reference-2.JPG

- yazi's folder colouring only distinguishes /mnt and /srv from $HOME (the two non-home locations this project actually uses today) — a general "anything outside $HOME" rule isn't portable in yazi's static theme.toml (no ~/$HOME expansion in its own path matching, and this repo's template renderer deliberately leaves $HOME untouched). If a real per-user $HOME path becomes available to templates some other way, extend profiles/base/templates/.config/yazi/theme.toml.tmpl's prepend_globs to match generally instead of by fixed path.

## Ideas (not to be implemented, have to be discussed)

- LocalSend

- update centre + Applications folder

- Log viewer

- Customisations should be exportable in a single configuration file, as well as importable from the same file (with syntax check).

- Weather: add an extra special workspace dedicated to weather informations using: https://github.com/ashuttl/linecast . It should probably use a multiplexer to show a single view with all panels, rather than separated. (Or all instances of linecast go to the special workspace, that does not allow other apps)

- a list of active ports and servers should be available both in the settings under connectivity as well as in the tailscale panel. Taking inspiration from this https://github.com/ZerubbabelT/portwatch

- vocabulary tool: add a definition tool that provides definitions for words and implement it natively I the runner bar. It can accept multiple languages, if the language is not the system language, it should show the translation (using the translate tool described below). Settings for the vocabulary should be added in the settings, where the user can add more languages that don’t require translation for the definition (still show the translation of the word if not of the system language)

- translate tool: add a translate command that takes an input string and translates it, implemented in the runner bar. It should accept optional arguments for “from” and “to” language, otherwise the language is automatically detected and the “to” language is by default the system language. The case the “from” language is the system language the default translation should return not be handled now (throws an error that must not block the runner). The runner bar should also have a custom layout for that result, showing the from and to translation and languages. (Translation and vocabulary tools can work together in the runner).


## Custom apps and services

- Notes app

- Cloud storage [server]

- Music indexing + download [server]

- Music client

- Movies/Series indexing + download [server]

- Jellyfin hidden library feature [server]: have the option to add storages for hidden content, which gets indexed (actors, categories, titles, tags) only to users that have access, only when toggled on (client side option)

- Jellyfin client

## Dotfiles improvements:

- Better separation

- Cleanup + Optimisation

- Remove AI shenanigans

- place all phios locals in ~/.local/share/phios/{phi|dotfiles|phi-agent}

- Installer
