# TODOs

The user's backlog. An agent that starts on an entry prefixes it with
`[taken]`; when the change is committed the entry is removed from here and
written up in `VERIFICATION.md`. See `AGENTS.md` — *The TODO / VERIFICATION
loop*.

## Bug Fixing / Improvements

- on razer the trackpad does not work after hibernation

- after hibernation, the screen automatically suspend after 1 minute which is not the normal behavior (it should take longer)

- windows management keybinding (move, resize) do not work *to be checked first

- the clipboard preview should be on the left of the sidebar, rather than inside. Also it's very low, it should be vertically aligned with the relative entry (beware of the position in the screen, so that it does not go out of the screen area).

- the magnifier glass currently does not zoom in since the border where removed. It has to do with inconsistencies with the screen capture method. Needs to be solved. Reference this: https://github.com/Horizon0427/Glasscope 

- the ai agent a1 always fails starting. Running `phi agent broker —instance a1` shows it binds it correctly on “127.0.0.1:8789” (after the second time it shows the address occupied). — investigated 2026-09-11: read `phi/internal/agent/broker.go` (bind/shutdown logic looks correct, no stale-socket handling gap for TCP), `phi/internal/cli/agent.go` (SIGINT/SIGTERM → graceful `srv.Shutdown`, looks correct), `phi-shell/Services/Agent.qml` (only ever issues one `systemctl start phi-agent-a1.service`, guarded against re-entrancy), and `phi-agent-broker@.service`/`phi-agent-a1.service` (no code bug found, but `Type=simple` with no readiness sync between the broker binding its socket and `phi-agent-a1.service` starting is a plausible source of a *different* failure mode — connection-refused, not the reported address-in-use). Could not find a concrete code defect, and did not want to guess at a fix to the credential-broker's systemd unit without being able to observe the actual failure — this needs the real machine. Next time it happens: `ss -ltnp | grep 8789` and `systemctl --user status phi-agent-broker@a1.service` to see what actually holds the port.

- area selection in screenshot, OCR and QR reading is never right. The offset changes as the size and position of the area change.

- improve the neovim chroma integration, with as many mapping as possible. When I press a key only valid options in the keyboard should be backlit, with color codes to understand the nature of the command (eg. If I press “g” I should have the numbers in a color, the g in another color, and so on). Currently the colors change smoothly, in this integration it should be instant instead.

- add specific settings for the “ambient effect”. Add more “screensaver” type of “ambient effect” (always only played in the lock screen). Also add a live preview of the effect when one is selected

- (was: "holding the volume up key should reach a top of 100%, exceeding it requires a double click + hold" — the 100% cap is fixed, see VERIFICATION.md) add a deliberate gesture (e.g. double-tap-and-hold fn+f3) to intentionally push volume past 100%. Not attempted as part of the cap fix: Hyprland binds have no built-in double-tap primitive, and this project's own hyprland.lua.tmpl documents a prior double-tap gesture (SUPER+G, ROUNDS FOUR/FIVE/SIX) going wrong on real hardware — a bespoke timer-based implementation needs deliberate design, not a guess.

- super+shit+left/right do not change active workspace

- make steam workspace 11 and btop workspace 12

- hyprland resize does not seem to work

- the cheathsheet shell should have 2 columns

- add borders to the whole view when in the scratchpad or make it recognisable

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
