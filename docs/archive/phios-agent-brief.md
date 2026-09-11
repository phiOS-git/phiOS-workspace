# phiOS — Agent Brief and Main-Line Backlog

**For:** Claude Code, operating on a machine that is **not** any phiOS host.
**Authority:** `phios-master-plan.md` is the single source of truth. This file executes it. It never overrides it.
**Language:** everything you write — code, identifiers, file names, commit messages, comments, UI strings — is in **English**. You may receive instructions in Italian; you answer in whatever language the user writes.

---

## 1. Your role

You build and maintain the phiOS repositories. You do not operate the machines.

phiOS is a personal Arch Linux system across three hosts: `zotac` (desktop, NVIDIA, gaming and dev), `razer` (laptop, primary machine for study and daily use), `mini` (headless server, 4 GB RAM, no graphical session). All three are installed and working. What is missing is the desktop shell, the unified CLI, the design system, most user-facing features, several server services, and the AI agent subsystem.

You work in a loop: read one step, write files, commit, hand off, **wait**. The user runs the commands on the real machine and reports back. You never assume a step succeeded.

---

## 2. Hard constraints

### 2.1 You must never

1. Run `pacman`, `paru`, `makepkg`, or any package installation.
2. Touch `/etc`, `/usr`, `/var`, or any system path on any host. You may write files **into the repository** under `profiles/*/system/`; you never apply them.
3. Run `systemctl` in any form against a real host.
4. Connect to `zotac`, `razer`, or `mini`. You have no network path to them and must not try to obtain one.
5. Perform hardware diagnostics. You request them; the user performs them.
6. Write a secret, a key, a password, a private IP address, an overlay network hostname, or a notification topic into any repository. **The GitHub remote is public.**
7. Add an AUR (T1/T2) or manual-build (T4) dependency. `Q-01` is deferred; only T0 (`core`/`extra`) and — on the server only — T3 rootless containers are allowed.
8. Add a package that is not in the master plan's package registry (§15) without asking first.
9. Reopen a closed ADR.
10. Move to the next step before the user has verified the current one.
11. Push to the `origin` remote (`mini`). You push to `github` only.
12. Hardcode a colour, a font name, or a size anywhere. Everything comes from the design tokens (`I-05`).

### 2.2 You must always

1. Read `phios-master-plan.md` §2 (founding rules) before writing anything in a new area.
2. Stop and ask when you meet a `[TBD]`, `[HOLD]`, `[?]`, or any ambiguity. Guessing is worse than waiting.
3. Keep exactly **one main-line step in flight**. Parallel-track work (`phios-agent-parallel.md`) is the only exception, and it never touches host state.
4. Make **one commit per step**, with a `Step: S-NN` trailer.
5. Update `PROGRESS.md` in `phios-dotfiles` in the same commit.
6. State plainly what you could not verify.

### 2.3 Why these constraints exist

The user's system holds sensitive study material and is encrypted at rest. The repositories are mirrored publicly. The machines are working systems the user depends on daily. A change you cannot verify is a change that silently drifts from the repository — which is the exact failure mode invariant `I-09` exists to prevent.

---

## 3. Repositories

| Repository | Contents | You write here |
|---|---|---|
| `phios-dotfiles` | Configuration only: modules, profiles, host manifests, design tokens, templates, `/etc` material (never applied), bootstrap scripts, `PROGRESS.md` | Yes |
| `phi` | Unified CLI, Go | Yes |
| `phi-shell` | Desktop shell, QML on Quickshell | Yes |
| `phi-packages` | PKGBUILDs and build scripts for all own packages | Yes |
| `phi-notes`, `phi-music`, `phi-media` | Client applications (M8) | Yes, when reached |

**Remotes.** `github` is your working remote and the public mirror. `origin` points at the user's server and is written only by the user. Push to `github`; never to `origin`.

**Current state of `phios-dotfiles`** (before S-01): a bash `install.sh`, `theme.sh` with nine colour tokens, and modules `base`, `desktop-environment`, `laptop`, `razer`, `nvidia`, `gaming`, `server`. It works for a minimal system and is inadequate for the full one. Rebuilding it is step S-01.

---

## 4. Step card format

Every step below uses this shape. When you report back, use the same headings.

```
S-NN  <title>
Depends on: <step ids, or —>
Goal: one sentence. What problem this closes.

AGENT
  - what you write, file by file or area by area

USER
  - what the user must do on the machine, in order

VERIFY
  - non-destructive commands the user runs
  - the shape of the expected output (not the exact value)

DONE WHEN
  - the acceptance condition, unambiguous
```

**Handoff message** — after committing, produce exactly this and nothing more:
1. What changed (two or three lines).
2. The `USER` block, ready to execute.
3. The `VERIFY` block, ready to paste back.
4. One sentence: what you will do next once verified.

Do not summarise the design rationale in the handoff. It is in the plan.

---

## 5. Commit convention

```
<scope>: <imperative, lowercase, English>

<optional body: what and why, never how>

Step: S-NN
```

`scope` is a profile, module, or component name (`dotfiles`, `theme`, `bar`, `launcher`, `phi/theme`, `pkg/phi-shell`). One step per commit. Never squash across steps. Never let one commit touch two steps.

---

## 6. Main-line backlog

Sequential. Do not reorder without asking. Steps marked **[BLOCKING]** gate the whole milestone.

---

### M0 — Dotfiles foundation

The exit criterion is **no regression**, not improvement. Both machines, re-applied from the new structure, must behave exactly as they do today.

```
S-00  Repository scaffolding and PROGRESS.md
Depends on: —
Goal: give the loop a durable memory and the repo a documented contract.

AGENT
  - Add PROGRESS.md: one row per step (id, title, status, commit, date, note).
    Statuses: todo | awaiting-verification | verified | blocked.
  - Rewrite README.md: what the repo is, what install does, what it deliberately
    does NOT do (no /etc, no systemctl, no pacman for own packages before M1).
  - Add docs/ with a copy of the four planning documents for offline reference.

USER
  - Pull and read README.md.

VERIFY
  - git log -1 shows the Step trailer.

DONE WHEN
  - The user confirms README.md describes what they expect the repo to do.
```

```
S-01  [BLOCKING] Dotfiles v2 structure and installer
Depends on: S-00
Goal: an installer that is idempotent, previewable, reversible, and knows what it
      has created on this machine.

AGENT
  - Create the layout of master plan §5.2: bin/, design/, hosts/, profiles/.
  - bin/phios-install with, at minimum:
      --dry-run      list every file that would change and every package that
                     would be installed; touch nothing
      --system-diff  show the difference between profiles/*/system/ and the
                     machine; read-only, no privilege
      --check        report drift between repo and machine; exit non-zero on drift
      (default)      apply: packages, symlinks, rendered templates, reconcile
                     against the state manifest, print the list of systemd units
                     the user must enable — never enabling them
  - State manifest in $XDG_STATE_HOME/phios/manifest: every path created, with its
    source. On re-run, paths no longer declared are removed.
  - bin/lib/ for shared functions. Bash only. Dependencies limited to coreutils,
    bash, git, gettext.
  - Do NOT move existing module content yet. S-01 builds the machinery; S-03 migrates.

USER
  - Nothing yet. This step is inert by design.

VERIFY
  - bin/phios-install --dry-run  → runs, reports "no profiles declared" or equivalent.

DONE WHEN
  - --dry-run runs clean on both machines and changes nothing.
```

```
S-02  [BLOCKING] Design token source, two variants
Depends on: S-01
Goal: one source for every colour, font, size, radius, and motion value, in two
      permanent variants.

AGENT
  - design/tokens.common.sh   typography roles, spacing scale, radii, z-layers,
                              motion categories A-D
  - design/tokens.dark.sh     full palette, dark variant
  - design/tokens.light.sh    full palette, light variant
  - Token set exactly as master plan §6.2 and §6.3. Abstract names only
    (bg-0, fg-1, accent), never literal ones.
  - design/adapters.txt: one row per target — template | destination |
    reload command | class A/B/C.
  - bin/phios-render: renders a template for a given variant.
  - Carry the current nine values forward as the starting dark palette. Do NOT
    derive the final palette here; that is S-51.
  - Light variant: the accent MUST get a second lightness. #d3a0ac is ~2.2:1 on
    white, below the 4.5:1 minimum. Mark it clearly as provisional and failing.

USER
  - Nothing.

VERIFY
  - bin/phios-render on one template, both variants → two distinct outputs.

DONE WHEN
  - Both variants render; no colour literal exists outside design/.
```

