# Investigation Notes

Detailed research, hardware measurements, and dead ends behind specific
`docs/TODO.md` entries — split out here so that file stays quick to scan.
Each section below is the full record for one entry; the condensed bullet
in `docs/TODO.md` links to it by anchor. When an entry is finished and
moves to `VERIFICATION.md`, delete its section here too — this file should
only ever hold notes for entries still open in `docs/TODO.md`.

## idle-timeout-after-hibernation

**Entry:** after hibernation, the screen automatically suspends after 1
minute, which is not the normal behavior (it should take longer).

Investigated 2026-09-11: searched all of `phios-dotfiles` for anything that
could set an idle-timeout/auto-lock/DPMS policy (`grep -rl
"idle\|suspend\|hibernate\|sleep"`). Found only
`profiles/laptop/system/etc/systemd/logind.conf.d/10-lid.conf`
(`HandleLidSwitch`/`HandleSuspendKey` — LID CLOSE and the physical suspend
key, unrelated to an idle *timeout*) and `hypridle` listed in
`profiles/desktop/packages.txt` with an explicit comment that its config is
"deferred" — **no `hypridle.conf` (or any other idle-timeout config) exists
anywhere in this repository, committed or templated.** So this project sets
no idle-timeout policy at all; the observed "suspends after 1 minute
post-hibernation" cannot be something `phios-dotfiles` configures, since
there's nothing here to misconfigure. Did not attempt a guess-based fix.

Next time this happens, on the real machine (not from this repo):
`systemctl --user status hypridle` (is it even running, and does
`~/.config/hypr/hypridle.conf` exist there outside the repo — if hypridle
IS running with some config, where did it come from), `loginctl
show-session $(loginctl | grep $(whoami) | awk '{print $1}')` (an
`IdleActionUSec` or similar systemd-logind-level timeout, separate from
hypridle entirely), and specifically whether the 1-minute timer only starts
counting fresh right after a hibernation *resume* (a session/idle-timer
reset on wake, which would point at a resume-hook or systemd-logind
interaction rather than a normal idle timeout misconfiguration) versus
being the ordinary idle timeout just being reached faster than expected
around the same time as a hibernation resume.

## ai-agent-a1-fails-to-start

**Entry:** the ai agent a1 always fails starting. Running `phi agent
broker —instance a1` shows it binds it correctly on "127.0.0.1:8789"
(after the second time it shows the address occupied).

Investigated 2026-09-11: read `phi/internal/agent/broker.go` (bind/shutdown
logic looks correct, no stale-socket handling gap for TCP),
`phi/internal/cli/agent.go` (SIGINT/SIGTERM → graceful `srv.Shutdown`,
looks correct), `phi-shell/Services/Agent.qml` (only ever issues one
`systemctl start phi-agent-a1.service`, guarded against re-entrancy), and
`phi-agent-broker@.service`/`phi-agent-a1.service` (no code bug found, but
`Type=simple` with no readiness sync between the broker binding its socket
and `phi-agent-a1.service` starting is a plausible source of a *different*
failure mode — connection-refused, not the reported address-in-use). Could
not find a concrete code defect, and did not want to guess at a fix to the
credential-broker's systemd unit without being able to observe the actual
failure — this needs the real machine.

Running `ss -ltnp | grep 8789` and `systemctl --user status
phi-agent-broker@a1.service` shows the service active and the server open:
check ai-agent.output for the log. However the chat panel does not work
"phi-agent-a1.service is not running, or the containment failed to start.
Nothing runs outside the containment". Running `phi agent code .` opens the
opencode session but it keeps showing an error "socat[64] E connect(,
AF=1 \"run/phi-agent/net/proxy.sock\", 31): No such file or directory" and
opencode does not work. opencode normally works. The entire AI feature must
be debugged and corrected (and the UI must be changed, see the Style
section).

## screenshot-area-selection-offset

**Entry:** area selection in screenshot, OCR and QR reading is never
right. The offset changes as the size and position of the area change.

