Those are new interesting features to add.

# Next steps

1. optimise code and remove redundancy
    - overview -> AppSwitcher
    - optimise shells
        - cleanup Dialogs
        - cleanup Popout
    - usare folder phios in .config e .local (oltre a etc)
        - migliorare organizzazione wallapapers (currently /dynamic è hardcoded per essere evitata, non ha senso)
    - mathx e simili hanno sesnso in phi? non dovrei snellire phi e creare dei tool separati come phi-packages ?

2. studiare Ai agent da zero: usare pi + opencode (con possibilità di integrare altri motori come claude code)

3. nvim: setup plugins e separazione IDE e notes
    a. IDE:
    b. Notes: zettlekaste + image (and other medias + websites) render and drop + grammar checking
    c. keybinding

4. ultimi fix:
    - magnifier
    - AppSwitcher
    - spotlight (borders)
    

5. ultime features:
    a. server:
        - cloud file manager
        - indexing (movies + series + music)
        - git remote manager APIs
    b. desktop:
        - color picker
        - 

6. completare lavore di stilizzazione + keybinding coherency


# Urgent

1. The setting panel sounds:
    a. create a select UI element for sounds * OR DECIDE ANOTHER COOL SELECT SYSTEM BUT NO LIST OF TOGGLEABLE ELEMENTS IF ONLY 1 CAN BE SELECTED
    b. add a "System Sounds" inner section in the Theme section to setup all sounds (move those that exist for notifications and battery there, maybe duplicate them using the same logic so they stay updated?).

2. option to invert the scrolling direction (must not interfere with touchscreen)

3. hovering a tab should allow scrolling in that one without focus *

4. replace completely the "lava lamp" ambient effect with a configurable one exactly like this: https://github.com/AngelJumbo/lavat

5. Line separator in status bars should be using the full color and not a shade and be taller

6. WHEN TYPING IN A TERMINAL OR NVIM REMOVE THE CURSOR, REQUIRES INPUT TO RESTORE (AVOID MISCLICK ON TOUCHPAD, BUT ALLOW TOUCHSCREEN)

7. ~~network icons in the bottom status bar have different spacing than other icons. Also wifi/ethernet should be the rightmost.~~

8. Stats overlay:
    a. Disk usage should list all mounted disks
    b. 

9. ~~Touchscreen does not work on system modals~~