```
S-03  [BLOCKING] Migrate existing targets, output-identical
Depends on: S-02
Goal: move every current config into the new structure without changing what
      lands on disk.

AGENT
  - Move base, desktop-environment, laptop, razer, nvidia, gaming, server into
    profiles/, splitting per master plan §5.3 (base, desktop, laptop, workstation,
    nvidia, intel-gpu, razer-hw, gaming, study, server).
  - Migrate templates for kitty, yazi, btop, nvim, zsh, mpv to the new token names.
  - Preserve package installation ORDER inside hosts/*.txt. Profiles providing a
    concrete provider must precede profiles requiring it. Regression to avoid:
    on razer, gaming before razer produced an interactive prompt for vulkan-driver.
  - profiles/*/services-user.txt and services-system.txt: declare, do not enable.
  - Record the yazi git plugin as a declared step (currently untracked, known gap).

USER
  - On razer first, then zotac:
      git pull github master
      bin/phios-install --dry-run

VERIFY
  - The --dry-run output. Expected shape: a list of files that will be replaced by
    identical content, and no packages to install.

DONE WHEN
  - The user confirms --dry-run proposes no functional change on either machine,
    then runs the installer and reports the session still works: terminal, browser,
    file manager, audio, network, Steam.
```

```
S-04  Capability detection
Depends on: S-03
Goal: one shell configuration on every machine; modules appear only where they
      have meaning (ADR 074).

AGENT
  - bin/phios-capabilities, output KEY=VALUE, detecting at minimum:
      battery, backlight, ambient light sensor, GPU vendor, Razer chroma device,
      touchscreen, touchpad, wifi, bluetooth, multiple monitors.
  - Detection is by device presence, never by hostname. The shell must never ask
    "am I a laptop".

USER
  - Run bin/phios-capabilities on both machines.

VERIFY
  - Paste the output from both machines.

DONE WHEN
  - razer reports battery, backlight, touchscreen, wifi, chroma present;
    zotac reports them absent and reports its NVIDIA GPU. The ALS line answers
    Q-F01 either way.
```

```
S-05  /etc boundary
Depends on: S-03
Goal: nothing lives only in a machine's memory (I-09), without the agent touching
      the system.

AGENT
  - profiles/*/system/ populated with what is currently applied by hand and known:
    NVIDIA modprobe options, crypttab shape (no UUIDs — those are machine data),
    zram generator config, sysctl drop-ins, notify-on-failure drop-in pattern,
    smartd config shape, multilib note.
  - --system-diff implemented against these.
  - README section stating clearly: these files are NEVER applied by the installer.

USER
  - bin/phios-install --system-diff on both machines.

VERIFY
  - The diff output.

DONE WHEN
  - Every difference is either explained (machine-specific value) or reconciled.
```

```
S-06  razer input diagnostics
Depends on: S-04
Goal: close the volume and brightness key failure (funzionalita §2.15).
      Diagnosis only; the fix is a later step.

AGENT
  - Nothing to write yet. Produce the diagnostic instruction set.

USER
  - On razer:
      sudo evtest        (or sudo libinput debug-events) pressing volume up/down,
                         mute, brightness up/down, with and without Fn
      cat /proc/bus/input/devices   for the internal keyboard vendor:product id
      lsusb
  - Also: ls /sys/bus/iio/devices/   (answers Q-F01 definitively)

VERIFY
  - Paste the raw codes emitted per key, the vendor:product id, and the iio listing.

DONE WHEN
  - The codes are known. The hwdb rule is written in S-46, not here.
```

**Gate G0.** Both machines re-applied from v2, no regression, `--dry-run` and `--system-diff` clean, capabilities reported, razer input codes known.

---

### M1 — `phi` and own-package distribution

```
S-10  [BLOCKING] phi repository skeleton and --version
Depends on: G0
Goal: the unified CLI exists as a binary with subcommands. This is the explicit
      minimum requirement.

AGENT
  - New repository phi. Go module.
  - cmd/phi: entry point, dispatcher, PATH fallback to phi-<name> (ADR 017).
  - internal/cli: argument parsing, help, TTY detection.
  - Output contract: styled on a TTY, structured when redirected. Never colours or
    spinners off-terminal.
  - Commands: phi --version, phi help, phi completion zsh.
  - Separate domain logic from view layer from the first line (§10.1.1 architettura).
    This is the only thing that keeps the Rust option open.
  - Identity: help header carries the Φ mark, Role A, monochrome.

USER
  - Nothing yet; the package comes in S-11.

VERIFY
  - Agent reports: go build succeeds, phi --version prints a version.

DONE WHEN
  - The binary builds and the dispatcher falls back to PATH for unknown verbs.
```

```
S-11  [BLOCKING] phi-packages and the [phi] pacman repository
Depends on: S-10
Goal: own software is installed by pacman like anything else.

AGENT
  - New repository phi-packages: PKGBUILD for phi, a build script that builds in a
    clean chroot, and a publish script that signs and adds to a repository database.
  - Documented conventions: versioning, naming (phi-<component>), where the
    repository database lives on the server (/srv/pkg/phi), how a host registers it.
  - profiles/*/system/pacman/ fragment declaring the [phi] repository. Never applied
    by the installer.

USER
  - On zotac (build machine): install base-devel, devtools, go, pacman-contrib.
  - Generate a package signing key. Keep the private key OFF every repository.
  - Build phi in a clean chroot, sign it, publish the repository database.
  - On mini: create /srv/pkg/phi, serve it over the overlay network to pacman.
  - On zotac and razer: register [phi] in pacman.conf, import the public key into
    the pacman keyring.

VERIFY
  - pacman -Si phi   on both machines → shows repository "phi"
  - phi --version    after installation

DONE WHEN
  - phi --version runs on both machines, installed by pacman, not by hand.
```

```
S-12  phi theme
Depends on: S-11, S-02
Goal: replace the bash renderer without changing the template contract.

AGENT
  - internal/tokens: read the token files; derive in OKLCH.
  - internal/theme: adapters, rendering, class-differentiated reload.
  - Verbs: phi theme render | set <variant> | preview | list | check
  - phi theme check verifies contrast ratios against 4.5:1 on BOTH variants and
    reports every failing pair. This is an executable check, not a visual one.
  - phi theme set is idempotent and supports --dry-run.
  - Class C targets are listed explicitly as "restart required", never restarted.

USER
  - Update phi. Run phi theme set dark --dry-run, then apply.

VERIFY
  - phi theme check   → paste the report
  - phi theme set dark, then set light, then set dark again → session survives

DONE WHEN
  - Output is byte-identical to bin/phios-render for the same variant, and
    phi theme check reports the known light-variant accent failure.
```

```
S-13  phi state
Depends on: S-11
Goal: a defined home for runtime state, separate from versioned configuration.

AGENT
  - internal/state: read and write $XDG_STATE_HOME/phi.
  - Verbs: phi state get | set | list.
  - Keys defined in master plan §5.6. Nothing else may be stored there.

USER
  - Update phi.

VERIFY
  - phi state set theme.variant dark && phi state get theme.variant

DONE WHEN
  - State survives a reboot and is never written into any repository.
```

```
S-14  phi doctor
Depends on: S-13
Goal: one command that answers "is this machine in the shape the repo expects".

AGENT
  - Composes: disk space, failed systemd units, dotfiles drift (--check), SMART
    status, service status, package categories. On mini also: /srv mount state.
  - Exit code non-zero on any red condition, so it is usable from a timer.

USER
  - phi doctor on all three machines.

VERIFY
  - Paste the three outputs.

DONE WHEN
  - The output is honest: it reports the known open items rather than hiding them.
```

```
S-15  phi completions and packaging polish
Depends on: S-14
Goal: the CLI is pleasant enough that it gets used.

AGENT
  - zsh completions generated by the command itself, installed by the package.
  - Man page or structured help, generated, not hand-written.
  - PKGBUILD updated to install completions and the man page.

USER
  - Update phi, open a new shell.

VERIFY
  - Tab completion after "phi ".

DONE WHEN
  - Completions work and are regenerated by the build, not committed by hand.
```

**Gate G1.** `phi` installed from `pacman` on both desktop machines; `phi theme` is the renderer of record; `phi doctor` runs on all three hosts.
---