Investigated 2026-09-11: all three modes (save/OCR/QR) already share ONE
selection code path in `phi-shell/Screenshot/Screenshot.qml` (`onReleased`
→ `_captureGeometry` → `_doCaptureGeometry`, differing only in what runs on
the resulting PNG afterwards — `tesseract`/`zbarimg`/clipboard-copy), so
there's no separate bug surface between them; a fix to the shared geometry
math fixes all three identically. That shared math already carries a prior
hardware-verified fix (commit `df4298d`) for offset growing with the
SELECTED AREA'S POSITION on a multi-monitor layout — confirmed against
grim's own source (`github.com/emersion/grim`, `render.c`) that grim wants
the `-g` box in logical (not physical/scaled) coordinates, which
`root.screen.x/y + selectionRect.x/y` already is. Read the current formula
carefully for a SEPARATE bug where offset grows with the selected area's
SIZE (not position) specifically, since that's what this entry says and
df4298d's own comment only discusses the position case: found no mechanism
for it — x/y and width/height are computed and rounded completely
independently in `onReleased`, so width/height cannot mathematically feed
back into the reported x/y in the current code. Could not reproduce or
measure on real hardware to find whatever mechanism does exist. Next time
this happens: get exact numbers — the logical selection rect drawn on
screen (x, y, width, height, and which monitor / its `scale`) vs. the
actual crop `file --brief` or `identify` reports for the resulting PNG,
ideally for one small and one large selection on the same monitor — so a
real size-correlated formula (if one exists) can be isolated instead of
guessed at.

**Measured live 2026-09-14, on zotac** (with the user's agreement to a
brief, fully-reverted monitor-scale change for this test only — restored
immediately after, confirmed back to normal). Not a code bug at all, in
`Screenshot.qml` or in `grim`'s own geometry math: **at the monitor's
normal integer scale (1x), `grim -g` is byte-for-byte, pixel-perfect
position-correct at every size tested** (50×50 up to 1800×950, round and
irregular origins, on a fully static wallpaper-only background to rule out
on-screen animation as a confound) — confirmed by cropping the identical
region out of a plain full-screen capture with ImageMagick and diffing
pixel-for-pixel: zero difference, every time. This directly confirms the
2026-09-11 note's own reading of the code (x/y and width/height really
don't interact) and extends it from "no mechanism found by reading" to "no
mechanism found by measuring, at scale 1."

Temporarily forced the same monitor to a fractional scale (1.25×, matching
what a laptop like `razer` commonly runs and zotac's own desktop monitor
does not) and reran the identical test: **a small selection (50×50
logical) was still pixel-perfect, but every larger selection showed a
real, nonzero, size-correlated pixel mismatch** (large 800×600: 2.3% of
pixels differ; a 1500×900 near-full-screen selection: 8.1%) — this is
genuinely new, measured evidence, not a guess, and it reproduces the
reported pattern (worse as the area grows) for the first time in this
project's history on this bug.

It is NOT a coordinate/offset bug even so: shifted the comparison's crop
origin by every combination of ±1/±2 pixels in x and y and reran the diff
at each — no shift ever reduces the mismatch below the unshifted value,
and every shift makes it WORSE. A true "off by N pixels" bug would show a
large IMPROVEMENT at the correct shift; this shows none, which rules that
mechanism out cleanly. Went one step further to isolate WHERE the noise
comes from: took two independent PLAIN FULL-SCREEN `grim` captures (no
`-g`, no crop, no phi-shell code involved at all) back to back, of the
same static wallpaper, still at 1.25× scale — **they were not byte-identical
either** (2% of the full 1920×1080 frame differs between two consecutive
whole-screen captures of unchanging content). That rules out
`Screenshot.qml`'s geometry AND grim's `-g` handling specifically as the
source: the noise is present in a bare `grim` full-screen capture with no
sub-region logic involved anywhere. This reads as the compositor or GPU
driver applying some form of dithering/resampling noise to the output
buffer specifically when the monitor scale is fractional (a common
technique to avoid visible colour-banding under non-integer scaling) —
regenerated differently on every captured frame, which would corrupt
OCR/QR decoding (needs crisp, consistent pixel values) far more than it
would visibly bother a human looking at a "save" screenshot, plausibly
explaining why this reads as "OCR/QR reading is never right" specifically
rather than "screenshots look wrong."

