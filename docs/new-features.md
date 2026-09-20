Those are new interesting features to add.

# Next steps

1. optimise code and remove redundancy
    - overview -> AppSwitcher
    - optimise shells
        - cleanup Dialogs
        - cleanup Popout
        - wallapaper è giusto come background? Thunar ha l'opzione "set wallpaper" che non va in quel caso.
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
    - cursor spotlight (borders)
    - touchpad on restart
    - hibernate freeze before turning off
    - chroma implementations

5. ultime features:
    a. server:
        - cloud file manager
        - indexing (movies + series + music)
        - git remote manager APIs
    b. desktop:
        - media fn keys
        - color picker
        - tilings !!!
            - floating windows (wrapper con grab area?) !!!
        - extra-packages manager (AppImage, repos, AUR?, npm, flatpack, etc.)
    c. extras
        - WiVRn
        - LocalSend / handhoff / shared clipboard

6. completare lavore di stilizzazione + keybinding coherency
    a. stile:
        - infatuation color code
        - Thunar
        - librefox
        - plymouth + tty
    b. keybinding
        - fn usage ?


# Required settings

- option to invert the scrolling direction (must not interfere with touchscreen)

- User informations:
    - user informations (editable field only on those that are safe to change)
    - user image
    - password change (using system dialogue, with animated live validation)

# Style directives

- librefox: https://www.reddit.com/r/unixporn/comments/1dl1xzx/oc_shyfox_theme_for_firefox_i_made/

- terminal: addd "header" and autocompletion

- Select (dropdown menu) widget missing, it should be used for single-option items in the settings panel (eg. sounds). build it to allow multi-selection dropdown as well.

- in all panels there are a lot of informative text that should be just removed. Consider where it is actually important to instruct about an option or a state and make that status text minimal and clear (much is obvious ai work artifacts). If some text informs about TODOs or placeholder leave theme but make them use a warn coloring

- Line separator in status bars should be using the full color and not a shade and be taller

- stats popout
    - put the disk usage in the usage section
    - the temperature should use dotted bars and have cpu and gpu inverted in direction (look at btop for reference)

- the speedtest element should use bars * check reference (btop dottet bars as well)

- system modal: rework *

- notification popout:
    - group by time ranges first...
        - ...then group by source
    - clicking should open source and delete

- notification toast:
    - x button to close
    - click clears it and opens source
    - 2 finger swipe closes it
    - quick animation:
        - first the icon
        - then the text with expansion
        - in and out animations
        - on-screen timing configurable

- runner bar:
    - add color and glyph property to "tags" (by tag i mean the words that activate a custom ranking like "app", "file", "ask", "web", "phi", "run", "yt", "wiki", "arch", etc.). When a tag gets activated:
        - tag in the runner gets highlighted with the color
        - runner bar transition color
        - phi glyph changes with transition
        - when a tag is active, deleting will stop before the tag. To delete the tag double click of backspace is required (or first "selects" it * )
    - runner bar text can go out of bound. While normally on 1 line, if the "ask" tag is active, the field extends vertically while typing to fit the content (vertical scrolling at a limit)

- thunar customisations don't work

- AppSwitcher: 
    - selection is undistinguishable
    - workspaces should be larger, have a background, clear selection state, list their windows as small icons
    - windows should be... * change/add behavior to MacOS overview ?

