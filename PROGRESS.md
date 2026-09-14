# phiOS — progress

The single, current record of what phiOS is and where it stands. Updated in
the same commit as the change it describes. This replaces the old
step-by-step step log, which is kept for reference at
`docs/archive/phios-dotfiles-PROGRESS.md`.

---

## 1. What phiOS is

A personal Arch Linux desktop environment, built from scratch, running on
three machines:

| Host | Role | Hardware |
|---|---|---|
| `zotac` | Desktop, work + gaming | NVIDIA (open DKMS), 32 GB RAM, Btrfs+LUKS, two disks (root + `/mnt/bulk`) |
| `razer` | Laptop, primary machine — study, work, some gaming | Razer Book 13 (2020), Intel Iris Xe, IR camera, ambient-light sensor, per-key Chroma keyboard |
| `mini` | Headless server, support backend only | 4 GB RAM (soldered), `/srv` on an unlocked LUKS volume, no graphical session ever |

All three are installed and in daily use. The base OS (disk layout, boot,
drivers, Hyprland session, Tailscale, Steam, snapper) predates this
workspace and is not tracked here — only the phiOS layer on top is.

**Design language:** one accent (pastel pink `#d3a0ac`), base16-style
semantic tokens, mono + sans + symbol-only fonts (no patched fonts), a
bound motion taxonomy, and a single Φ identity mark. Two variants, dark and
light, switchable live. Every value comes from `phios-dotfiles/design/`.

**Guiding constraints:** TUI over GUI; every feature must name the problem
it solves; no colour or font hardcoded anywhere; `/etc` changes are kept
versioned but applied only by hand; nothing proprietary; one CLI entry
point (`phi`), one visual identity.

---

## 2. Status at a glance