### M2 — Shell skeleton and status bar

Framework: Quickshell 0.3.1 (`extra`, T0), QML/QtQuick, native hot reload on save.
You cannot run it. Every visual result is verified by the user with a screenshot or a description.

```
S-20  [BLOCKING] phi-shell repository and configuration singletons
Depends on: G1
Goal: the structural skeleton every other surface plugs into.

AGENT
  - New repository phi-shell. Layout as master plan §8.2.
  - Config/Tokens.qml: GENERATED by phi theme. Add it to .gitignore and commit a
    checked-in example instead. Never edit it by hand.
  - Config/Appearance.qml: singleton exposing semantic roles, not raw values.
    Every other file reads Appearance, never Tokens directly.
  - Config/Capabilities.qml: singleton reading phi capabilities.
  - Config/Settings.qml: bridge onto phi state.
  - shell.qml: per-screen instantiation. Designed for N monitors from day one
    (ADR 077). One monitor today is not a reason to hardcode one.
  - Add a theme adapter row so phi theme regenerates Config/Tokens.qml.
  - Keep the contact surface with Quickshell types THIN: Appearance and
    Capabilities are the only places that touch framework APIs. The framework is
    at 0.3.x and its API is not stable.

USER
  - Install quickshell. Run the shell manually from a terminal inside the session.

VERIFY
  - qs -p <path> starts without QML errors; paste any error output.

DONE WHEN
  - The shell process starts, produces no surface yet, and logs no errors.
```

```
S-21  Styled widget library
Depends on: S-20
Goal: zero duplication inside surface class 1.

AGENT
  - Widgets/: StyledText, StyledButton, StyledIcon, Pill (radius-pill toggle),
    Segment, Popover, Panel, ListRow, Separator, Scrim.
  - Every widget implements the seven transverse states of the style plan §12:
    default, hover, active/pressed, focus (keyboard), disabled, loading, invalid.
  - Affordance rules from style plan §6, enforced in the widgets themselves:
    system labels low-contrast monochrome; values Tier-2 only above threshold;
    inactive interactive = same weight, reduced opacity; active = full inversion;
    the ">" glyph is reserved for the active input point ONLY.
  - Motion: category B for state transitions, near-instant, no organic easing.

USER
  - Nothing.

VERIFY
  - Agent reports the widget list and which style-plan rule each enforces.

DONE WHEN
  - No widget contains a literal colour, size, or duration.
```

```
S-22  [BLOCKING] Status bar with declarative module registry
Depends on: S-21
Goal: a bar whose composition is data, not code (ADR 078).

AGENT
  - Bar/Bar.qml: three-island layout — left workspaces, centre active window title,
    right status cluster ending with the clock.
  - Bar/modules.json: the registry. Each row = type, island, position, data source
    (internal service or phi verb), capability requirement.
  - Title truncation: end-of-string with ellipsis. No additional logic.
  - Icon vs text rule: icon only for discrete/binary state; text plus
    colour-above-threshold for any continuous value.
  - Three-level disclosure (style plan §7) built into the Segment type:
    level 1 segment, level 2 popover (max 5 info rows + 2 quick actions),
    level 3 deep-link to an existing mature tool.
  - Per-monitor: bar on every monitor, active window is LOCAL focus, not global.

USER
  - Restart the shell.

VERIFY
  - Screenshot of the bar on both machines.
  - Add one module by editing modules.json only, restart, screenshot.

DONE WHEN
  - Adding a module is demonstrably a one-file data change.
  - Ask the user Q-N02 (per-monitor or shared workspace list) with the compositor
    in front of them, and Q-N03 (btop workspace model).
```

```
S-23  Bar modules
Depends on: S-22, S-04
Goal: the per-host inventory of master plan §8.4.

AGENT
  - Types: workspaces, active window, clock, volume, network/Tailscale, bluetooth,
    battery (anomaly-carrier), brightness, GPU (anomaly-carrier), night mode,
    Φ agent presence (placeholder, no backend yet).
  - Sources: Quickshell.Hyprland, .Services.UPower, .Services.Pipewire, .Bluetooth,
    .Networking. Brightness: VERIFY the exact QML type name in 0.3.x documentation
    first; fall back to brightnessctl via Quickshell.Io if it does not exist.
  - Anomaly-carrier thresholds are placeholders from style plan §8: razer battery
    >15%/h discharge or <20% remaining; zotac GPU >70% for 60s or >75°C. They are
    generic starting numbers, not calibrated. Make them configurable.
  - Φ segment: Tier-1 accent with category-A motion only while processing,
    otherwise neutral. Binary trigger, no threshold.
  - Every module declares its capability requirement; modules appear only where
    the capability exists.
  - Network module shows the overlay name, NEVER an IP (ADR 067).

USER
  - Restart the shell on both machines.

VERIFY
  - Screenshot of both bars. Confirm razer shows battery/wifi/bluetooth/night mode
    and zotac does not; zotac shows GPU and razer does not.

DONE WHEN
  - The inventory matches §8.4 exactly on both machines, driven by capabilities.
```

```
S-24  Session integration
Depends on: S-23
Goal: the shell starts with the session and reloads cleanly.

AGENT
  - Hyprland Lua config: start phi-shell with the session, plus the window rules
    already decided — Steam dedicated workspace, Steam secondary windows floating,
    btop workspace, dynamic workspaces.
  - Steam window rules need real class and title values. Ask the user for
    hyprctl clients output rather than guessing.
  - Document the hot-reload path so the user can iterate without restarting.
  - Remove nothing yet: waybar was never installed; there is nothing to displace.

USER
  - Restart the session.

VERIFY
  - The bar appears at login on both machines. hyprctl clients for Steam windows.

DONE WHEN
  - The bar starts automatically and survives a shell reload.
```

```
S-25  Compatibility check against Hyprland
Depends on: S-24
Goal: close risk C-06 before building nine more surfaces on top.

AGENT
  - Review the Hyprland Lua configuration against the version actually installed.
  - Document which API surfaces the shell depends on and where they are used.

USER
  - hyprctl version, pacman -Qi hyprland on both machines.

VERIFY
  - Paste both. Confirm the Lua config loads with no deprecation warnings.

DONE WHEN
  - Any deprecation is either fixed or recorded as a known risk in the plan.
```

**Gate G2.** Bar working on both machines, capability-driven, no hardcoded values, module addition proven to be a data change.

---

### M3 — Session surfaces

This milestone is what makes the system usable daily. It is the largest.

```
S-30  Notification daemon and toasts
Depends on: G2
Goal: the shell IS the notification daemon (ADR 073), so history in the sidebar
      comes for free.

AGENT
  - Services/Notifications: implement the desktop notification specification.
  - Toast surface: unobtrusive animated icon with pager-style scrolling text for a
    short excerpt and source (shell doc §4). Motion category B — a notification
    recurs several times per work session, so it is frequent by definition.
  - Action support (buttons) required, for the sidebar detail view.
  - Do-not-disturb: silence popups for a duration or on demand.
  - History retained for the sidebar tab.

USER
  - Send test notifications; try DND.

VERIFY
  - Screenshot of a toast; confirm DND silences popups but keeps history.

DONE WHEN
  - Notifications work with actions, and DND behaves.
```

```
S-31  [BLOCKING] Sidebar with declarative tab registry
Depends on: S-30
Goal: adding a tab is configuration, not code (ADR 078).

AGENT
  - Panels/Sidebar.qml with fixed dimensions defined in the theme code. No user
    resizing (shell doc §6).
  - Panels/tabs.json: type, title, icon, data source (internal service or phi verb).
  - Tabs at this step: notifications, clipboard (empty until S-32), calendar,
    AI chat PLACEHOLDER.
  - The AI chat tab renders the full conversational layout with no backend: message
    list, input, streaming indicator, tool-approval affordance, memory-proposal
    notice. It must look finished and do nothing. This satisfies the user's stated
    priority 2 and ADR 100 (the card TYPE is code, the INSTANCE is declarative).

USER
  - Open the sidebar; cycle the tabs.

VERIFY
  - Screenshot of each tab.

DONE WHEN
  - A fifth tab can be added by editing tabs.json alone.
```

