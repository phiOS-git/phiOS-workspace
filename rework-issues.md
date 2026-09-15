Most of the requests done in rework.md was wrong. Here a list of bugs to fix.

1. the status bar should hav a background, not the isles. Also the border radius logic (1px outward, 4p inward) should be appliead to the bar, not to the isles.
2. The btop workspace (12) still exists, it should have been removed.
3. The status bar overlay, specifically for the clipboard and notifications, are way to tall. It should not go over 3/4 of the screen height. The notification panel should not have a fixed hieght, it grows based on content.
4. in the status overlay we have some issues:
    a. the lock icon has no hover effect
    b. the sensor where never meant as text+switch but as icons, they are well described as "list of toggleable icons" in rework.md. It even explains how many different states an icon should have (meaning it should have different icons for each state, possibly animating from one to another)
    c. the tiling system does not work even in the 2 style it should have. When i set a tiling style, all windows in the workspace should follow it. Currently the "floating" style simply makes the focused window floating and pressing it again toggles it off. The tiling style does nothing at all.
5. the "mic" and "cam" entries in the lower bar were never requested
6. the network icon does not use the ethernet/wifi icon but another one that needs to go
7. the network overlay shows a first title "Tailscale" that should be simply removed
8. the workspace list in the status bar should have the active workspace grow only in width, not in height as well. also the list itself should have a little padding
9. the "line separators" in the status bar should be vertically centred



New requests:

1. add a setting in the "settings panel" to toggle the battery charge amount in the status bar
2. add to the "stats overlay" a button to open btop in a new workspace (simply add one to the currently highest and focus that.
3. in the network panel, add a section to toggle the firewall and, when enabled, to set the firewall profile
4. in the clipboard overlay, reduce entries to a single line with trimming (ellipsis, "...") and remove the time in the list. Leave the time information in the hover overlay
5. in the clipboard overlay, make the hover overlays larger with a range 100px-300px based on the content and make the time signature and the source spaced between
6. in all overlays, the "settings button" that usually appears at the end, should instead be a settings icon in the header aligned with the title (space between). The network overlay currently has this for each inner section and that's perfect, hoever those icons should not be button (centered, button hover effects, etc) but icon-buttons, meaning that they align correctly with the right side and have an hover effect that changes their opacity and pointer cursor, also they can be as big as the button, without the padding around. The same should be applied to the settings icon in the chat panel
7. in the status overlay, icons should be distributed horizontally
8. in all status bar overlays there should be more some padding for each inner section and those should be divided by an horizontal thin line separator
9. the "currently active window name" in the low status bar on the left isle, should have some spacing on the left, exactly the same amount icons have as inner padding. Also it's not vertically centred
10. the list of windows in the center isle of the low status bar has 3 issues:
    a. it should show the window icon, not a letter. Letter can only be accepted as fallback
    b. the order is inverted compared to the tiling (it's right in count but if i move a window in the tiling, that should be reflected). When not tiled, windows can be automatically set to the end of the list compared to tiled ones. The same issue exists in the overview.
    c. clicking on an icon does not focus the window
11. the "runner" icon (the lens in the low-left) and the "phi" icon do not have an active state when their relative panel is open
12. the "phi" character looks too small compared to the icons. If possible replace with an icon.
13. the calendar overlay is not centred.
14. in all status bar overlays, replace list of option with thinner style. Instead of bulky buttons it should be a list of texts, with the "highligh" hover and selection (same effect used in the runner bar).
15. the overview needs some fixes:
    a. pressing ESC should close it
    b. the entries should be larger windows with padding, a shade background.
    c. the currently selected window (starting from the one in focus, but based on the cycle) should have a clear selected state, currently they all look the same
    d. the workspace count on the bottom, should have a list of squares with some padding and border, and the active one in the cycle should have a selected state, identical to the workspace list in the status bar.
16. increase the padding of the terminal windows to 40px (make it customisable in the settings)
17. in the settings panel:
    a. make the panel padding the same on all sides
    b. separate inner sections using a shade background

