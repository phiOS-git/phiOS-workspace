Those are new interesting features to add.

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