```
S-32  Clipboard history
Depends on: S-31
Goal: pinning, TTL, and password exclusion — none of which existing tools give
      together.

AGENT
  - Services/Clipboard on wl-paste --watch. Text and images.
  - Pin: pinned entries never expire.
  - TTL: minimum one month; exact value deferred to real consumption.
  - Sensitive exclusion via the x-kde-passwordManagerHint MIME type with value
    "secret". KeePassXC and KDE Wallet already set it.
    WARNING: this depends on which password manager the user chooses. Flag it in
    PROGRESS.md as a cross-dependency on the M6 secrets decision.
  - File support (text/uri-list): NOT required now. Design the storage so it can be
    added later without restructuring.
  - Remove cliphist from profiles/desktop/packages.txt in this step (C-07).
    Keep wl-clipboard.

USER
  - Copy text, copy a password from the manager, pin an entry, restart the session.

VERIFY
  - Confirm the password did not enter history, and the pin survived the restart.

DONE WHEN
  - Both hold.
```

```
S-33  [BLOCKING] Launcher
Depends on: S-31, S-12
Goal: a Spotlight-class launcher whose logic lives in phi (ADR 018).

AGENT — phi side (repository phi)
  - internal/query: providers, ranking, frecency, actions.
  - Providers: applications, open windows (switch to, likely the most frequent
    action on a tiling compositor), files, web search, shell command, calculator
    (fully local expression evaluator with unit conversion), directory/project jump
    via zoxide, system actions (lock, suspend, log out), known SSH hosts.
  - Currency conversion: a rates source with no API key, cached, falling back to
    the last known value with no network.
  - Dictionary and translation: defer; they belong to the system translation
    backend which is not yet decided.
  - Ranking is the risky, iterative part. Validate phi query in a terminal against
    fzf BEFORE any GUI work. Getting ranking wrong in a terminal costs nothing.
  - Asynchronous provider orchestration: results arrive with different latencies and
    must NEVER block typing.
  - Ask the user Q-N09 before indexing password vault entries. It is a security
    decision, not a convenience one.
  - File index constraint (I-08): the index contains the names of everything,
    including sensitive material. It must live on the encrypted volume and be
    excluded from any synchronisation.

AGENT — shell side (repository phi-shell)
  - Launcher/: layer-shell surface, text field, virtualised result list.
  - NAVIGATION STACK with sub-views that are not plain lists (a translate view has
    input fields and an output pane). This is the capability that separates a
    command palette from a dmenu clone. It is the real requirement.
  - The "command" result type pushes a sub-view instead of executing and closing.
    Tab on a keyword is an ACCELERATOR on the same object, not a separate feature
    (ADR 022).
  - Direct command: if the first word is a shell command, Enter opens a new terminal
    window and runs it. The result must not appear in the bar. Define a hold policy:
    interactive commands keep the window, one-shot commands need an explicit rule.
  - App vs command heuristic: single token = application, token with arguments =
    command. Confirm with the user (Q-74).

USER
  - Try the launcher for a day. Report what ranked wrong.

VERIFY
  - Screenshot. A list of queries that returned the wrong first result.

DONE WHEN
  - The first result is right for the twenty queries the user actually types.
```

```
S-34  Lock screen
Depends on: S-21
Goal: a lock screen that cannot fail open.

AGENT
  - Lock/: Quickshell.Wayland WlSessionLock on ext-session-lock. The guarantee that
    the session stays locked if the client crashes comes from the PROTOCOL, not from
    the application — use the protocol, never a fullscreen window.
  - Authentication: Quickshell.Services.Pam.
  - THE PAM RESULT HANDLING IS THE ONLY GENUINELY SECURITY-CRITICAL CODE IN THE
    WHOLE SHELL. Keep it simple, explicit, and fail-closed. No clever abstractions.
    Ambiguous result = not authenticated.
  - Content: clock, battery, notifications, media (MPRIS), optionally reminders.
  - Blur or solid colour; transition on activation and unlock.

USER
  - Lock, unlock. Then, from a TTY, kill the shell process while locked.

VERIFY
  - Confirm the session stayed locked after the kill.

DONE WHEN
  - Killing the client does not expose the session, and a wrong password never
    unlocks.
```

```
S-35  Window overview
Depends on: S-21
Goal: Mission Control equivalent, all windows on all monitors.

AGENT
  - Overview/: grid of ALL open windows across all workspaces and monitors — not
    only the current workspace. Quick selection, no text search.
  - Recall gesture: three-finger swipe up/down (the opposite axis to the L/R
    workspace switch, so no conflict). Native Hyprland on razer's touchpad.
    On zotac: keybind only, unless Solaar rules cover the MX Master gesture button
    (see S-43).
  - Live previews (screencopy) vs icon+title (DesktopEntries): start with
    icon+title. Live previews are an upgrade, not a requirement.
  - No hyprpm plugin. Q-01 is deferred; the native path was already the decision.

USER
  - Use it on both machines.

VERIFY
  - Screenshot; confirm windows from other monitors appear.

DONE WHEN
  - Selection is faster than switching workspaces by hand.
```

```
S-36  Screenshot, OCR, QR, recording
Depends on: S-21
Goal: capture built in-house because the desired features are rich UI, plus one
      mature external tool for video.

AGENT
  - Screenshot/: area, window, full screen. Selection overlay built in QML.
  - OCR from a selected area: tesseract, already installed. Zero new dependency.
  - QR read from a selected area: zbar.
  - Video recording: wf-recorder invoked via Quickshell.Io for encoding only.
    First VERIFY whether Quickshell's declared screen-recording integration covers
    full encoding or only frame capture; do not discard wf-recorder before checking.
  - Nice-to-have, explicitly deferred: decorative background around a window shot,
    syntax-highlighted code snippets, draggable on-screen overlay with annotation.
  - Scrolling capture is EXCLUDED permanently (ADR 075). Do not implement, do not
    propose, do not revisit.

USER
  - Take one of each; run OCR and QR.

VERIFY
  - The OCR text and the decoded QR payload.

DONE WHEN
  - All three modes work for both stills and video.
```

```
S-37  Alt+Tab overlay, tooltips, context menu, cheat sheet
Depends on: S-35
Goal: the remaining interaction surfaces.

AGENT
  - Alt+Tab: enters a temporary input mode showing the overlay and cycling.
    Releasing Alt exits and confirms. Releasing only Tab keeps the mode active and
    the overlay accepts the pointer. Uses press AND release bindings plus submaps.
  - Tooltip with an appearance delay.
  - Context menu. The mechanism was out of scope in the style plan; propose one and
    ask before building.
  - Cheat sheet: READ-ONLY, sourced from hyprctl binds -j at the moment of display.
    Never a saved copy. Editing bindings from the panel is EXCLUDED — both possible
    implementations reintroduce exactly the divergence the user wants to avoid.
  - The PATH command enumeration used here is the SAME data the launcher's command
    provider needs. Share it; do not build it twice.
  - Also investigate Q-N10: Quickshell.Services.Polkit would let the shell act as
    the Polkit agent, removing hyprpolkitagent / lxqt-policykit from architecture
    §8.2 entirely. Report whether it covers the real cases; do not adopt it without
    asking.

USER
  - Try each.

VERIFY
  - Screenshot of the cheat sheet; confirm it reflects a binding changed by hand.

DONE WHEN
  - The cheat sheet cannot diverge, because there is no second place holding it.
```

```
S-38  Keybinding scheme
Depends on: S-37
Goal: assign the modifiers once. Remapping later destroys muscle memory.

AGENT
  - Propose a complete scheme: Super for the window manager, Alt for applications,
    modes for rare actions. Cover every surface built in M2 and M3.
  - Bindings are written BY HAND into the Hyprland config. No intermediary
    generates them (decision already taken).

USER
  - Review, amend, apply. This is Q-N07 and it is the user's call, not yours.

VERIFY
  - hyprctl binds -j after applying.

DONE WHEN
  - The user confirms the scheme is the one they want to learn.
```

```
S-39  Daily-use consolidation
Depends on: S-38
Goal: close M3 honestly.

AGENT
  - Fix everything the user reported during a week of real use.
  - Update PROGRESS.md and the plan's open-question list.

USER
  - Use the system for a week. Report friction.

VERIFY
  - The friction list.

DONE WHEN
  - Nothing on the list blocks daily use.
```

**Gate G3.** The session is usable daily without dropping to a terminal for common operations. **This closes the user's stated priority 1.**

---

### M4 — Settings panel and system features

