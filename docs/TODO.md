# TODOs

The user's backlog. An agent that starts on an entry prefixes it with
`[taken]`; when the change is committed the entry is removed from here and
written up in `VERIFICATION.md`. See `AGENTS.md` — *The TODO / VERIFICATION
loop*.

## Bug Fixing / Improvements

- on razer the trackpad does not work after hibernation

- after hibernation, the screen automatically suspend after 1 minute which is not the normal behavior (it should take longer) — investigated 2026-09-11: searched all of `phios-dotfiles` for anything that could set an idle-timeout/auto-lock/DPMS policy (`grep -rl "idle\|suspend\|hibernate\|sleep"`). Found only `profiles/laptop/system/etc/systemd/logind.conf.d/10-lid.conf` (`HandleLidSwitch`/`HandleSuspendKey` — LID CLOSE and the physical suspend key, unrelated to an idle *timeout*) and `hypridle` listed in `profiles/desktop/packages.txt` with an explicit comment that its config is "deferred" — **no `hypridle.conf` (or any other idle-timeout config) exists anywhere in this repository, committed or templated.** So this project sets no idle-timeout policy at all; the observed "suspends after 1 minute post-hibernation" cannot be something `phios-dotfiles` configures, since there's nothing here to misconfigure. Did not attempt a guess-based fix. Next time this happens, on the real machine (not from this repo): `systemctl --user status hypridle` (is it even running, and does `~/.config/hypr/hypridle.conf` exist there outside the repo — if hypridle IS running with some config, where did it come from), `loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}')` (an `IdleActionUSec` or similar systemd-logind-level timeout, separate from hypridle entirely), and specifically whether the 1-minute timer only starts counting fresh right after a hibernation *resume* (a session/idle-timer reset on wake, which would point at a resume-hook or systemd-logind interaction rather than a normal idle timeout misconfiguration) versus being the ordinary idle timeout just being reached faster than expected around the same time as a hibernation resume.

- windows management keybinding (move, resize) do not work *to be checked first

- the magnifier glass currently does not zoom in since the border where removed. It has to do with inconsistencies with the screen capture method. Needs to be solved. Reference this: https://github.com/Horizon0427/Glasscope — investigated 2026-09-11 (`phi-shell/Magnifier/Magnifier.qml`, `phi-shell/Services/Magnifier.qml`): the "since the border was removed" theory does NOT hold up under a close diff read, though the actual cause is still open — two competing candidates below, not confirmed either way. Pulled the exact commit that dropped the bezel (`8aacf2f`, "drop the magnifier bezel plate") and compared it line by line against the pan/zoom math: `ScreencopyView`'s `width`/`height` (`root.screen.width * root.zoom` / `* root.zoom` — this IS the zoom mechanism, an oversized capture panned under the lens) and its `x`/`y` pan offset (`root.lensSize / 2 - root.viewX * root.zoom`) are byte-for-byte IDENTICAL before and after that commit. The only things that commit changed are how the circular mask is drawn (an opaque hole-punched Canvas disc → a `QtQuick.Effects.MultiEffect` masking a `layer.enabled: true` Item) and the outer `lens` Item's own size (was `1.6× lensSize` "bezelD", now exactly `lensSize`) — the latter looked like a candidate at first (it changes the absolute screen position of the item tree) but the inner `feedClip` was correspondingly re-anchored (`anchors.centerIn` at a fixed `lensSize` size → `anchors.fill` on a now-`lensSize`-sized parent), and working through the actual pixel math by hand, `feedClip`'s absolute on-screen position and size come out identical in both versions.

  Two candidates, not one, and they predict different, checkably-different symptoms:
  1. **The mask/layer change broke rendering entirely.** `feedClip` has BOTH `visible: false` AND `layer.enabled: true`, with its rendered texture meant to be consumed by the sibling `MultiEffect`'s `source`. Tried to verify whether `visible: false` on a `layer.enabled` item still produces a live texture for another item's `source` — searched Qt's own `qtdeclarative` source for this and got zero results, so this is NOT confirmed either way, only recalled as a common pattern elsewhere. Worth flagging as actively suspect, not exonerated: `MultiEffect`'s own docs say it manages layering internally and doesn't need `layer.enabled` set on its source at all, so the explicit `layer.enabled` here is redundant at best — and pairing an unnecessary explicit layer with `visible: false` on both `feedClip` and the `lensMask` Rectangle is exactly the kind of combination that could plausibly stop content from rendering, not something ruled out. If this is the bug, the lens would show NOTHING inside the rim (transparent), not an unmagnified image.
  2. **`ScreencopyView` never honoured the explicit oversized `width`/`height` at all**, even before the bezel commit — i.e. this may be a pre-existing bug this commit gets blamed for only by timing coincidence. Already self-flagged as unverified in the file's own header comment, written when the ScreencopyView-based approach was first introduced (commit `0b4bb5b`): "whether ScreencopyView honours the explicit scaled size." If this is the bug, the lens would show real, SHARP, unmagnified (1:1) screen content — something is visibly there, it just never scales up with the zoom setting.

  Could not verify either theory without a compositor (`phi-shell/CLAUDE.md`: "You cannot run this"), and did not make a speculative code change to either the masking or the capture sizing without being able to see the result. Next time this happens: first ask (or check) the one question that discriminates the two candidates without needing any new screenshot — **is the lens currently showing nothing at all inside the rim (transparent), or is it showing real screen content that just isn't magnified?** Nothing/transparent points at candidate 1 (the mask/layer change); visible-but-unmagnified content points at candidate 2 (ScreencopyView ignoring the explicit size). If it's candidate 2, a further discriminating test: open the magnifier at a low zoom (1.5×) and a high zoom (6×) and screenshot both — if the content looks the same apparent size at both settings, that confirms ScreencopyView is ignoring the explicit size.

- the ai agent a1 always fails starting. Running `phi agent broker —instance a1` shows it binds it correctly on “127.0.0.1:8789” (after the second time it shows the address occupied). — investigated 2026-09-11: read `phi/internal/agent/broker.go` (bind/shutdown logic looks correct, no stale-socket handling gap for TCP), `phi/internal/cli/agent.go` (SIGINT/SIGTERM → graceful `srv.Shutdown`, looks correct), `phi-shell/Services/Agent.qml` (only ever issues one `systemctl start phi-agent-a1.service`, guarded against re-entrancy), and `phi-agent-broker@.service`/`phi-agent-a1.service` (no code bug found, but `Type=simple` with no readiness sync between the broker binding its socket and `phi-agent-a1.service` starting is a plausible source of a *different* failure mode — connection-refused, not the reported address-in-use). Could not find a concrete code defect, and did not want to guess at a fix to the credential-broker's systemd unit without being able to observe the actual failure — this needs the real machine. Next time it happens: `ss -ltnp | grep 8789` and `systemctl --user status phi-agent-broker@a1.service` to see what actually holds the port.

- area selection in screenshot, OCR and QR reading is never right. The offset changes as the size and position of the area change. — investigated 2026-09-11: all three modes (save/OCR/QR) already share ONE selection code path in `phi-shell/Screenshot/Screenshot.qml` (`onReleased` → `_captureGeometry` → `_doCaptureGeometry`, differing only in what runs on the resulting PNG afterwards — `tesseract`/`zbarimg`/clipboard-copy), so there's no separate bug surface between them; a fix to the shared geometry math fixes all three identically. That shared math already carries a prior hardware-verified fix (commit `df4298d`) for offset growing with the SELECTED AREA'S POSITION on a multi-monitor layout — confirmed against grim's own source (`github.com/emersion/grim`, `render.c`) that grim wants the `-g` box in logical (not physical/scaled) coordinates, which `root.screen.x/y + selectionRect.x/y` already is. Read the current formula carefully for a SEPARATE bug where offset grows with the selected area's SIZE (not position) specifically, since that's what this entry says and df4298d's own comment only discusses the position case: found no mechanism for it — x/y and width/height are computed and rounded completely independently in `onReleased`, so width/height cannot mathematically feed back into the reported x/y in the current code. Could not reproduce or measure on real hardware to find whatever mechanism does exist. Next time this happens: get exact numbers — the logical selection rect drawn on screen (x, y, width, height, and which monitor / its `scale`) vs. the actual crop `file --brief` or `identify` reports for the resulting PNG, ideally for one small and one large selection on the same monitor — so a real size-correlated formula (if one exists) can be isolated instead of guessed at.

- improve the neovim chroma integration, with as many mapping as possible. When I press a key only valid options in the keyboard should be backlit, with color codes to understand the nature of the command (eg. If I press “g” I should have the numbers in a color, the g in another color, and so on). Currently the colors change smoothly, in this integration it should be instant instead.

- add specific settings for the “ambient effect”. Add more “screensaver” type of “ambient effect” (always only played in the lock screen). Also add a live preview of the effect when one is selected

- (was: "holding the volume up key should reach a top of 100%, exceeding it requires a double click + hold" — the 100% cap is fixed, see VERIFICATION.md) add a deliberate gesture (e.g. double-tap-and-hold fn+f3) to intentionally push volume past 100%. Not attempted as part of the cap fix: Hyprland binds have no built-in double-tap primitive, and this project's own hyprland.lua.tmpl documents a prior double-tap gesture (SUPER+G, ROUNDS FOUR/FIVE/SIX) going wrong on real hardware — a bespoke timer-based implementation needs deliberate design, not a guess.

- super+shift+left/right and super+ctrl+left/right do not do anything (not workspace change, not window focus/move) — only bare super+left/right (focus change) works. Worked around 2026-09-11 by adding super+shift+h/j/k/l (move window) and super+ctrl+h/l (prev/next workspace) as additional bindings alongside the still-broken arrow-key ones — see VERIFICATION.md. Root cause NOT found: four independent source-level checks against Hyprland's own code (`keybinds/Bind.cpp`'s `CBind::make`/modifier parsing, `keybinds/Resolver.cpp`'s keycode resolution, `config/lua/bindings/LuaBindingsToplevel.cpp`'s `hlBind`, and its `parseKeyString`/`CVarList2` tokenizer in `hyprutils`) found no defect — modifier names, key names ("left"/"right"), and bind-string tokenization/trimming all check out correctly for 3-token binds with word-name keys, so this isn't a config-file or Hyprland-core bug as far as static reading can tell. Next time this happens: run `hyprctl binds -j | grep -i left` on the affected machine (razer) — if the Super+Shift/Ctrl+Left/Right binds are ABSENT from that output, registration is failing at runtime for some reason not visible in source; if they're PRESENT with the expected modmask, the binds are registering fine and something else (an app stealing the shortcut, a modifier-detection quirk with this specific keyboard) is consuming the keypress before Hyprland's own matcher sees it. That single check discriminates between "config/registration bug" and "runtime/input-layer issue" and should be the starting point instead of re-deriving the source-level checks already done here.

- hyprland resize does not seem to work — investigated 2026-09-11: checked whether `hl.bind("left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"))` (and h/j/k/l/arrows siblings, `phios-dotfiles/profiles/desktop/templates/.config/hypr/hyprland.lua.tmpl`'s "resize" submap, entered via Super+R) has a shell-quoting bug — it's the only dispatch call in the file with a space inside an unquoted argument, unlike every other `hyprctl dispatch X Y` call which uses a single token. Confirmed NOT a bug: pulled `hyprctl`'s actual CLI parser (`hyprctl/src/main.cpp`, `main()`), which has an explicit exception for exactly this shape — an argument starting with `-` is only treated as a hyprctl flag if it does NOT parse as a number (the code's own comment: "For stuff like -2 or -2,"), so `-40` correctly falls through to the joined dispatcher request string instead of being misread as a flag. The submap's dispatch syntax is correct. Did not find another concrete defect in the submap definition (entry bind, four direction binds, three ways out via Escape/Return/catchall all look structurally sound) and could not reproduce or observe the actual failure without the real compositor. This entry and the "windows management keybinding (move, resize) do not work *to be checked first" entry look like the same underlying report — worth checking together. Next time this happens: confirm Super+R actually enters the submap at all (`hyprctl` has no direct "am I in a submap" query, but the cheat sheet / `hyprctl binds -j` can confirm the binds are registered), and try running the exact `hyprctl dispatch resizeactive -40 0` command directly in a terminal while the submap is NOT involved, to isolate submap-entry vs. dispatcher-execution as the failure point.


## Features

- add a setting to invert the scroll wheel (mouse/trackpad)

- "theme auto" which changes automatically on evening time (automatic/manual time). Consider "phi theme set" restarts the qs and that cannot happen automatically, the change should be smooth and non destructive.

- add suspension/hibernation settings in the settings panel

- add a power icon to the left isle of the status bar, it's overlay should have power options (suspend, logout, shutdown, lock, hibernate, reboot) and "settings". add log out, lock, suspend, hibernate, reboot, shutdown commands so that they can be quickly referenced in the runner bar as well. Reboot and Shutdown should require confirmation.

- new terminal windows should start at the same position as the last focused one

- color picker (maybe compatible with the magnifying glass)

- three finger gestures on trackpad and touchscreen: up/down (open/closes overview), left/right (change workspace). Add more if not too error-prone.

- add trash feature (package to be picked). Options (to be checked if they work as expected): CliFM (cli), ... * check the list on archlinux.org file manager

- system file picker required

- add a timer and alarm feature to phi, also add tools to the runner to quicky setup timers and alarms. They should have a custom overlay that requires to be turned off, on the higher Z index in the system. It should have a ringtone. The two features must be customisable in the settings.

- add option for automated night mode (automatic time at nighttime or manual hours range)

- phi agent should run automatically as the panel is opened for the first time (or on startup). It should not waste resources when not used

- clicking on the wifi icon should show the list of available wifi to connect. Same in the settings.

- spotlight cursor: super+super (double tap hold) * blocked by issue on hyprland 0.56

- consideration: usare alt come super, così avrei 2 super invece che 2 alt. Da valutare con software che usano alt [TBD]

- add gestures to open the chat and notifications panel: 2 finger swipe from edge (touchpad) or swipe from screen edge (touchpad). Make the inverted gesture to close the panel as well. It should move progressively with the scroll, not only a toggable state.

- full screen alert should appear when battery level is low (2 thresholds warn and danger, configurable)

- add a sound on charging plugged in

- have a battery saving mode, it automatically kicks in when not in charge and lower then 20% battery (or notifies the user to  do so), configurable. automatically disabled when plugged in and over the threshold. It must have visual feedback on the battery in the status bar and settings. The battery overlay must have the switch.

## Custom apps and services

- Notes app

- Cloud storage [server]

- Music indexing + download [server]

- Music client

- Movies/Series indexing + download [server]

- Jellyfin hidden library feature [server]: have the option to add storages for hidden content, which gets indexed (actors, categories, titles, tags) only to users that have access, only when toggled on (client side option)

- Jellyfin client

## Style

- many elements and options don't have basic UX features. a quick lists: chat panel has no settings button, wallpaer list has no "browse wallpaper folder", most options don't have hover effects, cursor never changes state on clickable elements or fields, tabs are indistinguishable from buttons, some elements are clickable without any feature (eg. the bluetooth elements in the list),  the lock screen has no "locked" state with timer after too many failed attempts, no wrong password visual feedback, no clean button for searchbars, accordions don't differentiate the body, accordions sometimes have the arrow icon sometimes they dont, often time the accordions don't align content with the title (when the arrow is present, they should compensate for it), many elements that have the same behavior don't have the same visual grammar, trigger buttons don't bring loading states or result feedbacks, there are no skeleton loading or loading in general, the settings panel should have options better organised, grouped and ordered in meaningful ways. There are many more issues that can be found, this task requires you to act as an expert UI/UX designer, being critically honest about each feature and every detail, and polish out the system UI/UX to optimal levels, focusing on functionality. No element in the current state has a definitive style, everything can be reworked, but all elements should be coherent and follow the same grammar, possibly using the same styling options. Also as many variable as possible should be mapped in the theme settings.

- the hyprland scratchpad should slde in from below, have slighlty more out spacing than other workspace and have a accent-colored border all around the screen

- the dim from the notification, chat panel and scratchpad should not overlay the status bar, while the dim from screenshot, overview (alt+tab) and warning/alert (eg. battery, to be introduced) should cover it. Have the 2 types of dim have different intensity as well (the one that overlays should be stronger)

- rework status bar buttons: they should not have a box button but be just icons, with hover and active states. Apply SVG animations to icon when changing within states (eg. volume amount and muted, bluetooth activation, wifi strenght/activation/searching, brightness amount (sun/moon icon that fills up, based on either night mode on or not, with an animation from sun to moon)), notifications (DND state as well), battery states. Apply the background to the isles in the status bar (noo trasparency).

- the clock in the status bar should change like a flip clock

- add the clipboard icon to the status bar (with animation for when an element is added)

- add status bar icons for active sensors (microphone, camera), the overlay should show a list of apps with the sensor they are using and killswitches. Also add settings for killswitches and permission rules

## Ideas (not to be implemented, have to be discussed)

- LocalSend

- update centre + Applications folder

- Log viewer

- Customisations should be exportable in a single configuration file, as well as importable from the same file (with syntax check).

- Weather: add an extra special workspace dedicated to weather informations using: https://github.com/ashuttl/linecast . It should probably use a multiplexer to show a single view with all panels, rather than separated. (Or all instances of linecast go to the special workspace, that does not allow other apps)

- a list of active ports and servers should be available both in the settings under connectivity as well as in the tailscale panel. Taking inspiration from this https://github.com/ZerubbabelT/portwatch

- vocabulary tool: add a definition tool that provides definitions for words and implement it natively I the runner bar. It can accept multiple languages, if the language is not the system language, it should show the translation (using the translate tool described below). Settings for the vocabulary should be added in the settings, where the user can add more languages that don’t require translation for the definition (still show the translation of the word if not of the system language)

- translate tool: add a translate command that takes an input string and translates it, implemented in the runner bar. It should accept optional arguments for “from” and “to” language, otherwise the language is automatically detected and the “to” language is by default the system language. The case the “from” language is the system language the default translation should return not be handled now (throws an error that must not block the runner). The runner bar should also have a custom layout for that result, showing the from and to translation and languages. (Translation and vocabulary tools can work together in the runner).

## Dotfiles improvements:

- Better separation

- Cleanup + Optimisation

- Remove AI shenanigans



- place all phios locals in ~/.local/share/phios/{phi|dotfiles|phi-agent}

- Installer