No fix identified — this can't be fixed in `Screenshot.qml`, since the
noise reproduces in a bare `grim` call with zero phi-shell code involved.
If it's real on `razer` (this was only tested on zotac's desktop monitor,
forced to a fractional scale it doesn't normally run — a real confirmation
needs `razer`'s own actual, currently-configured scale factor,
`hyprctl monitors -j`'s `scale` field), the fix would have to be
compositor/driver-side (a Hyprland setting disabling this dithering for
screencopy clients specifically, if one exists — not searched for this
session) or a phi-shell-side mitigation (e.g. averaging several captures to
cancel random per-frame noise, expensive for a live screenshot tool, and
unverified to even work if the dither isn't independent between frames).
Next time this happens: confirm `razer`'s actual monitor scale first (if
it's already an integer, this whole theory is wrong and the mismatch must
be something else entirely); if fractional, this note's own measurement
method (two full-screen captures diffed, no phi-shell involved) is the
fastest way to confirm the same effect exists there before looking for a
fix.

## neovim-chroma-per-key-integration

**Entry:** improve the neovim chroma integration, with as many mappings
as possible. When I press a key only valid options in the keyboard should
be backlit, with color codes to understand the nature of the command (eg.
if I press "g" I should have the numbers in a color, the g in another
color, and so on). Currently the colors change smoothly, in this
integration it should be instant instead.