```
S-40  [BLOCKING] Settings panel, nine sections
Depends on: G3
Goal: one canonical place for every runtime option.

AGENT
  - Settings/: General, Theme, Connectivity, Devices, Keybindings, Notifications,
    Security, AI Agent, Updates. Contents exactly as master plan §9.12.
  - Runtime state ONLY. Anything persistent that is not runtime state belongs in the
    versioned configuration; a panel writing outside the repo creates a second
    source of truth that diverges.
  - Bar shortcuts are supplementary, never a replacement: every option lives here.
  - Sections with no backend yet render as placeholders that state what is missing.

USER
  - Open every section.

VERIFY
  - Screenshot of each.

DONE WHEN
  - Every feature in phios-funzionalita.md has a home here, working or explicitly
    marked as awaiting a backend.
```

```
S-41  Live light/dark theme, GTK/Qt, CSD decision
Depends on: S-40, S-12
Goal: I-05 fully realised across all five surface classes.

AGENT
  - Theme section: toggle with dual preview, live application.
  - Generate GTK3/GTK4 theme and Kvantum config from tokens; set the colour-scheme
    preference through the portal so native apps follow.
  - Librewolf userChrome.css generated from tokens; class C, restart required.
  - Decide CSD window decorations (Q-N05). Proposal: suppress where the toolkit
    allows, leaving window management entirely to the compositor. Ask before doing.
  - LibreOffice icon set aligned; class C.

USER
  - Toggle both ways with several apps open.

VERIFY
  - Screenshots in both variants. The list of apps that needed a restart.

DONE WHEN
  - Class A and B reload live; the class C list matches §6.7 and nothing else.
```

```
S-42  Night shift and True Tone
Depends on: S-40
Goal: evening and daytime eye comfort.

AGENT
  - hyprsunset driven from the shell via Quickshell.Io — a timer and a control call,
    fewer moving parts than a second daemon. No sunsetr.
  - Toggle plus target temperature in the Theme section; status icon on razer's bar.
  - True Tone: only if S-06 showed an ALS under /sys/bus/iio/devices/. Drive colour
    temperature from ambient lux instead of clock time. If absent, the feature is
    abandoned, not substituted.

USER
  - Try both.

VERIFY
  - Confirm the transition and whether ALS exists.

DONE WHEN
  - Night shift works; True Tone is either working or formally abandoned.
```

```
S-43  Cursor spotlight, idle inhibit, OSD, timer, colour picker,
      fullscreen auto-hide bar
Depends on: S-40
Goal: the remaining small surfaces, all inside the same framework.

AGENT
  - Spotlight: layer-shell overlay drawing the vignette, updated on cursor movement
    via the Hyprland event socket. The native shader path is verified closed
    (upstream issue closed without development). No permanent commitment: if
    maintenance becomes unmanageable the feature is dropped.
  - Idle inhibit: native Wayland idle-inhibit type, driven by a rule on window class
    or process — automatic detection, not a manual toggle, not a timer. Define the
    process list with the user (games, video lectures).
  - OSD for volume and brightness. Timer in the bar. Colour picker (capture plus
    pixel read).
  - Fullscreen: auto-hiding bar with edge reveal; requires the shell to observe the
    active window state.
  - Also here: investigate whether Solaar rules with diverted keys can drive the
    MX Master gesture button on zotac. Solaar is T0 and already installed; logid is
    AUR and excluded. Report findings; do not assume either way.

USER
  - Try each; report on the Solaar experiment.

VERIFY
  - Screenshots; the Solaar finding.

DONE WHEN
  - Each surface works or is explicitly recorded as dropped.
```

```
S-44  Wallpaper
Depends on: S-40
Goal: native background layer, no separate daemon.

AGENT
  - Background layer inside the shell. hyprpaper and swww are excluded.
  - On assignment, the image is COPIED into $XDG_DATA_HOME/phi/wallpapers/ and
    referenced from there — never from its original path, which may move or vanish.
  - Background constraint from the style plan: wireframe / technical grid or flat
    gradient. Never photographic or illustrative.

USER
  - Set a wallpaper; move the original file; restart.

VERIFY
  - The wallpaper survived.

DONE WHEN
  - It does.
```

```
S-45  Package management surface and theme regeneration hook
Depends on: S-40
Goal: visibility on package provenance, and a theme that never goes stale.

AGENT
  - phi pkg list | check: four categories — T0 (core/extra), AUR (empty while Q-01
    is deferred), T4 manual, and phi-packages.
  - Updates section renders those four categories with available updates per
    category.
  - phi update: preventive snapshot, pacman upgrade, config regeneration, outcome.
  - pacman hook (repository file, applied by the user) that regenerates theme
    configs after an upgrade touches a theme target.

USER
  - Apply the hook; run an upgrade.

VERIFY
  - Confirm configs were regenerated and no colour drifted.

DONE WHEN
  - An upgrade cannot leave a stale theme behind.
```

```
S-46  razer hardware: hwdb fix and Chroma
Depends on: S-06, S-43
Goal: fix the broken keys and implement the Chroma behaviours.

AGENT — hwdb
  - Write the /etc/udev/hwdb.d/ rule from the codes captured in S-06, into
    profiles/razer-hw/system/. Never apply it.
  - Devices section shows a "resolved / not resolved" readout, not a live control.

AGENT — Chroma
  - Services/Chroma writing directly to the org.razer DBus bus. No razer-cli, no
    polychromatic: those are customisation UIs and are out of scope.
  - Behaviours: static colour on idle (hypridle); power key colour from UPower
    battery level; function-row blink on notification arrival — sourced from the
    SHELL's own notification service (ADR 073 closes Q-F05); red on a blocking
    error dialog (reuse the per-app window-class trigger); Super held illuminates
    keys with available shortcuts (Hyprland submap handling press AND release);
    Neovim mode colour via ModeChanged calling out; mic-mute indicator from
    PipeWire/WirePlumber; red pulse on critical battery.
  - Colours come from the tokens. No literal RGB values anywhere.
  - Panel scope: on/off toggle plus an optional static colour picker. NOTHING ELSE.

USER
  - Apply the hwdb rule; run systemd-hwdb update and udevadm trigger; test the keys.
  - Enumerate the Chroma device with python-openrazer: confirm the device id is
    supported (Q-F04) and whether the power key is individually addressable (Q-F06).

VERIFY
  - Volume, mute and brightness keys respond. Paste the openrazer enumeration.

DONE WHEN
  - The keys work, and every Chroma behaviour that the hardware supports is live.
    If the power key is not addressable, fall back to a full-keyboard or row pulse.
```

**Gate G4.** Every declared feature has a surface. **This closes the user's stated priority 2.**

---

### M5 — Identity and advanced styling

```
S-50  Final palette, derived in OKLCH
Depends on: G4
Goal: a palette that is generated and provably accessible, not chosen by eye.

AGENT
  - Derive the full Tier 0/1/2/3 sets plus the 16-colour ANSI map in OKLCH,
    both variants, from a small set of anchor values.
  - The light variant MUST get a second accent lightness. This is not optional.
  - Tier 2 direction: oxide/desaturated red, ochre/amber, moss/teal, slate blue.
  - phi theme check must pass with zero violations at 4.5:1.

USER
  - Apply; read in both variants for a full day.

VERIFY
  - phi theme check output with zero failures; subjective report.

DONE WHEN
  - Zero violations and the user prefers it to the current palette.
```

```
S-51  Typography and the patched-font correction
Depends on: S-50
Goal: close ADR 054, which the current font set violates.

AGENT
  - Close Q-N01 with the user: Iosevka (narrow, more columns on a 13" screen, works
    with the 1ch spacing unit) or Source Code Pro (same Adobe superfamily as
    font-reading and font-ui).
  - Install the chosen mono font UNPATCHED plus ttf-nerd-fonts-symbols as a
    symbols-only fallback.
  - Generate the fontconfig fallback chain from tokens: mono primary, symbols,
    then targeted Noto — Greek (for Φ) and extended Latin. NO CJK until it is
    actually needed.
  - COVER THE YAZI CASE FIRST. The patched font is not a stylistic choice: it was
    installed solely to satisfy yazi's icon glyph requirement. Removing it without
    covering that breaks the file manager. Two things are needed, not one:
      (a) the fontconfig fallback chain to font-symbol;
      (b) kitty symbol_map directives mapping the Nerd Font codepoint ranges to
          font-symbol. kitty does NOT rely on fontconfig alone for missing glyphs;
          without symbol_map the icons stay as boxes even with a correct fallback.
  - Remove ttf-iosevkatermslab-nerd ONLY after the yazi and btop check passes.
  - This step does not depend on the palette work of S-50. It can be brought
    forward if the user wants the ADR 054 violation closed sooner.
  - Verify Φ (U+03A6) renders in font-reading, font-ui and font-mono. Never use the
    lowercase forms: Unicode has two and fonts disagree on which renders as what.

USER
  - Apply; check terminal, TUI and glyph coverage.

VERIFY
  - Screenshot of yazi, btop and neovim; confirm no missing glyphs.

DONE WHEN
  - No patched font is installed and no glyph is missing.
```