10. In the clipboard history preview panel the minimum width is not enough to fit the details. I should not have any minimal height. If the selected entry is an image it should have a greater minimum width then normal, and the content should be the image (with a limit, there should be a max height and the image must fit the area.

11. When running `phi theme set dark` if "Automatic" is set, it shold request confirmation to apply it, if so it disables the Auto mode

12. Move keybindings for status popups to FN.
    - status: fn+s
    - clipboard: fn+v
    - notifications: fn+n
    - phi agent: fn+p
    - etc.

13. 

# Codebase

1. Why color picker with Screenshot? Delete, it's a feature of the magnifier

# To be built

1. **Floating windows**: floating terminal windows should have a custom styling, that allows them to be grabbed for movement. This custom style has a lower area with the window name, used for grabbing. This is already existing in a wrapper for imv and should be abstracted. imv should not have it unless the window is actually floating.

2. **Weather Ambient Effect** (new lock screen ambient effect). It shows a terminal based animation for different weathers. Inspired by:
    - https://github.com/rmaake1/terminal-rain-lightning
    - 

3. **Dynamic wallpaper**: a custom wallpaper packing multiple images named with a convention that allows the system to change them based on the time of day, weather and season. The system should automatically read the folder "wallpapers/dynamic-wallpapers/" for folders (non empty), each folder is a dynamic wallpaper. Images inside will use a name convention to describe their daytime, weather, season metadata (or actual metadata if easy to setup but might need a custom extention). Wallpaper should transition at a given time of day (configurable), checking for date of the year (season) and current weather. One image should be set to default: when the computer uses "low power mode" (also called "battery saving") the dynamic wallpaper gets disabled and the currently active wallpaper stays active. however if the computer starts in low power mode (or the users logs out, or any reason hyprland starts without having a "last active wallpaper") the default one kicks in.
Some extra interesting ideas:
        - There could be a setting, for each dynamic wallpaper, to enable "blended fade" with a duration: this will slow down the transition in steps, making the changes between the images take a longer time
        - There could be a visual editor to edit/create dynamic wallpapers

4. Wallpaper grouping: in the settings, the wallpapers should be divided in groups. Groups are defined in the images names when recurring "filename.groupname.ext" or something similar but unambiguos OR just use folder (conflicts with dynamic-wallpapers).

4. New Lock Screen: TBD
Features:
    - spacebar to unlock (so not fixed on password input)
    - lock/unlock animation
    - Greetings message
    - validation effects
    - Battery status (if available)
    - new notifications
    - AUDIO REACTIVE AMBIENT EFFECTS? Or more simply some audio reactive thing in the lock screen. Maybe media controls?
    - face/touch checking state animations
    - power options
Inspirations:
    - https://unixporn-dots.github.io/assets/dotfiles/rklyz_dotfiles/thumbnail.png
    - 

5. Settings profiles: allow to quickly change between multiple settings profile (eg. Home, Work, School) to quickly change wallpaper, theme, settings, etc.

6. Must create the custom apps:
    - Notes *
    - Music client *
    - Media Centre client

# Style things

1. Terminal: "header", autocompletion

2. Librefox:
    - https://www.reddit.com/r/unixporn/comments/1dl1xzx/oc_shyfox_theme_for_firefox_i_made/
    - 

3. The settings panel should be a floating window with minimum width, not a locking overlay in the centre

4. 


# Reminders

1. VLC: to be considered for advanced codec
2. WiVRn
3. LocalSend / Shared Clipboard / Handoff
4. Cloud File Manager

# Older notes

## Settings

1. Add an "interactive index" panel that appears on the right side of the settings panel with some spacing, aligned with the top of the content body, showing the mapped inner sections. Active section has an "highlighter" effect. Inactive sections have an hover effect (opacity). They automatically change as the screen scrolls and can be clicked to activate them and scroll to position. It should work with the searchbar feature already existing. Make it easy to configure which panels have it and normalise how sections are mapped. Currently only sections Theme, Connectivity and Devices use it.

## General 

Those are some general reworks for the whole system or specific elements of it.

### Style

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
    d. the "phi" glyph in the runner changes to a corresponding glyph associated with the tag. Have it change with a transition, and using the tag's color

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

### Features

1. The notifications don't seem to work correctly. There's probably a lot of dead code and changes done in time as various issues are cumulating. Clear up the notification logic as much as possible in order to have a very clean and linear setup.
    a. no warn prompt confirmation when clearing notifications
    b. clearing notification (single, group, all, it does not matter) seems to logically clear the notifications but not visually. They stays in the overlay panel even when closed. Restarting hyprland or quickshell actually updates the notifications
    c. when receiving a notifications the popup appears only the first time
    d. clicking a notification should open the source window (if any) or activate their custom behaviour if set.

2. There is a lot of informative text in the UI that should be removed. While some descriptions are useful to understand what an option does, there are many texts that are clearly AI artefacts made to describe the features from the prompt, those need to go away. Text that is written as reminder for a feature to be implemented or completed should stay (and make them use warning color)

3. the trackpad does not have any "smooth scrolling" while the touchpad actually does (what i mean by smooth scroll is the effect that makes the scrolling last a bit longer then the actual end of the input, with velocity-based alterations). Be careful: i only want the smooth scrolling where the touchpad uses it. For example if i use the touchpad on librewolf i get the smooth scrolling while if i use the touchpad i don't, however on nvim (or terminal in general i guess) the touchpad does not scroll and thus i don't want the touchpad to have extra scrolling that would feel un-naturla. Be sure to apply the effect only for thoss


