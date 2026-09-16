Those are directive specific to the status bars and the overlay elements.

# Style

1. the overlay shells seem to use a different background color from the status bar. While inner sections of the overlay should have a different background, the overlay itself should not. There must be some padding in the overlay as well as spacing between inner sections.

2. calendar overlay:
    a. Make the time larger and centered
    b. add day, month, year below the time, smaller then the time, centred
    c. move the timer sections below the calendar

3. workspaces list: remove the bouncing animation, it should only enlarge in width, no bouce

4. all the overlays that have a keybinding (notifications, and clipboard, but this should be a global fix as i might add new keybind in future) open their overlay shell in the screen corner, rather then aligned with their iconfig 

5. when changing theme, shells don't change until hyprland is reloaded completely. Config files change correctly instead. The shells should update without reload as well, in order to make the automatic theme work. There should be a transition for shells changing color.

6. in the "titling" section of the status overlay, add a fitting icon for each option, centred above the text

7. in the clipboard history:
    a. the context menu that opens with the right click has no option inside. It should have: copy, pin/unpin, delete
    b. the details panel (that appears on hover/selection) should have some spacing from the original overlay
    c. the details panel should be aligned with the respective option not on the vertical center but on the top or bottom side (based on the screen position)
    d. the details panel currently has always the same width, it should instead have a variable width (from 100px minimum up to 600px) based on its content
    e. the details panel currently seems to have a fixed or minimum height, that should ont be the case. The height changes based on the content. It should have a padding (already correct, just the same on all sides). Add spacing between the content and the details line.

8. the network element in the status bar has multiple icons overlapping (wifi/ethernet, tailscale, etc). They should be well positioned

9. The network overlay has some issues:
    a. while scanning the list appears as an empty area, that should not happen
    b. the "Refresh" button is not aligned correctly (should be on the right side, instead of close to the title).
    c. VPN should have a generic activation switch, then the configurations should appear in a list of elements that can be selected (like the list of wifi or sound devices)
    d. The tailscale "overlay name" has no interaction, it shouldn't have an hover state, pointer cursor, selected state and so on. It's just status text.

10. While an overlay is open, the status bar (or maybe the whole quickshell) gets "blocked": no more hover, no curor pointers and to make it work again the overly must be closed. This means, for example, that once i open an overlay clicking on another icon won't open the right overlay, it will just close the current one (same as clicking everywhere outside the overlay). Opening an overlay should not block quickshell, everything should work just the same. However remember that no more then 1 overlay can be opened at a time.

# Features

1. the clipboard history should automatically filter out "empty" values

2. the clipboard history should check for duplicate entries, if any is found the details are changed, it gets pushed as first element, but there must not be entries with the same value 

3. in the settings panel for clipboard history, add an option to clear clipboard history (does not delete pinned options)

# Without solution (not to be implemented)

Those are issues without a solution:

1. in light mode the focues window has a dark border that is hardly visible
