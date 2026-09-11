# TODOs

The user's backlog. An agent that starts on an entry prefixes it with
`[taken]`; when the change is committed the entry is removed from here and
written up in `VERIFICATION.md`. See `AGENTS.md` — *The TODO / VERIFICATION
loop*.

## Bug Fixing / Improvements

- on razer the trackpad does not work after hibernation

- windows management keybinding (move, resize) do not work *to be checked first

- the magnifier glass currently does not zoom in since the border where removed. It has to do with inconsistencies with the screen capture method. Needs to be solved. Reference this: https://github.com/Horizon0427/Glasscope 

- the ai agent a1 always fails starting. Running `phi agent broker —instance a1` shows it binds it correctly on “127.0.0.1:8789” (after the second time it shows the address occupied).

- alt+tab does not work: when releasing alt it does not select the window nor it closes the overview. When clicking a windows in the overview it does not select it. It’s always the first window to be selected when opening the overview, not the actual active one. 

- when applying an area screenshot, the dim area is trimmed below the status bar

- area selection in screenshot, OCR and QR reading is never right. The offset changes as the size and position of the area change.

- ESC key should close open overlays and panels. Sometimes ESC might just remove focus from an element (eg. The chat text field) so it should only close a panel if nothing is focuses inside of them

- improve the neovim chroma integration, with as many mapping as possible. When I press a key only valid options in the keyboard should be backlit, with color codes to understand the nature of the command (eg. If I press “g” I should have the numbers in a color, the g in another color, and so on). Currently the colors change smoothly, in this integration it should be instant instead.

- [taken] the runner should resize it’s height when there are not enough options to fill it. (Anchored on the top)

- add specific settings for the “ambient effect”. Add more “screensaver” type of “ambient effect” (always only played in the lock screen). Also add a live preview of the effect when one is selected

- holding volume up should reach top 100%. To increase over 100% it requires a double click + hold.

- add an icon icon in the list of desktop to toggle the hyprland scratchpad

- add borders to the whole view when in the scratchpad or make it recognisable

- clipboard should show an overlay with the complete command and extra informations when the selection is held for a while (or on mouse hover after some time)

## Features

- color picker (maybe compatible with the magnifying glass)

- add trash feature (package to be picked). Options (to be checked if they work as expected): CliFM (cli), ... * check the list on archlinux.org file manager

- system file picker required

- add a timer and alarm feature to phi, also add tools to the runner to quicky setup timers and alarms. They should have a custom overlay that requires to be turned off, on the higher Z index in the system. It should have a ringtone. The two features must be customisable in the settings.

- start-hyprland should be automated on startup

- phi agent should run automatically as the panel is opened for the first time (or on startup). It should not waste resources when not used

- clicking on the wifi icon should show the list of available wifi to connect. Same in the settings.

- spotlight cursor: super+super (double tap hold) * blocked by issue on hyprland 0.56

- consideration: usare alt come super, così avrei 2 super invece che 2 alt. Da valutare con software che usano alt [TBD]

## Custom apps and services

- Notes app

- Cloud storage [server]

- Music indexing + download [server]

- Music client

- Movies/Series indexing + download [server]

- Jellyfin hidden library feature [server]: have the option to add storages for hidden content, which gets indexed (actors, categories, titles, tags) only to users that have access, only when toggled on (client side option)

- Jellyfin client

## Style

- tailscale/vpn overlay should align its content better. Connectivity as well (especially the buttons)

- the overlay use the buttons with borders that are notte visible, so the text appears not aligned.

- overlay panels are still way too distant from the status bar: they should be few pc below the bar


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

- Manual steps: remove the "(base)" as i can't copy-paste-run

- place all phios locals in ~/.local/share/phios/{phi|dotfiles|phi-agent}

- Installer