- Switch
    - on/off sate should have the same opacity (be sure to use different colors, to make obvious the state: thumb and borders can't change color)
    - opacity is used for disabled state
    - remove delay between color changing and thumb movement
    - hover thumb transition
    - add (if missing) the Label element, that automatically focuses the related switch (or input) both with hover and activation and has pointer cursor
        - integrate everywhere (spacing should be kept as it is everywhere)

- scratchpad should slide in/out on the bottom

- many informative elements (especially in the settings and popout) have hover effect and pointer cursor but not click interaction

- NetworkPopout
    - speedtest graph should be visible on ethernet as well (as long as there is internet connection)
    - should use dotted bar graph, not lines (eg. reference to btop graphs)

- Button * TBD

- Lock Screen:
    - https://unixporn-dots.github.io/assets/dotfiles/rklyz_dotfiles/thumbnail.png 
    - state pre-input: mouse/keyboard input to enable password
    - improve
        - validation animations
        - lock/unlock transition
        - screensave effects

- ScreenSavers
    - Lava lamp: complete rework (current one is completely wrong and must be deleted): https://github.com/AngelJumbo/lavat
    - Improve customisable property for existing screensavers

# Known bugs

- In the MediaControls
    - the title "marquee" does not slowly move, it's instant and stuck at the end 
    - shows the title twice: title, author+title instead it should show author+album in the second row

- when hibernating the laptop, touchpad does not always come back (touchscreen always works)

- hovering a tab should allow scrolling in that one without focus *

- the stats popout only shows 1 mounted disk

- systems modal:
    - touchscreen does not work
    - tab cycles + enter/space selection

- When running `phi theme set dark` if "Automatic" is set, it shold request confirmation to apply it, if so it disables the Auto mode

- NotificationPopout
    - clearing notifications still does not delete them visually
    - remove confirm dialog on clearing notifications
    - the toast seems to appear only on the first notification per session (not sure on the pattern, definetly not at each notification)

- AppSwitcher:
    - clickable area is only the icon
    - releasing the alt key should trigger the selection
    - changing workspace (3 finger swipe) should react in the appswitcher (changes selected workspace and selected window, following system focus)

- SpeedTest: still returns unreliable values. It should measure internet speed, not local speed. It should not be capped.

- Dynamic Wallpaper: there is no transition on change.

- ClipboardPopout
    - right click context menu shows an empty option and is a square with no content (padding-only). not selectable. It should have options: delete, copy, pin/unpin

# Additions

- add smooth scrolling with touchpad in the shells. Touchscreen (and mouse drag) already work like that. With the scrollwheel leave it as it is (write a comment about it, will decide in time how to handle it)

- Add an "interactive index" panel that appears on the right side of the settings panel with some spacing, aligned with the top of the content body, showing the mapped inner sections. Active section has an "highlighter" effect. Inactive sections have an hover effect (opacity). They automatically change as the screen scrolls and can be clicked to activate them and scroll to position. It should work with the searchbar feature already existing. Make it easy to configure which panels have it and normalise how sections are mapped. Currently only sections Theme, Connectivity and Devices use it.

- draggable window wrapper: a wrapper for floating windows (eg. currently used as an imv wrapper, can be used for general floating windows or other processes)
    - small padding LTR
    - header bottom: app title + draggable area (grab cursor) + extra content passed as property

- add "Quick Note" feature:
    - HotCorner shell item:
        - can be set at anchors and has a callback. The quick not hot corner will be on the right bottom (screen corner, regardless of the status bar)
        - on hover it show a little square expanding to hint the interaction
        - not visible until hovered, 0px (or 1px if 0 does not work)
    - on activation:
        - opens a nvim-notes the latest file in the phios/quick_notes/ folder
        - the view is wrapped in the draggable floating window, in the header a button "new" and a select to switch notes from folder
        - new notes are created as timestamp_customName where customName is the first line or word

- Music Client

- Media Centre Client


# Nice to have

- Settings/Theme profiles (home/work/school)

- Weather app: 

- New ScreenSaver: weather terminal
    - Storm example: https://github.com/rmaake1/terminal-rain-lightning


- WHEN TYPING IN A TERMINAL OR NVIM REMOVE THE CURSOR, REQUIRES INPUT TO RESTORE (AVOID MISCLICK ON TOUCHPAD, BUT ALLOW TOUCHSCREEN)

- Move keybindings for status popups to FN.
    - status: fn+s
    - clipboard: fn+v
    - notifications: fn+n
    - phi agent: fn+p
    - etc.