Investigated 2026-09-14: the main ask ("only valid options... backlit,
with colour codes... numbers in a colour, the pressed key in another")
needs several keys lit in different colours at once — inherently per-key,
not the single whole-keyboard tint the current integration does
(`profiles/base/home/.config/nvim/lua/phi_chroma.lua` sends only one mode
letter; `phi-shell/Services/Chroma.qml`'s `setNvimMode`/`_nvimColor` push
one `setStatic` colour for the whole keyboard). `Chroma.qml` does have a
real per-key path already (`advanced`/`keyOverrides`, `setKeyRow`/
`setCustom`, the `Widgets/KeyboardMap` grid) — so the primitive exists —
but every key it addresses is keyed by matrix `(row, col)`, and the file's
own header is explicit that those coordinates have no known mapping to
physical keys anywhere in this repo: "the user reads their real values off
the KeyboardMap grid" — i.e. discovering which `(row, col)` is the "g"
key, which are the number-row keys, and so on for every key this feature
would need, is a one-at-a-time manual real-hardware task with no shortcut.
Building "as many mappings as possible" needs that whole table first, and
it can only be built on the real keyboard.

Deeper problem underneath that: **the `org.razer` DBus service this
entire file talks to has never been reachable from any environment this
project has run in** (`Chroma.qml`'s own header, unchanged since S-46: "no
org.razer service is reachable from this machine to call, so this file has
never run"). Every existing Chroma feature — including the neovim
integration already shipped — was written against openrazer's documented
DBus API and the user's own confirmation it works on this Razer Blade,
never actually exercised here. A change this large, on a surface with zero
verified working history, isn't something to extend blind.

The "instant not smooth" clause specifically: read the whole file for any
colour transition — there is none. Every mode change calls `_render()`,
which composes one `setStatic`/`setKeyRow`+`setCustom` frame and pushes it
via one synchronous `busctl` call; no `Behavior`, `ColorAnimation`, or
software-side fade exists anywhere in `Chroma.qml`. If the colour
genuinely fades on a real keyboard, that's the Chroma firmware's own
transition effect, not this code — fixable only via whatever DBus method
(if any) openrazer exposes for transition style, which needs the same
real, currently-unreachable service to find and test.

Next time this happens: on the real machine, confirm `org.razer` is
actually reachable (`busctl --user introspect org.razer
/org/razer/device/<serial>` — this alone has never been confirmed
possible from this project), then use `Widgets/KeyboardMap`'s existing
per-key picker to build a real key-name → `(row, col)` table for at least
the keys this feature needs (letters, digits, common modifiers) before any
mapping logic can be written.

## status-bar-not-appearing-in-fullscreen

**Entry:** when in full screen, the status bar does not appear by moving
the cursor on the top edge.

Investigated 2026-09-14: `Bar/Bar.qml`'s own `autoHidden`/`hoverHandler`
mechanism (fullscreen auto-hide + edge-reveal) looks structurally sound by
reading alone — the window's own geometry never shrinks, only
`exclusiveZone` and `barContent`'s internal `y` change, so a `HoverHandler`
at the very top of the screen should in principle still see the pointer.
The file's own comment asserts this ("hoverHandler below can still catch a
pointer at the very top of the screen even while hidden") but nothing in
the file or VERIFICATION.md history marks that claim as
hardware-confirmed.

Checked whether this is the same root-cause class as the bar-popout
positioning bug just fixed (an `exclusiveZone`/layer issue) — it is not a
simple one-line fix this time. Real, current research against Hyprland's
own GitHub (not recalled, fetched 2026-09-14) found this exact area — how
a `Top`-layer surface like a status bar interacts with a fullscreen window
above it — is genuinely unsettled upstream:
[hyprwm/Hyprland#15937](https://github.com/hyprwm/Hyprland/pull/15937),
still in **draft**, not merged as of 2026-09-12, is actively changing
whether newly-spawned `Top`-layer surfaces render above or below a
fullscreen window, and the maintainers' own discussion on that PR is still
going back and forth on the default. That means even the CURRENT,
released Hyprland's behavior here — whichever version is actually
installed on `razer` — cannot be pinned down from source reading alone; it
depends on a version that isn't recorded anywhere in this repo.

The one plausible code fix considered — moving `Bar.qml` onto
`WlrLayer.Overlay` (Quickshell's topmost layer, the same one
`Settings`/`Sidebar`/`Launcher`/`AltTab`/`Cheatsheet`/`Screenshot`/
`AgentPanel`/`ConfirmDialog` all already use specifically so their own
dimming scrim can cover the bar) — was deliberately NOT made: every one of
those other surfaces relies on being ABOVE the bar in z-order for that
scrim-covers-the-bar behavior, and z-order WITHIN one layer (as opposed to
between layers) is not something this session can predict or verify
without a compositor. Bumping the bar to the same layer those surfaces
already occupy risks a new, different regression (the bar rendering on
top of a scrim meant to cover it) in exchange for an unconfirmed fix to
this one. Not worth the risk blind. Next time this happens: confirm the
installed Hyprland version (`hyprctl version`) and check whether #15937
(or whatever it becomes) has landed in it — that determines whether this
is stock Hyprland behavior needing a
`misc:allow_new_top_layers_over_existing_fullscreen`-style config line in
`hyprland.lua.tmpl`, or a phi-shell-side layer issue after all.

## network-speed-graph-wrong-numbers

**Entry:** the network speed graph (settings + bar overlay) does not
show real numbers: it's always around 1Kb/s both upload and download.
Also make it visually match the reference more better:
https://github.com/programmersd21/flow

Investigated 2026-09-13: `Services/NetStats.qml` is the single source both
the settings-panel graph and the bar-overlay graph read from
(`Settings/sections/Connectivity.qml`, `Panels/BarPopout.qml`), so this and
the sibling "wifi speed graph" entry are one bug, not two. A prior session
already found and fixed one real defect here (commit `f5915a7`;
VERIFICATION.md's own now-deleted "fixed a real under-reporting bug, but...
may not be fully resolved" entry): the rate math trusted the poll `Timer`
landing exactly 1000ms after the last sample, replaced with a real
`Date.now()`-measured elapsed time. This bug report is dated after that
fix, so it's a fresh report that fix did not resolve. Re-checked the two
obvious follow-on suspects and ruled both out by reading: (1) `/proc/net/dev`
field parsing — `parts[1]` = rx_bytes, `parts[9]` = tx_bytes is correct per
the kernel's own field layout (8 receive fields precede transmit); (2) the
Quickshell Process-respawn landmine this file's own header calls out
(`Services/Tailscale.qml`'s documented `Process.onFinished` unconditional
re-arm) — `devProc`/`pingProc`/`routeProc` here all already set `running =
false` in `onExited`, the same guard `Tailscale.qml`'s own `probe` uses, so
that tight-loop failure mode shouldn't apply here either. `_fmtRate()`'s
kb/s-vs-Mb/s threshold and rounding, in both consumer files, is also
correct by inspection.

One real, unverified candidate: `NetStats.qml` resolves which interface to
measure via `ip route show default`'s device — the DEFAULT ROUTE's
interface, not necessarily the physical Wi-Fi NIC. If the machine has a
full-tunnel VPN up (`phi vpn up`) or a Tailscale exit node enabled, the
default route points at that tunnel interface instead, whose own
idle/control-plane traffic is small and roughly constant — which would
look exactly like this report (a small, stable number regardless of real
link speed) with the rate math never being wrong at all. Nothing in this
repository configures either state (WireGuard tunnels and Tailscale
exit-node state are both runtime-only, outside every repo), so this can't
be confirmed or ruled out from source. Next time this happens: on the
affected machine, run `ip route show default` while reproducing the bug —
does it name the real NIC (`wlan0`/`wlp*`) or a tunnel (`wg0`/
`tailscale0`)? — and compare against the same command with any VPN down
and any Tailscale exit node off.

**Measured live 2026-09-14 on zotac** (ethernet-only, no Wi-Fi hardware to
test the sibling "wifi speed graph" entry specifically, but the same
`NetStats.qml` singleton and formula either way): bracketed a real 10 MB
HTTP download with `/proc/net/dev`'s own `enp7s0` rx-byte counter, read
before and after, and ran the exact `NetStats.qml` formula (`(Δbytes × 8 /
1000) / Δseconds`) against the real measured delta — **5.89 Mbps**,
against curl's own reported **5.61 Mbps** for the same transfer. The small
gap is in the expected direction and size (the raw interface counter
includes IP/TCP header overhead curl's payload-only `speed_download`
metric doesn't count) — this is a clean, real-traffic confirmation that
the rate math itself is correct, on top of the 2026-09-13 note's
code-reading conclusion. `ip route show default` on zotac right now names
the real NIC (`enp7s0`), no VPN or Tailscale exit node up, so the one
still-unconfirmed candidate (a tunnel silently owning the default route)
could not be tested here — zotac has neither configured. Still the most
likely explanation left standing; still needs checking on whichever host
actually reproduces this, mid-bug, exactly as the note above already
asks.

## zsh-black-on-black-directory

**Entry:** zsh in dark theme has the directory in black on black.

Investigated 2026-09-13: traced the whole pipeline end to end and found no
defect anywhere in it. Built `phi` and ran the *real* renderer against the
*real* dark tokens (`phi theme render --variant dark
profiles/base/templates/.config/zsh/theme.zsh.tmpl`), which produces
`PROMPT='%F{#d3a0ac}%n@%m%f %F{#d6d1c9}%~%f %# '` — `%~` (the directory)
is `#d6d1c9`, `PHI_FG_0` dark, a light cream, never black in any commit of
`design/tokens.dark.sh` (checked `ac8b04e`, `b97f3f4`, `08eb32d`). Fed
that exact rendered `PROMPT=` line to a real zsh 5.9 and printed it
(`print -P "$PROMPT"` piped through `cat -v`): it emits
`\e[38;2;214;209;201m` for the directory segment, the correct 24-bit
truecolor escape for `#d6d1c9`, not black. The Go substitution
(`internal/theme/render.go`'s `variableRef`/`Substitute`,
`internal/tokens/tokens.go`'s `tokenLine`) has no name-boundary bug —
`PHI_FG_0`'s trailing digit matches fine, same code path as `PHI_ACCENT`
which is not reported broken. No `LS_COLORS`/`dircolors`/`eza`/`zstyle
list-colors` config exists anywhere in this repo (ruled out the
completion-menu and `ls`-output surfaces entirely), no prompt framework
(starship/oh-my-zsh/etc.) is installed, and `theme.zsh` is a real,
declared `design/adapters.txt` row (class C, correctly sourced
unconditionally from `.zshrc`).

One genuinely new fact worth keeping: zsh's `%F{}` prompt escape is NOT
forgiving of an empty argument — `%F{}` (empty color name) renders as
literal ANSI black (`\e[30m`), while `%F{garbage}` (an unrecognized name)
safely resets to default (`\e[39m`). So **only a wholesale-empty
substitution produces black**, and this project's renderer is confirmed,
by the real end-to-end test above, not to produce one for this template.
This gives one sharp discriminating question for next time it happens: is
the accent-coloured `%n@%m` segment ALSO black, or only `%~`? If both are
black, something is stripping the whole `PROMPT` value at runtime (not
this template); if only the directory is black, the rendered file on disk
is not what this repo's renderer produces, and something downstream
(stale `~/.config/zsh/theme.zsh` from before a token fix, or a
`zsh/nearcolor` module loaded by an `/etc/zsh/zshenv` or
`/etc/profile.d/` global rc outside this repo — `zmodload -L | grep
nearcolor` on the affected machine turned this exact hex into `\e[39m`
default-not-black in one quick test here, so it's a live but unconfirmed
candidate) is overriding it. Next time this happens, on the real machine:
`cat ~/.config/zsh/theme.zsh` (does the ON-DISK file actually hold
`#d6d1c9`, or is it stale/truncated — this one check resolves most of the
remaining uncertainty), `zmodload -L | grep nearcolor`, `echo $TERM`, and
whether it reproduces outside kitty (e.g. in the Linux VT or over SSH from
another machine).

**Checked live 2026-09-14 on zotac** (the same real-machine checks this
note already asked for, now actually run rather than deferred):
`~/.config/zsh/theme.zsh` on disk holds exactly `PROMPT='%F{#d3a0ac}%n@%m
%f %F{#d6d1c9}%~%f %# '` — not stale, matches the renderer's own output.
`zmodload -L | grep nearcolor` returns nothing (module not loaded).
`print -P "$PROMPT"` inside a real interactive shell (confirmed by its own
process tree: `kitty → zsh` is a direct parent, this genuinely is a kitty
pane, not a bare terminal) emits `\e[38;2;211;160;172m` for the accent
segment and `\e[38;2;214;209;201m` for the directory — both correct 24-bit
truecolor, neither black. **Does not reproduce on zotac.** This doesn't
close the entry — the report may be `razer`-specific (a different
`/etc/profile.d/`, a different kitty version, or something else host-local
that isn't in any repo) — but it does rule out zotac as a second site
where this happens, and confirms every one of the 2026-09-13 predictions
held on a real machine, not just in theory.

## scratchpad-bar-icon-no-visual-state

**Entry:** the scratchpad bar icon has no visual "shown" state — it
always looks the same whether the scratchpad is currently visible or not,
regardless of how it was opened (the icon, or MOD+A).

`Bar/modules/Workspaces.qml`'s own header comment records this as a
deliberate choice (ADR 134): a numbered workspace and the special one can
both read as "active" at once, so a lit toggle sharing that same `active`
state would lie half the time — not an oversight, a considered decision
made when this looked technically impossible to do correctly.

It may not be impossible anymore: confirmed against current Hyprland
source (`hyprwm/Hyprland`, `src/ipc/s1/Commands.cpp`'s `getMonitorData`
and `src/workspace/SpecialWorkspace.cpp`'s `create()`) that `hyprctl
monitors -j` includes, per monitor, `"specialWorkspace": {"name": "..."}`
— exactly `"special:scratch"` when the scratchpad is shown on that
monitor, `""` when it is not. This is a source the current Quickshell-IPC-
only tracking never used; it comes from a plain `hyprctl` subprocess poll,
the same established pattern already used elsewhere in this repo
(`AltTab/AltTab.qml`, `Screenshot/Screenshot.qml`,
`Services/Keybinds.qml`) for exactly this class of state Quickshell's own
Hyprland module cannot read.

## spotlight-cursor-super-super

**Entry:** spotlight cursor: super+super (double tap hold) — blocked by
issue on Hyprland 0.56, check if fixed.

Rechecked 2026-09-14: still broken, not something this project can fix.
The current latest Hyprland release is still v0.56.2 (published
2026-08-05, no newer release exists as of this check), and a 2026-08-17
comment on `hyprwm/Hyprland#6946` — testing a plain keysym bind, the
documented "modifier tap" pattern, and a raw keycode bind, all against
0.56.2 — confirms release events never fire for a bare-modifier-only key:
press is delivered, release is not, across every variant tried. This is
the same finding `phios-dotfiles`' own `hyprland.lua.tmpl` already
documents in its "ROUND SIX" comment (commit `48d0a16c`, 2026-09-09),
which is why the cursor-spotlight hold gesture is bound to SUPER+G (an
ordinary key, reliably delivered both ways) rather than bare Super — that
revert is already shipped and is the correct, working shape; nothing
about it needs to change.

**A trap for the next recheck:** `#6946` shows as *closed*, and a
separate, unrelated issue (`#6946`'s bot-closed sibling
`hyprwm/Hyprland#15952`, about `Control_R` rather than Super) asserts in
its own body that "#6946 was closed after a targeted fix" — that claim is
the `#15952` reporter's own unverified inference from the closed state,
not something they tested, and it is directly contradicted by the newer,
rigorously-tested 2026-08-17 comment sitting on `#6946` itself. Checking
only whether `#6946` is closed, or only `#15952`'s text, will wrongly
conclude this is fixed — read `#6946`'s actual latest comments instead.

The only known alternative that does receive both press and release for a
bare modifier is an app grabbing `/dev/input/eventN` directly via evdev,
bypassing Hyprland's own bind dispatch entirely (named in that same
2026-08-17 comment). Not pursued: it would mean a new raw-input-device
dependency and a very different architecture from `phi-shell`'s existing
IPC-from-Hyprland model, for one gesture — a much bigger trade than this
entry asks for. Nothing to recheck again until a Hyprland release newer
than v0.56.2 ships.

## gesture-open-chat-notification-panel

**Entry:** add gestures to open the chat and notifications panel: 2
finger swipe from edge (touchpad). Make the inverted gesture to close the
panel as well. It should move progressively with the scroll, not only a
toggable state.

Investigated 2026-09-14: the "moves progressively with the scroll" half is
genuinely buildable — real, current research (fetched today, not
recalled) against Hyprland's own wiki source confirms `hl.gesture()`
supports "live" gestures: pass a table with `start`/`update`/`finish`
methods instead of a function, and `update` receives a real per-event
`delta.x`/`delta.y` (a working example in the wiki is a live-adjusted
volume gesture using exactly this shape). Forwarding every `update` event
as its own `qs ipc call` (this project's only IPC mechanism, one process
spawned per call) would be tens of calls a second during a swipe — but
that's not a hard blocker: accumulating the delta in Lua and forwarding
only every ~5-10% of progress (a handful of IPC calls per swipe, phi-shell
animating between them with its own `Behavior`, the same interpolation
every other surface here already uses) keeps this smooth without flooding
anything.

**The literal "2 finger swipe" cannot be built, and this is a hard
technical wall, not a design choice:** libinput's own documentation
(wayland.freedesktop.org/libinput, fetched today) states plainly — "Swipe
gestures are executed when three or more fingers are moved synchronously
in the same direction." Two-finger synchronized movement is claimed by
libinput itself for scrolling before Hyprland's gesture layer ever sees it;
independent real-user reports researched today (a Hyprland forum thread
asking for exactly a 2-finger gesture) confirm the same experience on real
hardware. No Lua config in this repository, or anywhere else, can make a
2-finger swipe arrive as a gesture event — this is below the compositor,
in libinput itself. Also relevant: this file's existing three-finger
vertical swipe is already fully claimed in both directions by the
Alt+Tab/overview gesture (`hl.gesture({fingers=3, direction="up"/"down",
...})`, lines ~921-930) and horizontally by workspace-switching — there is
no free three-finger direction left to reuse for this feature either.
`hl.gesture()` also has no "starts from the screen edge" concept at all
(confirmed against the same wiki source) — gestures are
finger-count-and-direction only, with no starting-position awareness, so
"swipe from screen edge" as a distinct trigger (as opposed to "swipe" full
stop) is not implementable via this API either, only via finger count
and/or an added `mods` modifier mask.

## settings-switch-color-transition

**Entry:** the settings-panel switch's color transition still looks like
it finishes before the knob finishes sliding across.

Investigated 2026-09-13, in `Widgets/Toggle.qml`'s own header comment (not
previously copied here): every `Behavior` in the file (track colour, track
border colour, knob position, knob colour) already reads the identical
`motionBDuration`/`motionBCurve` pair — no mismatched token exists to
point at, and the file has exactly one commit in its history, so there's
no earlier version with a different value either. **Cause not diagnosed,
left as-is** — one theory noted but unverified (sRGB colour interpolation
often reads as "arrived" well before a `t=1` geometric move does, at the
same eased duration, since the last stretch of a colour lerp is a much
smaller perceived difference than the same stretch of physical motion).

Re-read 2026-09-14: agreed with the prior call not to guess at a fix here
— any change (extending just the colour Behaviors' duration, or giving
them a different easing shape) would be exactly as unverified as the
original diagnosis, since neither session can see the actual on-screen
timing, and rule 6 rules out inventing a new ad-hoc duration/curve outside
the motion-category token pairs anyway. The prior note's own
discriminating test still stands as the way to actually resolve this: on
real hardware, bump `motion-b-duration` in Theme settings (the animation
editor already exposes it live) and watch whether the colour still
finishes noticeably early at the new duration too — if the gap SCALES with
the duration, it's the perceptual theory above (and the fix would be
extending only the colour Behaviors, proportionally); if the colour keeps
finishing after a roughly FIXED, unscaled head start regardless of
duration, something else is going on and needs a fresh look.