| Area | State |
|---|---|
| Dotfiles foundation (installer, profiles, tokens, `/etc` boundary, capability detection) | **Working**, in daily use on all three hosts |
| `phi` CLI — theme, state, doctor, pkg, completions | **Working**, packaged, installed on all three hosts |
| `phi` CLI — vpn, firewall, wallpaper, query, update | **Built**, in use; some paths only exercised on `razer` |
| `phi-shell` — bar, session integration, Hyprland autostart | **Working** on `razer` and `zotac`, but a 2026-09-11 hardware verification round found real bugs still open: overlay panels sit lower than the bar, the scratchpad icon doesn't call the scratchpad, the bar doesn't reveal on a top-edge hover in fullscreen, touchscreen taps near an icon's top edge hover instead of activating — tracked in `docs/TODO.md` |
| `phi-shell` — panels, launcher, lock, overview, screenshot, notifications, settings, magnifier, OSD | **Built and in use**, refined over four restyle rounds + a settings overhaul + a multi-round 2026-09-14 expert UI/UX pass (cursor/hover affordance system-wide including drag surfaces, a shared tab-vs-button grammar, search clear buttons, a Settings "Advanced" toggle, a rebuilt clipboard tab, a lock-screen lockout, a two-intensity scrim that now also stays clear of the bar for the right surfaces, a loading-skeleton widget, a dead bar module reconnected to its real backend, several fully-built-but-never-wired capabilities — chat pin/rename/close, personality rename, AI Agent config edit/restart — actually wired up, free-text "type a name from memory" fields (sound, font) replaced with real pickers, missing Escape handling closed on four more surfaces, two destructive actions that bypassed confirmation now don't, the notification toast and the launcher's own result rows given real interaction for the first time, loading now reads visually distinct from disabled, a systemic keyboard-activation gap fixed across every shared widget and hand-rolled interactive region (Tab-focus existed but Enter/Space did nothing), Do Not Disturb's timed-session expiry fixed so it can no longer silently drift out of sync with its own persisted state, plus a live "time left" readout for a timed DND session, and Alt-Tab's "doesn't close on Alt release"/"doesn't start with the right window selected" symptoms turned out to already be fixed by older commits the TODO entry hadn't been updated to reflect (closed as a documentation correction, not new code) — see `docs/VERIFICATION.md`); screenshot/OCR/QR area-selection offset is still wrong (root-caused to compositor/GPU dithering under fractional scale, not a phi-shell bug) — tracked in `docs/TODO.md`. No UI/UX-pass round is hardware-verified yet (no compositor in any session so far) |
| Identity & advanced styling — final palette, typography, motion, Plymouth, cursor theme | **Built**, pending a clean end-to-end verification pass |
| AI agent (`phi agent` + shell agent panel + containment) | **Working end-to-end on `zotac`** (2026-09-14) — the mechanics were sound; nothing had ever actually been configured/started (`broker.json`/`provider-key`/`opencode.json`, the A1/A2 systemd units) on either host. Real gap found and fixed: every failure state (a rejected turn, a down support service) used to vanish silently instead of being shown anywhere — see `docs/VERIFICATION.md`. One remaining blocker is outside phiOS: the configured account (opencode.ai Zen) has no payment method, so a real completion still errors — now surfaced clearly instead of hidden. Needs the same real-hardware pass on `razer` (`docs/ai-agent.output` is `razer`-only and predates this fix) |
| Server services (`mini`) — cloud sync, photos, Jellyfin, \*arr, LanguageTool | **Not started** |
| Custom apps (`phi-notes`, `phi-music`, `phi-media`) | **Not started** |

Legend below uses: **done** (in daily use, confirmed on hardware),
**built** (written and running, not fully verified across all hosts),
**partial**, **not started**. A 2026-09-11 verification round tested
~44 items previously marked done/built in `docs/VERIFICATION.md`; most
failed on real hardware and were folded back into `docs/TODO.md` as bugs
rather than staying signed off. Treat **done**/**built** elsewhere in this
file as what an agent believed at the time it wrote it, not as a
user-confirmed fact, until `docs/VERIFICATION.md` shows it was actually
checked off.

---

## 3. `phios-dotfiles` — configuration

Configuration only: no compiled code. One entry point, `bin/phios-install`.

### Install engine — done

- `bin/phios-install` with four modes: `--dry-run` (list every change,
  touch nothing), `--check` (report drift, exit 1 if any), `--system-diff`
  (show `profiles/*/system/` against the live `/etc`, read-only,
  unprivileged), and default (apply packages, symlinks and rendered
  templates).
- **Idempotent and reversible.** Every path it creates is recorded in
  `$XDG_STATE_HOME/phios/manifest` with its source. A path that leaves the
  repo is removed from `$HOME` on the next run — unless hand-edited since,
  in which case it is left and reported. Anything it is about to overwrite
  that it did not write is moved to `$XDG_STATE_HOME/phios/backup/<ts>/`.
- Templates rendered with `envsubst` restricted to the `PHI_*` token names,
  so a `$PATH` or `$HOME` inside a config file survives.
- Shared bash lib under `bin/lib/` (`plan`, `profiles`, `packages`,
  `manifest`, `system`, `tokens`, `env`, `common`). Bootstrap depends only
  on coreutils, bash, git, gettext — runs on a fresh machine before `phi`
  exists.
- Writes `~/.config/phios/dotfiles-root` and
  `~/.config/environment.d/10-phios.conf` so `$PHI_DOTFILES` resolves for
  the login shell and the systemd user environment regardless of where the
  checkout lives.

### Profiles & hosts — done

Profiles: `base`, `desktop`, `laptop`, `intel-gpu`, `nvidia`, `razer-hw`,
`gaming`, `workstation`, `study`, `server`. Composed per host in
`hosts/<name>.txt`; order is significant (a profile providing a concrete
`vulkan-driver` must precede `gaming`, or pacman prompts interactively —
this regression actually happened on `razer`).

- `zotac`: base, desktop, workstation, nvidia, gaming
- `razer`: base, desktop, laptop, intel-gpu, razer-hw, gaming, study
- `mini`: base, server

Each profile carries `packages.txt`, a `home/` tree symlinked wholesale,
`templates/` rendered against the tokens, `system/` (`/etc` material),
`services-*.txt` (declared systemd units, printed never enabled), and
`manual.txt` (one-off commands, printed never run).

### `/etc` boundary — done

`profiles/*/system/` mirrors real absolute paths under `/etc` and is shown
by `--system-diff` only. Populated with what is applied by hand and known:
NVIDIA modprobe options, `zram` generator + `sysctl` companion (per-host
sizing), `crypttab` shape (UUIDs left as placeholders — a permanent,
by-design diff), `smartd.conf`, the unit-failure notification drop-in,
`razer`'s suspend/hibernate drop-ins. The `[phi]` pacman repo is registered
via `profiles/base/system/etc/pacman.d/phi-mirrorlist` (placeholder
`Server =` line) plus a `manual.txt` stanza. `multilib` is a `manual.txt`
`sed` (pacman.conf has no include mechanism for repo sections).

Verified on all three hosts: every difference is either reconciled or is a
documented machine-data placeholder.

### Capability detection — done

`bin/phios-capabilities` probes `/sys` and `/proc` only (no `lspci`,
`udevadm`): GPU vendor, backlight, battery, wifi, bluetooth, touchpad,
touchscreen, ambient-light sensor (`iio:device0` named `als` on `razer`,
confirmed), Chroma (Razer USB vendor `1532`). Profiles decide what is
installed; capability detection decides what the shell shows.

### `razer` input diagnostics — done (diagnosis only)

Full evdev / HID map of the Razer Book 13 keyboard captured. Every
"broken" volume/brightness key already emits a correctly-named HID
scancode — the fix is a compositor keybinding, not an `hwdb` rule (with one
exception: `Fn+F4` synthesizes Super+P in firmware). `Fn` emits no
independent Linux event. The `hwdb` question and the Chroma per-key
questions (`Q-F04`, `Q-F06`) remain for whenever Chroma is finished.

### Design tokens — done

`design/tokens.common.sh` + `tokens.{dark,light}.sh` (`KEY='value'` lines),
`design/adapters.txt` (the list of themed targets), `design/preview.tmpl`,
`design/brand/` (Φ SVGs, ASCII mark, PNG render script). `phi theme`
consumes these. `bin/phios-render` is kept as the comparison target for
`phi theme render`. 2026-09-14: added `PHI_OVERLAY_SCRIM_STRONG` (both
variants) for `phi-shell`'s two-intensity dim split — a screen needs `phi
theme set <variant>` re-run to pick it up.

### ClamAV real-time protection — built, applied on `zotac`

`clamav` in `profiles/base/packages.txt` (all three hosts — on-access
scanning is kernel-level fanotify, works headless too). `clamd.conf`
itself is not mirrored as a system/ file (pacman manages it as a backup
file, and it's ~30KB of mostly stock commentary); `profiles/base/
manual.txt` instead carries a verified, idempotent `sed` that uncomments
the same ~25 lines by hand-tuning on `zotac` reached (heuristics, PUA
detection, per-format scanners, on-access watching all of `/`), plus the
`VirusEvent` line wiring detections to a desktop notification.
`profiles/base/system/etc/clamav/virus-event.bash` (the notification
script) and `system/etc/sudoers.d/clamav` (the NOPASSWD rule it needs to
reach a user's session) are real, mirrored system/ files — the sudoers
one replaces a hand-edit that had clamd.conf's `VirusEvent` *directive*
pasted into a sudoers file by mistake, which broke `sudo` outright on
`zotac` (every invocation, not just clamav's) until fixed by hand via
`su -` (both `sudo` and `pkexec` were unusable while sudoers itself
couldn't parse). `clamav-daemon.service`, `clamav-freshclam.service` and
`clamav-clamonacc.service` (stock units, no overrides) are declared in
`services-system.txt`, enabled by hand per the usual convention.
Quarantine is the stock `clamav-clamonacc.service`'s own `--move=
/root/quarantine`, not something this repo configures.

Fully verified end to end on `zotac`, down to the sudoers rule's exact
required shape: the first version (`NOPASSWD: /usr/bin/notify-send`, no
`SETENV:`) let `sudo` run but silently refused the `DBUS_SESSION_BUS_
ADDRESS`/`PATH` assignments `virus-event.bash`'s own invocation sets
inline — clamd logged the detection but the notification never fired, no
error visible anywhere except `journalctl -u clamav-daemon.service`.
Fixed and re-verified with a live EICAR scan (`clamdscan`, the standard
industry test string, not real malware). **Still open:** whether the
notification actually renders on screen — a bare `notify-send` with no
clamav involved at all showed no visible toast either, in the same
session, so this reads as a separate, pre-existing `phi-shell`
notification-rendering gap, not a clamav or dotfiles issue, and was not
chased further here.

This is real-time (on-access) protection only — a periodic full-disk
`clamscan` sweep (to catch anything that existed before real-time
protection was ever turned on) is not built and not requested yet.

Applied and enabled on `zotac`; not yet reproduced on `razer`/`mini`.

### Known open item

`phios-dotfiles` is renamed `master` → `main` in this workspace and in the
live checkout at `~/.local/share/phios/dotfiles`. **The GitHub default
branch still needs to be changed and `origin/master` deleted** — see §9.

---

## 4. `phi` — unified CLI (Go, dependency-free)

Monolith with a `PATH` fallback to `phi-<verb>` (ADR 017). Domain logic in
`internal/*`, kept strictly separate from the view layer from the first
line. Cold start is a functional requirement — the launcher calls
`phi query` on every keystroke. Output is styled on a TTY, structured
(JSON) when redirected. Packaged as `phi`, installed by pacman on all three
hosts.

| Verb | State | What it does |
|---|---|---|
| `--version` / `help` / `completion zsh` / `man` | **done** | Version string set at link time by the PKGBUILD. Help, zsh completion and the man page all render from one `internal/view.Commands` list — adding a verb is one row. |
| `theme` | **done** | `render` one template, `set VARIANT` (render every adapter target, reload what changed, record the active variant), `preview`, `list`, `check` (WCAG contrast of every checked pair, both variants), `contrast HEX [on HEX]` (for the settings panel's live check). Generates `phi-shell`'s `Config/Tokens.qml`. |
| `state` | **done** | Closed set of runtime keys under `$XDG_STATE_HOME/phi`, one flat file each: `theme.variant`, `monitor.config`, `wallpaper.path`, `night-mode`, `dnd`, `spotlight`, `chroma`. Rejects any unlisted key. Survives reboot (confirmed on `zotac`). |
| `doctor` | **done** | Composes seven checks: disk space (`statfs`), failed systemd units (system + user), dotfiles drift (`phios-install --check`), SMART (`smartctl -H`, tri-state — never a false `ok`), declared-service status, package categories (any foreign package is a policy violation), and `/srv` mount (`mini` only). Every check degrades to `unknown` rather than guessing; exit code non-zero only on a real problem. |
| `pkg` | **built** | `list` / `check` / `state` — every explicitly-installed package split into T0 / AUR / T4 / phi-packages, with available updates. A non-empty AUR row is a policy violation, flagged as such. |
| `vpn` | **built** | WireGuard: `list`, `status` (handshake age, transfer — never an endpoint or address), `up` / `down` (via `sudo -n wg-quick`), `import`, `forget`. Managed configs live at `~/.config/phi/wireguard/`, `0600`, outside every repo. Needs the `49-phi-vpn` sudoers drop-in. |
| `firewall` | **built** | Inbound nftables (`inet phi` table → `/etc/nftables.conf`): `status`, `enable` / `disable` (default-drop), `preset home\|public\|paranoid`, `allow PORT [--from CIDR]`, `remove ID`, `log on\|off`, `blocked`. State in `~/.config/phi/firewall.json`; needs the `49-phi-firewall` sudoers drop-in. |
| `wallpaper` | **built** | `texture MODE [--intensity N] [--size WxH]` — deterministic procedural PNG tile for the shell's background layer, cached by the shell. |
| `query` | **built** | The launcher backend. Ranks results across applications, open windows, calculator, unit + currency conversion, zoxide jump, SSH hosts, shell commands, web search, files, system actions. JSON when redirected (what `phi-shell`'s Launcher parses). `query record <id>` for frecency. The calculator engine (`internal/mathx`) does arithmetic, constants, functions, free-form unit conversion, percentages, equations/inequalities, calculus (derivative, definite integral) and plots — multi-line results carry a "rich" payload the shell renders as a card. Hidden `refresh-currency` sub-verb fetches one rate into the on-disk cache. |
| `update` | **built** | Preventive `snapper` snapshot → `pacman -Syu` → regenerate every themed config. Interactive. |
| `agent` | **built** | The AI-agent subsystem — see §7. |

---

## 5. `phi-shell` — desktop shell (QML on Quickshell 0.3.1)

One shell process, not independent components (ADR 072). Cloned to
`~/.config/quickshell/phi`; Hyprland starts `qs` itself on login (since
session integration landed). Hot-reloads on save. `Config/Tokens.qml` is
generated by `phi theme` and gitignored.

**Architecture:** the *type* of a bar module or panel tab is code, written
once; the *instance* is a row in `Bar/modules.json`, `Panels/tabs.json` or
`Settings/sections.json` — adding one is a one-file data change (ADR 078).
Modules declare a capability requirement and appear only where it exists
(ADR 074). Designed for N monitors from day one (ADR 077). The service
surface (`Quickshell.Services.*`, `.Hyprland`, `.Wayland`, …) is touched
only in `Config/` and `Services/`; everything else reads one of those.

### Status bar — done

Declarative module registry. Modules in use: phi-agent, workspaces (with
Steam / btop workspace icons), active window, volume, brightness, GPU
(NVIDIA only), network (Tailscale), wifi, bluetooth, battery, notifications,
clock. Three-island layout, N-monitor, capability-gated. Bar popouts align
to the button, a meter widget, full-height buttons, modal scrim covers the
bar, one source of truth for bar height, buttons sit on the wallpaper.

### Session surfaces — built

| Surface | Notes |
|---|---|
| **Notification daemon + toasts** | The shell is the notification daemon (ADR 073). Icon-with-scrolling-text toast; detail in the panel. Per-app rules, DND, retention, test, clear. |
| **Sidebar** | Declarative tab registry. Tabs: Notifications, Clipboard. Also hosts the Calendar and the agent panel. |
| **Clipboard history** | The shell owns it (ADR 073), with password exclusion (`I-08`). |
| **Launcher** | A renderer only — ranking, providers and actions live in `phi query` (ADR 018). Modes are data (ADR 019). Rich-result card for calculator / converter / plot output. |
| **Lock screen** | `ext-session-lock` protocol, native PAM, fail-closed. Terminal-style input, fade-in, blank cursor, selectable ambient backdrop (lava lamp / matrix rain / starfield). PAM result handling is the one security-critical path — kept simple and explicit. |
| **Window overview** | Native, all windows, 3-finger up/down gesture (gesture entry confirmed working). Unified with the Alt+Tab surface. |
| **Screenshot / OCR / QR / recording** | Home-built screenshot + region select, colour picker, OCR, QR decode; `wf-recorder` for video. Scrolling capture is permanently excluded (ADR 075). Area-selection offset is still wrong as the selected region's size changes — confirmed broken 2026-09-11, root cause not yet found, see `docs/TODO.md`. |
| **Alt+Tab overlay, tooltips, context menu, cheat sheet** | Cheat sheet is read-only from `hyprctl binds -j`. Alt+Tab itself confirmed **broken** on hardware 2026-09-11 — doesn't close on Alt release, doesn't start on the right window, doesn't focus on select (click/touch/Enter/Space), doesn't change workspace; only the gesture entry point works. See `docs/TODO.md`. |
| **Keybinding scheme** | Defined in `phios-dotfiles`' `hyprland.lua`; the cheat sheet and settings panel group binds by context. Several binds confirmed non-functional on hardware (Super+Shift/Ctrl+arrows, the h/j/k/l workspace alternatives, submap-based resize) — root cause not found by source reading alone, see `docs/TODO.md`. |
| **Magnifier** | Circular glass loupe overlay (`phios-dotfiles` binds + `phi-shell` render). Confirmed broken on hardware — the lens no longer zooms, root cause not yet isolated between two candidates (see `docs/TODO.md`). |
| **OSD** | Volume / brightness overlay, split. |
| **Cursor spotlight** | Dedicated layer-shell vignette overlay following the cursor (no native Hyprland path exists — `Q-F07` resolved negative). |

`S-39` (daily-use consolidation) is **blocked** pending a run of the
consolidated set on hardware.

### Settings panel — built

Nine sections, each a `Settings/sections/*.qml` driven by
`Settings/sections.json` with search keywords: **General** (host / hardware
/ OS / uptime / disk, battery on `razer`), **Theme** (dark/light, night
shift + temperature, true tone, cursor spotlight, magnifier, lock-screen
effect, colours / typography / shape, full wallpaper section with a
cubic-bezier motion editor), **Connectivity** (Tailscale, WireGuard VPN,
Wi-Fi with a speed graph, Bluetooth, firewall), **Devices** (audio device
selection, monitor, Chroma per-key, brightness, mouse/trackpad),
**Keybindings** (reference, grouped by context), **Notifications** (DND,
per-app rules), **Security** (ClamAV, face unlock, secrets — placeholders),
**AI Agent** (activation, project, personality, broker, model/provider,
egress whitelist, systemd units, memory proposals), **Updates** (four
package categories, check + upgrade).

The panel went through four restyle rounds (R1–R4) and a full section-by-
section overhaul (A–K), plus an `I-05` / motion audit. A few visual
results remain unverified without a compositor.

2026-09-14: gained a session-only "Advanced" toggle (`Services/
SettingsPanel.qml`'s `showAdvanced`, next to the search field) that hides
a `SettingsRow`/`SettingsGroup` marked `advanced: true` unless a live
search already matches it. Applied so far to Connectivity's raw firewall
port-editor/blocked-log rows and AI Agent's blocklist/services/broker-
readout groups — not yet swept across the other seven sections, tracked in
`docs/TODO.md`.

### Identity & advanced styling — built, pending verification

Final palette derived in OKLCH; typography with the patched-font correction
(symbol-only font + targeted Noto fallback, no patched fonts); motion
implementation against the bound taxonomy; Plymouth boot theme rendered
onto the lock-screen grammar with the user's ASCII Φ; cursor theme,
magnifier, remaining chrome. Auth surfaces (lock / login VT palette /
Plymouth) reworked over three rounds. None of this has had a single clean
end-to-end verification pass yet.

---

## 6. `phi-packages` — packaging

Produces packages; never installs them, never touches a real machine.

- `phi/PKGBUILD` builds the CLI from a pinned git tag
  (`source=(…#tag=v${pkgver})`, never `latest` / `-git`). `pkgver` is
  hand-bumped and always names a real tag; `pkgrel` for packaging-only
  rebuilds.
- `scripts/build <component>` — clean-chroot build via
  `mkarchroot` / `makechrootpkg -c` on `zotac` (the only build host).
- `scripts/publish <repo-dir> <pkg>…` — detached-signs with the dedicated
  phi packaging key and `repo-add -s` into the local `phi.db.tar.zst`.
  Requires `GPGKEY` explicitly. Never touches `mini` — moving the repo to
  `mini:/srv/pkg/phi` needs the overlay address, which no repository may
  hold.
- `package()` regenerates `_phi` completion and the man page from the
  freshly built binary — nothing generated is checked in.

Current published version: **`phi` 0.16.1** (firewall / sudoers fix). The
`phi` package pipeline (build → sign → publish → `pacman -Syu`) is run
**only by the user**. An agent creates and pushes the tag.

`phi-repo/` at the workspace root holds the built package artifacts and the
`phi.db` — gitignored, not part of any repository.

---

## 7. AI agent — working end-to-end on `zotac` 2026-09-14

Two agents (ADRs 084–100): **A1** an assistant with system/app skills over
an MCP server, **A2** a coding agent. Containment is `bubblewrap` from
empty; the provider credential is brokered and never enters the agent
process; memory is writable only by the client; a documented
engine↔client contract (opencode over loopback HTTP only, ADR 098/099).

- `phi agent`: `broker` (provider-credential broker, per-instance), `mcp`
  (the phi MCP server on stdio), `init` (seed the data model — two
  personalities, no projects), `project`, `personality`, `memory` (review
  proposals at system / personality / project level), `chat` (client-side
  transcript mirror), `search` (phi-owned markdown only, never opencode),
  `session` (A2 coding sessions), `code DIR` (open the A2 agent, guarded by
  a blocklist), `ask` (one inline question to the running A1 service).
- `phi-shell` agent panel: four sections — Dashboard, Chat, Coding
  Sessions, Memory Proposals, plus a Personality editor and Project view.
  Summonable from the shell.
- **2026-09-14, `zotac`:** the 2026-09-11 `razer` failure ("containment
  failed to start", `socat` unable to reach `proxy.sock`) turned out to
  have no code defect behind it, confirmed by actually running the whole
  pipeline on real hardware: `broker.json` / `provider-key` /
  `opencode.json` had never been created on this machine, and none of
  `phi-agent-broker@a1`, `phi-agent-a1`, `phi-agent-broker@a2`,
  `phi-agent-proxy`, `phi-agent-net-bridge` had ever been started — all are
  declared, none auto-enabled, by design. Once set up: A1's health check
  passes, `phi agent code .` opens a real contained opencode TUI (socat
  bridge working, no socket error), and the broker forwards correctly to
  the configured provider. The one genuine remaining failure is external:
  the opencode.ai Zen account behind the configured key has no payment
  method, so a real completion still errors — confirmed independent of
  phiOS (the same error reproduces with plain, unconfined `opencode`).
  The real bug this session fixed: **every one of these failure states was
  invisible in the product** — `phi agent ask` dumped raw JSON, the chat
  panel silently dropped a rejected turn's message instead of showing it,
  the "Agent offline" panel state was one sentence for five different real
  causes, and `phi agent code` / the coding-sessions panel spawned a
  terminal blind when A2's support services weren't running. Fixed in
  `phi` (`ask.go`, `code.go`) and `phi-shell` (`Services/Agent.qml`,
  `Services/AgentInfra.qml`, the Chat/CodingSessions panels, Settings).
  Full write-up in `docs/VERIFICATION.md`. Not yet re-verified on `razer` —
  `docs/ai-agent.output` is `razer`-only and predates this fix.

---

## 8. Not started

### Server services on `mini` (dominant constraint: 4 GB soldered RAM)

- **Cloud sync** — `/cloud`
- **Photo library**
- **\*arr stack** — indexers + download client
- **Media / music pipelines**
- **Jellyfin** and the video libraries
- **LanguageTool** self-hosted
- **Office / study tools / secrets** — LibreOffice, Anki + sync server,
  Zotero + WebDAV, KeePassXC or Vaultwarden (`Q-F02`: RAM budget on `mini`,
  measured at config time)
- **Clipboard continuity** `zotac` ↔ `razer` over Tailscale

### Custom apps (each is permanent debt — `I-10`)

- `phi-notes` — linked markdown notes (zettelkasten), neovim-based
- Language decision checkpoint (Go vs Rust for the second TUI app)
- `phi-music` — Navidrome client
- `phi-media` — Jellyfin client

### Deferred hardware work

- `razer` `hwdb` rule + Interactive Chroma behaviours (needs the machine)
- Face unlock IR on `razer` (`Q-01` — AUR policy — is deferred; all
  candidates are AUR or manual build, so this is blocked by rule 2)

---

## 9. Open items / follow-ups for the user

1. **`phios-dotfiles` branch rename.** Done locally (`master` → `main`) in
   this workspace and in `~/.local/share/phios/dotfiles`. On GitHub:
   change the default branch to `main`, push `main`, delete `origin/master`
   (commands in the handoff).
2. **`references/` is committed to the workspace** (screenshots + ASCII
   mark, ~1.7 MB). Move or drop it if you'd rather it not be in git.

---

## 10. History

The original planning documents and the full step-by-step log are in
`docs/archive/`:

- `phios-dotfiles-PROGRESS.md` — the old step log: 61 `S-NN` steps
  (M0–M8), 58 `OOP-NN` out-of-plan changes (the shell restyle rounds, the
  settings overhaul, auth surfaces, the agent panel rework, feature
  polish), 7 bugfix rounds. Every row carries its commit hashes and
  hardware-verification notes.
- `phios-master-plan.md`, `phios-architettura.md`, `phios-agente.md` (+
  delta), `phios-agent-brief.md`, `phios-agent-parallel.md`,
  `phios-funzionalita.md`, `phios-piano-stilistico-finale.md`, the three
  installation procedures, `phios-user-runbook.md`.

These are read-only history now. The invariants and closed ADRs they
contain still hold — they are summarised in the `AGENTS.md` rules — but the
project is no longer executed against a plan document.
