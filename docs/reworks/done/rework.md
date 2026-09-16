# phiOS rework

Rework of the interface and elements for phiOS

## Status bars

1. There will be 2 status bars, one on the top and one on the bottom of the screen
    a. the top bar will contain:
        left isle: phi icon, line separator, workspaces list
        center isle: clock
        right isle (right to left): settings icon, line separator, notifications icon, clipboard icon 
    b. the bottom bar will contain:
        left isle: lens icon, line separator, current app name
        center isle: list of windows
        right isle (right to left): stats icon, line separator, battery icon, network icon, bluetooth icon, volume icon, brightness icon

Both bars have a solid background and have 1px border radius on the outward corners, 4px border radius on the inward corners.

### Status Bar Elements

All status bars elements don't use any specific color unless specified. they all share the same size and style unless specified differently. All icons have hover and active states (same effect currently used). All icons have transitions when changing states and icon animations where possible.
List of elements:

- phi icon: it will evoke the "ai chat panel"

- workspace list: a list of clickable squares, with hover and active states. They show the number of the workspace and a thin border, no background. The selected workspace has slightly more width and uses inverted colors.

- clock: date time (configurable in settings). When pressed it will open the "calendar overlay"

- settings icon: when pressed it will open the "status overlay"

- battery icon: icon with fill amount, charging and discharging states. It changes color to orange below the "first battery saving threshold" (20%) and to red below "second battery saving threshold" (15%). It turns yellow when "low power mode" is active, no matter the threshold level. When clicked opens the "battery overlay". When right clicked toggles "low power mode".

- notifications icon: when pressed it will open the "notification overlay". It has different icons for: no notifications, unread notifications, dnd (do not disturb).

- clipboard icon: when pressed it will opent the "clipboard overlay". It has a simple animation when a new entry is registered.

- lens icon: when clicked evokes the "runner bar".

- current app name: shows the current app name, uses the accent color.

- list of windows: list of icons for all windows in the workspace, with active status for the currently focused. Clicking on one automatically focus it.

- stats icon: when clicked it will open the "stats overlay". 

- network icon: will show an icon for either wifi, ethernet, missing. Ethernet can have a "no internet" state. When there is not ethernet, if the wifi is disabled it will show a "wifi disabled" icon, otherwise the wifi icon should have different intensity states). It should consider more icon states for network issues. When pressed it will show the "network overlay".

- bluetooth icon: icon with enabled/disabled state and connected state. when clicked will open the "bluetooth overlay"

- volume icon: shows volume icon (animated on change) with muted state and error state. When clicked opens the "sound overlay". When right clicked toggles muted.

- brightness icon: brightness icon (fill animation on change), when clicked it opens the "screen overlay".


## Status bar overlays

When an icon invokes a "status bar overlay", an overlay panel should transition in. Losing the focus by pressing esc, clicking out or opening another overlay will close any other overlay. Only one can be opened at the time. All overlays have a main box with background (use a shade of the main background) and align vertically some inner elements (those inner boxes use the normal background color). Overlays have 3 corners of 4px and 1 corner of 1px (relative to the corner their parent icon sits). The overlays are not full height, they don't have a maximum height but the layout makes them usually smaller then full height.

List of status bars overlays:

- calendar overlay: aligns in column a larger clock with full data (with the flip clock animation), a timer, an interactive calendar. This overlay has both the top corner at 1px (only exception to the general rule).

- status overlay: the status overlay will show:
    - user profile pic on the left, on the right in column username and session time
    - list of power icons: lock, suspend (sleep icon), hibernate, logout, reboot, shut down. They all have different colors on hover. hibernate, logout, reboot and shutdown option will request confirmation with the "system modal"
    - Section "Media control": shows currently playing source, with media controls. Only if there's an available source.
    - Section "System control":
        - volume icon with volume bar (pressing on icon toggles mute)
        - brightness icon with brightness bar
        - list of toggable icons: night mode (moon/sun transition), true tone (with disabled state if not available), stay-awake (amphetamine icon with 2 states), microphone sensor, camera sensor. All those icons will toggle enabled/disabled for their relative function. The sensor icons have a state for when they are enabled, disabled, in use.
    - Tiling options: a grid of icons with name, each with hover and active state. They change how the workspace handles windows tiling (possibly workspace specific, if impossible downgraded to being be global).
        - X scroll: each windows is full size and in row, changing focus scrolls so the new one is in the centre. Small preview of the previous and next are visible.
        - Y scroll: each windows is full size and stacked in column, changing focus scrolls them so that the correct one is in view. Small preview of the next and previous are visible.
        - Tile: simple tiling (allows resize and movement while keeping tiled)
        - Center: one window tiled at the center 50% width, the others tiled in the 2 sides
        - Fair: tiles windows to divide the space fairly, clockwise.
        - Floating: removes auto tiling (windows should persist their floating size and position even when the tiling style is changed, so they return to their original state when reapplied)

- notifications overlay: has a switch to DND, as well as triggers for DND 30mins, 1h, 4h (with visible end time when enabled with timer). Below the list of notifications are divided by date (today, yesterday, this week, older), then grouped by source in the same date. Both date and source groups can be collapsed and expanded (date groups are expanded by deafult, source groups are collapsed by default). They have clear buttons on each single notification, on each group (source or day) and a clear all button.