```
S-52  Motion implementation
Depends on: S-50
Goal: the four categories, applied consistently.

AGENT
  - A: tracking feedback — kitty cursor_trail, Φ processing indicator.
  - B: state transitions — windows, panels, drawers, workspaces, notifications.
    Near-instant, no organic easing.
  - C: rare emphasis — boot, unlock, first run. ONLY two effects: character-by-
    character typing, and random-letters scramble resolving to the final word.
    A loading indicator qualifies for C only if the resolution coincides with the
    real completion of a process.
  - D: ambient indicators — animation forbidden by default.
  - Generic letter-roll on titles is REMOVED and must not reappear as a default.

USER
  - Use for a day.

VERIFY
  - Confirm nothing feels sluggish.

DONE WHEN
  - No category-C effect fires on a frequent event.
```

```
S-53  Plymouth boot theme and Φ identity assets
Depends on: S-51
Goal: the identity, in its closed list of contexts.

AGENT
  - Vector Φ: monochrome variant and accent variant. Plus an ASCII/Unicode variant
    for TUIs and banners.
  - Plymouth theme (script type) in profiles/desktop/system/plymouth/phi/,
    rendering Φ in Role A: Tier 0, monochrome, still. The random-letters resolve
    on appearance is permitted and thematically coherent — offer it, do not impose.
  - TTY/login banner, SSH banner, and the "about phiOS" panel — all Role A.
  - USE IS A CLOSED LIST: boot splash, TTY/login banner, about panel, agent segment.
    Never wallpaper, watermark, window icon, or launcher decoration.

USER
  - Install plymouth; add the hook to mkinitcpio.conf BEFORE sd-encrypt; set the
    theme; regenerate the initramfs; add quiet splash to the boot entries; reboot.
  - Do zotac and razer SEPARATELY, one at a time.

VERIFY
  - Boot completes; the LUKS passphrase prompt is graphical; on razer, resume from
    hibernation still works.

DONE WHEN
  - Both machines boot cleanly. If either fails: remove the hook, regenerate, reboot.
    The second kernel and the pre-upgrade snapshot are the safety net.
```

```
S-54  Cursor theme, magnifier, remaining chrome
Depends on: S-53
Goal: finish surface class 5.

AGENT
  - XCursor theme matching the described cursor: thin, black, white-outlined.
    Either find a conforming one or produce it.
  - Magnifier: the compositor has native zoom; the lens effect is a shader.
  - Decide Q-N04: theme systemd-boot or leave it.

USER
  - Apply.

VERIFY
  - Screenshot.

DONE WHEN
  - The cursor is consistent across GTK, Qt and the shell.
```

**Gate G5.** `phi theme check` clean; no patched fonts; both variants usable; boot identity in place. **This closes the user's stated priority 3.**
---

### M6 — Services and tools

Several steps here are independent of the shell and can be executed by the user at
any time after G0. They are grouped by milestone, not by strict dependency.

```
S-60  Synchronised cloud
Depends on: G0 (shell independent)
Goal: the server counterpart of ~/cloud, and the sync mechanism.

AGENT
  - profiles/server: syncthing package, unit declaration, folder configuration as
    data, RequiresMountsFor= on the /srv mount.
  - profiles/desktop: syncthing user unit declaration.
  - Folder granularity: ONE SYNC UNIT PER VAULT (ADR 040), so razer and zotac can
    hold different sets.
  - Naming discipline, enforced in documentation: subfolders of ~/cloud are named
    by PURPOSE, never by type. Never ~/cloud/documents — it would create parallel
    trees against the local XDG directories.
  - Sync operates on /srv/cloud ONLY. Media libraries are served, never synced
    (ADR 059). Never mix the two.
  - Ask the user Q-N08: the university vault's name.

USER
  - Install syncthing on mini and both clients; enable; pair the devices; create one
    Btrfs subvolume per sync unit under /srv/cloud; set ownership.
  - Measure: free -h and systemd-cgtop on mini before and after.

VERIFY
  - A file created on razer appears on mini. Paste the before/after memory figures.

DONE WHEN
  - Sync works and mini still has at least 1.5 GB free for page cache.
```

```
S-61  Photo library
Depends on: S-60
Goal: reliable storage for irreplaceable data, with automatic phone upload.

AGENT
  - phi photos import: reads EXIF (perl-image-exiftool), sorts into a date-based
    tree under /srv/media/photos, deduplicates BY CONTENT HASH, never by filename.
  - A send-only Syncthing folder as the phone inbox; import moves out of it.
  - NO ML indexing. Immich and PhotoPrism are excluded by the RAM constraint. This
    is an explicit renunciation of semantic search, not a postponement.
  - Client viewing: imv and yazi previews, already installed.
  - Ask Q-N06: photos on the external 1 TB (ADR 042) or on the internal disk, given
    that they are the irreplaceable class and USB-attached disks are a known risk.

USER
  - Create the subvolume; configure the phone folder; run one import.

VERIFY
  - The tree structure after import; confirm duplicates were caught.

DONE WHEN
  - An import is idempotent: running it twice adds nothing.
```

```
S-62  Jellyfin and the video libraries
Depends on: S-60
Goal: films and series served, with the VR library kept separate.

AGENT
  - profiles/server: jellyfin-server, jellyfin-web, unit with RequiresMountsFor=,
    static user in the shared media group with setgid (ADR 029, 067).
  - TRANSCODING DISABLED, permanently (ADR 063). Haswell Quick Sync decodes H.264
    but NOT HEVC. The library is stored in direct-play formats for the target
    devices — this is a decision about the STORAGE format, not about playback.
  - VR library at /srv/media/video-vr, OUTSIDE Jellyfin, served directly to the
    headset (ADR 061). The filename convention IS the metadata schema for
    projection and stereoscopy; ask the user to settle Q-69 before ingesting.
  - Subtitles: sidecar files with a language suffix, which is what both media
    servers and mpv expect.
  - Scan timers must not overlap with Navidrome or Syncthing hashing.

USER
  - Install; enable; point the library at /srv/media/video; measure memory.

VERIFY
  - Direct play works to one client. Memory figures.

DONE WHEN
  - Playback works with transcoding off and mini stays within budget.
```

```
S-63  Indexers and download client
Depends on: S-62
Goal: the search source that phi's media and music verbs need.

AGENT
  - qbittorrent-nox (T0): unit, configuration. Chosen specifically for SEQUENTIAL
    DOWNLOAD and FIRST/LAST PIECE PRIORITY — the two requirements already derived
    from R2 (playback begins before the fetch finishes) and from the subtitle hash
    (which is computed over size plus the first and last 64 KB).
  - Prowlarr as a rootless podman container with the official upstream image, T3.
    A quadlet unit, resource limits, no privileged daemon.
  - phi media search | add | status and phi music search, consuming Prowlarr's API.
  - LIDARR IS EXCLUDED. It duplicates the already-decided music pipeline
    (ADR 012, 023): fetch and cataloguing are separate, cataloguing always happens
    on the server, beets does tagging and organisation, and the entry point is
    phi music add <source>. Do not propose it again.
  - Stage 2 (radarr, sonarr) is GATED on the memory measurement below. Do not build
    it in this step.

USER
  - Install podman; pull the official Prowlarr image; start it; configure indexers.
  - Measure free -h and systemd-cgtop with everything running.

VERIFY
  - phi media search returns results. Paste the memory figures.

DONE WHEN
  - Search works AND at least 1.5 GB remains free. If not, stop: stage 2 does not
    happen and the plan records why.
```

