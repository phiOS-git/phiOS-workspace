Those are some general reworks for the whole system or specific elements of it.

# Style

1. change the style of the system modal:
    a. currently i can't use the keyboard (tab, shift+tab, enter) to select the confirmation button and select it. When the modal is active, it's important to block inputs to the rest of the desktop environment, yet i should be able to confirm with the keyboard
    b. the buttons should occupy the whole width of the confirm

2. change the notification popup to follow those rules:
    a. it is on 1 line and has a max-width. is divided in icon, text content, "x" icon.
    b. when clicked it activates it opens the source window, if the "x" icon is clicked it just closes the popup.
    c. it has a quick animation: first the source icon appear, then it expands to show the text (trimmed if too large), then it closes and disappear. Timings should be configurable in the settings

3. rework buttons:
    a. they have 3 main styles: outlined, filled, text-only
    b. all button styles have coherent transitions on hover, selected, active (for click down)
    c. all buttons use the pointer cursor
    d. All buttons in the system that have no border currently should be changed to the outlined style.
    e. Text-only buttons should not have border, hover background and padding. Instead they are plain text that get the pointer cursor and the "highlighted" effect when hovered or active (the text gets highlighted using the text color, so the text changes to the background color, based on the theme).

4.  In the runner bar, when a tag is active (by tag i mean the words that activate a custom ranking like "app", "file", "ask", "web", "phi", "run", "yt", "wiki", "arch", etc.) it should have 2 effects:
    a. the tag should get the "highlighter" effect with transition, using a color code associated with the tag itself
    b. the runner bar should change the border color with the associated color code (with transition, clockwise in, counter-clokwise out, with accelleration)
    c. when deleting text from the runner, deletion should stop at the tag, so if i keep pressed backspace i will reach the tag and won't delete it. In order to delete the tag it requires to double click backspace. The "x" button in the searchbar should delete the tag as well.

5. The runner bar text input can go out of bound. It should instead have visual limits cutting of the overflowing text. Hoewever when the "ask" tag is active, the text input will grow vertically (within a limit of height) to fit larger prompts.

6. Thunar config theme files are missing

7. Thunar is not set as hyprland default File Manager

8. The "quick note" element in the bottom right corner works great as a placeholder, it requires a couple changes:
    a. it currently sits in the corner above the bottom bar, it should instead be in the very corner of the screen no matter what
    b. it should not have a visible area, instead it should only be triggered in the very cornered px of the screen. When the cursor is in position, it can expand visually (larger then now)

9. Switch elements should be reworked:
    a. The on and off states should have the same opacity. The disabled state should use lower opacity.
    b. There's delay or different transition times between the moving thumb and background color change (only when activating). The color changes immediatly, the movement comes later.
    c. When an active switch is hovered the thumb should shrink a bit
    d. the switch should have a "Label" which contains the text label and the switch itself. The label should have the cursor pointer and should activate the hover effect and the toggle on the switch. It should also style with opacity when disabled the same way as the switch itself. Currently many switches are set in the whole system and those have a "label" text next o them, none should change how they look, they just need to get the new integrations on

11. The scratchpad should slide windows from the bottom, currently it always slides in/out on the right

12. There are many status texts in the system (in the overlays, in the settings panel, etc) that are informative status text but look like buttons as they have hover effect, selection state (when clicked) and pointer cursor. It should not have those feature, just a specific style to make it informative of what it is. This has to be solved globally. The Status text should be normalised in the whole project: it's a normal text made of label and status (visually distinc), those two elements might be separated with space between them (like in all the occourances currently), when hovered the status element get the "highlighted" effect. Here some example of where i found it:
    a. in the Network Overlay, under the Tailscale section, the entry "Overlay name" does not have any interaction, it's just status text
    b. in the settings almost every section has some (eg. in the ai settings: the services and their status, and the brokers and their statuses; in the security settings the clamav, face unlock and secrets inner sections have some; etc.). Fix and normalise this globally.

13. The "Speed & latency" in the settings panel and in the Network Overlay requires some changes:
    a. is part of the Wifi sections. Instead it should be available with ethernet connections as well. This must not monitor the local connection speed but the internet connection speed, so it's related only to the presence of an internet connection (and should have a state for missing internet connection.
    b. visually it should not have lines, rather a bar graph..

14. The General section of the Settings Panel, should show user informations. Some extra informations should exist like name, profile image, etc. Informations that can be changed should be editable. Changing password should also be possible from this panel, using the System Overlay with a custom body: old password, new password, repeat passoword, confirm/cancel buttons, validation (consider i will change style for this, so the System Overlay should allow custom panels as well, reusing the blocking logic).

# Features

1. The notifications don't seem to work correctly. There's probably a lot of dead code and changes done in time as various issues are cumulating. Clear up the notification logic as much as possible in order to have a very clean and linear setup.
    a. no warn prompt confirmation when clearing notifications
    b. clearing notification (single, group, all, it does not matter) seems to logically clear the notifications but not visually. They stays in the overlay panel even when closed. Restarting hyprland or quickshell actually updates the notifications
    c. when receiving a notifications the popup appears only the first time
    d. clicking a notification should open the source window (if any) or activate their custom behaviour if set.

2. There is a lot of informative text in the UI that should be removed. While some descriptions are useful to understand what an option does, there are many texts that are clearly AI artefacts made to describe the features from the prompt, those need to go away. Text that is written as reminder for a feature to be implemented or completed should stay (and make them use warning color)

3. the trackpad does not have any "smooth scrolling" while the touchpad actually does (what i mean by smooth scroll is the effect that makes the scrolling last a bit longer then the actual end of the input, with velocity-based alterations). Be careful: i only want the smooth scrolling where the touchpad uses it. For example if i use the touchpad on librewolf i get the smooth scrolling while if i use the touchpad i don't, however on nvim (or terminal in general i guess) the touchpad does not scroll and thus i don't want the touchpad to have extra scrolling that would feel un-naturla. Be sure to apply the effect only for thoss


# Ideas (not to be implemented)