- clipboard overlay: it opens with a focused searchbar, the first sections shows the pinned entries, the second section is a scrollable list of all clipboard history. Can be navigated with arrows and tab or mouse hover. Focusing an option for 1 seconds will add an aligned overlay on the left showing more details. Pressing enter or selecting will copy the entry and close the panel. Pressing ctrl+p while one option is focused pins/unpins it (show shortcut hint small in panel). Also has a small settings icon to open the "settings panel".

- stats overlay: show in column some quick device statistic and graph:
    - network speed and ping (with animated graph)
    - disks usage
    - ram usage, cpu usage, gpu usage (if available)
    - CPU temp, graph and 4 fan profile buttons with active state (auto, silent, default, heavy)
    - GPU temp (if available), graph

- network overlay: divided in sections, each section has a settings icon that opens the "settings panel" to the relative position.
    - If ethernet it will show the status. If in wifi a wifi switch. When enabled: the active network (either ethernet or wifi), status (with speedtest), list of available networks (clicking performs connection attempt, password is prompted in the "system modal").
    - tailscale switch. When active will show the status.
    - vpn switch. When enabled: status, list of available configs (clickign them changes the active one). 

- bluetooth overlay: shows a toggle for bluetooth. When active shows the list of available devices, clicking on one connects/disconnects it. Also has a small settings icon to open the "settings panel".

- sound overlay: shows the volume level, a muted toggle and the list of output devices (pressing one activates it). Also has a small settings icon to open the "settings panel".

- screen overlay: shows the brightness level, a night mode switch and a true tone switch (disabled if not available). Also has a small settings icon to open the "settings panel".

Stylistic notes:

s1. the area used by the windows in the cerntral part of the screen is delimitated by the line separators in the status bars.

s2. terminal windows should have a padding of 20px. That area can be used to drag when in floating mode.

s3. currently the theme works mainly on using the white/black alternation, with some part of accents. Instead the theme should make more use of shades, so starting from the black or white (based on the theme) and have shades of that colors used for most of the UI and themes. Text uses white on black and vice versa. The accent color is used for details. Other colors are only used when informative.

s4. all elements should have similar transition (fade and minimal slide) for appearing and disappearing. Elements that are nested (eg. status bar overlays) should have compound transitions where they fade in and the inner elements fade in in order (with minimal delay, just a subtle effect that don't slow down the usage).

s5. all ui elements should have a very thin and elegant style, while many still have a bulkier style (eg. buttons and switch that absolutely requires rework). The style should still be coherent with a terminal based system, following closely the provided references. However it should become more elegant by using thinner borders, smoother shapes (but avoid very curved material-like elements), elegant transitions, subtle details, use of shades rather then B/W contrast.

## Other UI elements:

- system modal: a warn, prompt or confimration modal that blocks interactions until it's resolved.

- runner bar: unchanged.

- volume/brightness change overlay: the small low-centred overlay displayed when volume or brightness is changed with keybinding (already existing, leave as it is)

- context menu: a classic context menu for right click actions to be used when needed. Clicking on the empty screen evokes it with a options: run, terminal, files, browser, settings.

- settings panel: unchanged.

- cheatsheet: unchanged.

- ai chat panel: a side panel that gets evoked from the left side of the screen. It has full height and dims the screen elements when it's active (contined between the status bars). It opens by default to a new chat (or latest state). It has tabs for: chat, code session, status. in the top right corner it has a small settings button to open the settings panel.
    - Chat: will have a toggleable sidebar with projects and chat list, as well as button to start new ones. The chat area itself is dedicated to the chat, with some minimal settings in the header (rename, change personality).
    - code sessions: lists all the available sessions and their status and allows to open them in a new terminal window (or focus it if alrady exists)
    - status: will show a quick overview of the system status (use icons and small texts) and the list of "memory proposal".

- image window: images should be opened in floating mode, in a window with a 4px border and a bottom area containing the name of the file (can be dragged clicking on that area). Double cliking it should toggle full screen. A reference can be see in the file "references/floating-panels-reference.JPG" (check only the image panels, other elements are not references).

- lock screen: notifications should be removed. Shutdown and reboot actions should request a confirmation when pressed.

- overview: activated by alt+tab it should show the list of windows of the current workspace centred in the screen and a list of workspaces on the bottom-center. The active workspace and focused window should be highlighted. Cycling with alt+tab or selecting a window with the mouse will close the overview and focus that window. Clicking a workspace in the overview simply move the view to that workspace without closing the overview (the windows should fade out and the new one fade in). 

# Features to be removed

- there will be no more workspaces specific for a certain program (btop/steam)

- notification panel downgraded to "notification overlay"

- clipboard panel downgraded to "clipboard overlay"

- the brightness icon does not have the moon/sun icon with filling, instead just a brightness icon

- many elements in the bars are either condensed or removed, and no icon has text next to it anymore.

# Features to be changed/fixed:

- the keybind and gestures to change workspace should not loop

- a GUI file manager needs to be added: thunar. Add to dotfiles and customise to fit the theme.

- add a app/file/cmd tag to the runner bar * TBD

- image panels still close when focused (fixed by creating custom image shell)

- the settings should allow an "auto" theme option, where it changes from dark to light based on the time of day. In order to do this, the "phi theme set" command must be reworked not to close the active quickshell session. The task is completed when a transition is also applied when switching from one theme to the other. (it's acceptable not to have the transition for third party theme configs).