```
S-64  Media and music pipelines
Depends on: S-63
Goal: the verbs that make the libraries usable from any device.

AGENT
  - phi music add <source>: source is a URL OR a local file — one implementation
    covering three cases (server-side add, files moved by hand over SSH, offline
    queue reconciliation). Fetch and cataloguing are separate phases; cataloguing
    always runs on the server because it needs metadata sources.
  - Deduplicate by content hash. On ambiguous metadata: FAIL AND ASK, never guess.
    Jobs must be idempotent and re-runnable.
  - phi media add: same shape. Playback may begin before the fetch completes —
    it is one pipeline, not two functions.
  - phi pin: the cross-cutting offline availability subsystem. A pin is a
    declaration for (device, content). Per-device budget with an eviction policy —
    razer's 512 GB needs one. Integrity check after download. Defined behaviour when
    pinned content is not yet available.
  - Local downloads are MIRRORS OF REAL FILES in the library's folder structure, not
    an opaque client cache — so one mechanism serves music and video alike, and the
    files survive a client reinstall.

USER
  - Add one track and one film end to end.

VERIFY
  - The file landed in the right place with correct metadata.

DONE WHEN
  - Both pipelines are idempotent and fail loudly rather than guessing.
```

```
S-65  ClamAV
Depends on: G0 (shell independent)
Goal: an ACTIVE antivirus service on every machine that can afford one — downloads,
      scripts, and whatever else is monitorable — plus files crossing to and from
      Windows/macOS and the shared exFAT disk.

AGENT
  - profiles/desktop: clamav; freshclam timer; clamd unit; clamonacc for on-access
    scanning via fanotify. Resident service on BOTH zotac and razer.
  - NO clamd on mini. The signature database is resident and of the order of
    1.2-1.5 GB — incompatible with 4 GB shared with every other service. This is
    the machine's dominant constraint, not a preference.
  - On-access paths are DECLARED, not the whole filesystem: ~/downloads, ~/cloud,
    the browser download directory, /tmp, media ingest areas. Watching everything
    costs performance without adding useful coverage, and on Btrfs with snapshots
    it generates noise. The list is configuration; it extends without code changes.
  - Scheduled scan timer on both machines, staggered against other jobs. It covers
    what on-access cannot: files already present when a new signature arrives.
  - razer battery cost: on-access scanning burns CPU, which on a laptop is battery.
    Make the on-access service conditional on a runtime toggle from the start, and
    prepare — do not yet enable — an AC-power condition via UPower, reusing the
    same mechanism as Chroma. The user measures the real cost before deciding.
  - mini: two options, both keeping the database off the server —
    (a) clamdscan --stream to zotac's clamd over the overlay network: simple, but
        it moves the bytes;
    (b) a queued job with execution node zotac (ADR 031): more efficient, but zotac
        must be able to reach the library.
    Do not pick one blind. Present both with the measured data volume.
  - Quarantine directory, OUTSIDE the sync and backup perimeter. NO automatic
    deletion: false positives exist, and deleting a user file is worse than the
    risk it covers.
  - Verbs: phi scan <path> | status | quarantine list|restore|purge.
  - Security section of the settings panel: service state, signature freshness,
    on-access toggle, watched path list, last result, start scan, quarantine
    contents. Threat-found notification, motion category B.
  - State the limit honestly in the documentation you write: ClamAV's detection
    rate against NATIVE Linux malware is modest. The real value is intercepting
    Windows and macOS malware in transit and known-bad files in downloads. It is a
    useful measure, not a guarantee.

USER
  - Install on zotac and razer; enable freshclam, clamd and clamonacc; run a first
    full scan of the declared paths.
  - On razer: use it on battery for a day and report whether the cost is noticeable.

VERIFY
  - clamd is running and the signature date is current on both machines.
  - Drop the EICAR test file into a watched path: it must be caught on access.
  - phi scan from mini executes on zotac.
  - razer battery impact, stated in words.

DONE WHEN
  - On-access catches EICAR on both machines, mini is covered without a local
    database, and the razer battery cost is either acceptable or the AC condition
    is enabled.

S-66  LanguageTool
Depends on: G0 (shell independent)
Goal: grammar and style checking in English and Italian, without sending text to a
      third party (I-08).

AGENT
  - profiles/study (and desktop where wanted): languagetool package; a SOCKET-
    ACTIVATED systemd USER unit on loopback, so the JVM starts on first request and
    stops after idle. Not a resident service, and NOT on mini.
  - Languages en-US and it-IT, extensible by configuration.
  - N-gram data (several GB per language) is DEFERRED: measure quality without it
    first.
  - Integrations: a Neovim plugin speaking the HTTP API directly — NOT ltex-ls,
    which is AUR and excluded while Q-01 is deferred; the official LibreOffice
    extension pointed at the local server; the official browser extension likewise;
    phi lint <file> for terminal use.

USER
  - Install; enable the socket; check one paragraph in each language.

VERIFY
  - Both languages return suggestions; the JVM is not running when idle.

DONE WHEN
  - It works and costs nothing while unused.
```

```
S-67  Office, study tools, secrets
Depends on: G0 (shell independent)
Goal: the remaining study-profile applications.

AGENT
  - profiles/study: libreoffice-fresh plus hunspell, hyphen and mythes for en and it.
    Class C for theming, an explicit I-06 derogation already granted.
  - anki (verify tier). Sync via anki-sync-server on mini is HOLD on Q-F02.
  - zotero (verify tier), explicit I-06 derogation. WebDAV storage on mini is
    HOLD on Q-F02.
  - PDF annotation: zathura already covers reading and search; annotation is
    verified absent upstream since 2018. Xournal++ stays DEFERRED until it becomes
    blocking.
  - Secrets: present both options and let the user decide — KeePassXC (offline, no
    server dependency, no Q-F02 exposure) or Vaultwarden on mini (auto sync, but
    another service on 4 GB). FLAG THE CROSS-DEPENDENCY: this choice determines
    whether clipboard password exclusion works via x-kde-passwordManagerHint
    (S-32). KeePassXC already sets it.

USER
  - Install; decide the secrets manager; measure mini if a server component is
    chosen.

VERIFY
  - LibreOffice opens a .docx correctly; the dictionaries work.

DONE WHEN
  - The secrets decision is recorded and S-32's exclusion is confirmed working.
```

```
S-68  Clipboard continuity between zotac and razer
Depends on: S-32, S-67
Goal: move a snippet between the two machines without a file or a chat.

AGENT
  - Inside the shell, over the overlay network. Scope deliberately narrow: clipboard
    only, not file sync.
  - I-08 RISK: a clipboard crossing the network carries passwords and sensitive
    data. The sensitive-content exclusion of S-32 MUST apply before transmission,
    not after. Confirm this with the user before building.

USER
  - Copy on one machine, paste on the other. Copy a password and confirm it did NOT
    cross.

VERIFY
  - Both behaviours.

DONE WHEN
  - Text crosses and secrets do not.
```

**Gate G6.** mini's memory budget measured and documented after every addition; no overlapping scans; `phi doctor` green on all three hosts.

---

### M7 — AI agent

The full specification is `phios-agente.md`. It is not restated here and is not
negotiable. What follows is only the sequencing.

**Out-of-plan `agent-panel-rework` (2026-09-09).** After M7 landed on `razer`, the
user asked for a four-section panel, three-level memory, per-project read-only
folder-of-interest, structured project metadata, a client-side transcript mirror, an
A2 management surface, and a panel personality editor. These are decided in
`docs/phios-agente-delta.md` (provisional ADRs D-01…D-08). Tracked as `OOP-NN` rows in
`PROGRESS.md`, on a per-repo `agent-panel-rework` branch, merged only on the user's
confirmation. The cards below (S-73, S-75, S-80) are **superseded in part** by that
delta; the M7 step rows and verification ledger are not touched by the rework.

```
S-70  [BLOCKING] Containment and its proof
Depends on: G1, G4
Goal: prove the boundary before anything can write.

AGENT
  - Contained launch scripts, one per agent, plus the path lists. bubblewrap,
    built FROM EMPTY: a path that is not mounted does not exist for the process.
  - Namespaces: --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup,
    --die-with-parent, --new-session, --clearenv followed by explicit --setenv.
  - NEVER MOUNTED: the rest of $HOME and /home, /var /srv /opt /mnt /boot /efi,
    /etc outside the whitelist, SSH keys, GPG keyring, password store, browser
    profiles, local mail — and SESSION SOCKETS: $XDG_RUNTIME_DIR, Wayland, D-Bus,
    PipeWire, the SSH agent. The SSH agent lets a key be USED without being read;
    excluding the file and leaving the socket protects nothing.
  - If containment fails to start, STARTUP FAILS. No degraded mode, ever.

USER
  - Run V-01 through V-04 from phios-agente.md §15. These are BLOCKING.

VERIFY
  - Paste all four results.

DONE WHEN
  - All four pass. If any fails, fix before anything else. No write capability is
    enabled before this.
```

```
S-71  Credential brokering
Depends on: S-70
Goal: the provider key never enters the agent process.

AGENT
  - A phi verb, not a separate binary. The agent talks in clear over loopback to a
    local service OUTSIDE the containment, which holds the key and adds it to the
    outbound request.
  - MUST stream without buffering, or incremental responses are lost.
  - It is the natural place to meter consumption and apply a local rate limit.
  - If the service is down, no agent works. Consistent with the fail-closed rule.

USER
  - Set a spending cap AT THE PROVIDER. It is the only measure that limits DAMAGE
    rather than probability. Write the revocation procedure down in advance.

VERIFY
  - V-08 (no key inside the containment) and V-09 (streaming, no buffering).

DONE WHEN
  - Both pass.
```

```
S-72  A2 network whitelist
Depends on: S-70
Goal: the boundary is the namespace, not an environment variable.

AGENT
  - --unshare-net removes the network; a socat bridge over a Unix socket reaches an
    external tinyproxy; proxy variables point there.
  - A process that clears the variables ends up with NO network, not free network.
  - Whitelist: the brokering service address plus the package registries actually
    used by the projects present. Nothing else. It grows by explicit addition, never
    for convenience.

USER
  - Run V-03.

VERIFY
  - Denied both with and without proxy variables.

DONE WHEN
  - V-03 passes.
```

```
S-73  Agent data model and phi MCP server
Depends on: S-71
Goal: personalities and projects as orthogonal axes; the single growth point for
      the agent's capabilities.

AGENT
  - On-disk structure of phios-agente.md §8.2 under the XDG data directory.
  - memoria.md mounted READ-ONLY inside the containment; proposals directory
    writable. The client, outside the containment, is the only thing that can
    promote an approved proposal. The constraint is enforced by MOUNTS, not by the
    interface: the agent cannot write its own memory even if manipulated.
  - phi MCP server: at first version, ONE read-only verb with no arguments, enough
    to prove the connection. It is tool 5 and the only growth point.
  - Initial state: two personalities (one general, one technical). No preloaded
    projects.

USER
  - Run V-05, V-06, V-07, V-10.

VERIFY
  - Paste all four.

DONE WHEN
  - All pass.
```

```
S-74  Inline command line and remote surface
Depends on: S-73
Goal: J7 and J6.

AGENT
  - Inline: a thin wrapper onto the already-running A1 service, no cold start.
    The session is ephemeral: excluded from the panel list and from memory.
  - Remote surface: A2 ONLY. Listening on the overlay address happens ONLY when a
    session is declared remote; local sessions stay on loopback. Authentication on,
    password loaded by the service manager as a credential from a file outside the
    repository with restricted permissions. NEVER in cleartext in the dotfiles.

USER
  - Run V-15, V-17, V-18.

VERIFY
  - Paste all three.

DONE WHEN
  - All pass.
```

```
S-75  Shell panel: connect the placeholder
Depends on: S-74, S-31
Goal: turn the M3 placeholder into the real surface.

AGENT
  - Thin, explicit client layer at ONE identifiable point, containing no product
    logic (ADR 098). The client assumes nothing about the engine's internal storage
    format; anything that must survive an engine change lives in the files of §8.2.
  - Panel scope of §10.1: streaming conversation, conversations grouped by project,
    personality and project management, copying files into materials, per-
    conversation attachment, output listing, tool approval, non-blocking memory
    proposal notice, end-of-day review, summary and archive on close, loading state
    on project switch, service-unavailable indication.
  - HISTORY SEARCH IS NOT IN THE FIRST VERSION. The archive is already the search
    surface: markdown files inside the project. A dedicated search would be a second
    mechanism for a solved problem AND would have to query the engine's private
    database, which ADR 098 forbids.
  - Memory confirmation shows the LITERAL TEXT to be written, as a diff against the
    existing file. NEVER a summary: a summary would be produced by the same model
    that may have been manipulated.
  - Φ segment in the bar switches to Role B (accent, category-A motion) while
    processing.

USER
  - Use it for a week.

VERIFY
  - V-11 through V-14, V-16.

DONE WHEN
  - The panel is the primary surface and the terminal wrapper is a convenience.
```

```
S-76  Transition from the current uncontained usage
Depends on: S-75
Goal: retire the unconfined engine configuration.

USER
  - Switch to contained A2. This removes access to SSH keys and the ability to push
    to remotes. A2 commits locally; publishing is the user's action.

VERIFY
  - A real coding session completes under containment.

DONE WHEN
  - The old configuration is removed.
```

**Gate G7.** All of `V-01`…`V-18` executed and recorded.

---

### M8 — Custom applications

```
S-80  phi-notes
Depends on: G5
Goal: the first custom application. Obsidian is Electron, class C, and cannot be
      themed from the tokens — criteria (a) and (d) of §10.1.

AGENT
  - Plain-text files, so they are versionable, syncable, and searchable with fd and
    ripgrep.
  - ADR 041, NON-NEGOTIABLE: content and state physically separated from day one.
    The vault holds ONLY the user's files. Index, search cache, open windows and
    workspace state live in ~/.local/state/<app>/. Workspace state is by definition
    machine-local; syncing it is the most common cause of conflicts in synced note
    tools. Designing it right now costs zero.
  - Link schema and attachment handling: decide with the user before writing.
  - Class A theming by construction.
  - Distributed as the phi-notes package.

DONE WHEN
  - It replaces Obsidian for the user's real note-taking.
```

```
S-81  Language decision checkpoint
Depends on: S-80
Goal: honour the deadline set in ADR 016.

AGENT
  - Reconsider Rust BEFORE the second TUI application, or never. Every TUI written
    in Go raises the porting cost: the first is cheap to redo, the third is not.
  - The domain logic ports mechanically; the VIEW layer does not — the two
    ecosystems have incompatible rendering models.
  - Present the trade-off; the user decides.

DONE WHEN
  - Recorded as an ADR either way.
```

```
S-82  phi-music
Depends on: S-81, S-64
Goal: a Navidrome client that can ask the server to download a track or album.

AGENT
  - Criterion (c): glue between two own systems. Streaming plus local download.
  - Local download is a MIRROR OF REAL FILES, reusing phi pin — one mechanism for
    music and video.
  - The offline client only FETCHES; cataloguing always happens on the server
    (ADR 012). The client does not need the tagging stack, only the downloader.
  - Currently substitutable by clamp or the Navidrome web interface. Not urgent.
```

```
S-83  phi-media
Depends on: S-82
Goal: a Jellyfin client that can ask the server to add a film, series or URL.

AGENT
  - Same shape as phi-music. Must respect the server-side features already defined.
  - Currently substitutable by the Jellyfin web interface. Not urgent.
```

**Gate G8.** Each application is class A, reads the tokens, ships as a `phi-*` package.

---

## 7. When to stop and ask

Stop and ask, do not decide, when you meet any of these:

- A `[TBD]`, `[HOLD]`, `[?]` or `Q-` marker in any planning document.
- A package that is not in the master plan's registry.
- Anything that would need AUR, a manual build, or a container on a client machine.
- A security-relevant choice: what enters the launcher index, what crosses the
  network, what the containment mounts, how a PAM result is interpreted.
- A design placeholder whose real value depends on hardware the user must observe.
- Any case where two planning documents disagree.
- Any step whose verification you cannot express as a command the user can run.

Asking costs one message. Guessing costs a step, a commit, and the user's trust in
the loop.

---

## 8. Quick reference

| Need | Source |
|---|---|
| Founding rules and invariants | master plan §2 |
| What you may and may not do | master plan §14, and §2 of this file |
| Package registry | master plan §15 |
| Design tokens and generation contract | master plan §6 |
| Shell structure | master plan §8.2 |
| `phi` contract and verb roadmap | master plan §7 |
| Server memory budget | master plan §10.1 |
| Open questions | master plan §17 |
| Parallel work | `phios-agent-parallel.md` |
| What the user does | `phios-user-runbook.md` |
