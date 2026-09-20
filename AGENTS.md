# phiOS — workspace

phiOS is a personal Arch Linux desktop environment, built from scratch, for
three machines that are all installed and in daily use:

| Host | Role | Notes |
|---|---|---|
| `zotac` | Desktop — work and gaming | NVIDIA (open DKMS), Btrfs + LUKS, second disk at `/mnt/bulk`. The only build host. |
| `razer` | Laptop — the primary machine | Razer Book 13, Intel Iris Xe, IR camera, ambient-light sensor, per-key Chroma keyboard |
| `mini` | Headless server — support backend | 4 GB soldered RAM, `/srv` on an unlocked LUKS volume, never a graphical session |

The base OS — disk layout, boot, drivers, the Hyprland session, Tailscale,
Steam, snapper — predates this workspace and is not tracked here. Only the
phiOS layer on top is.

## The repositories

This directory is a git superproject that ties four component repositories
together as submodules, so they can be developed together and synced across
machines in one step. Work happens **inside** a submodule; the superproject
only records which commit of each is current.

| Submodule | Language | What it is |
|---|---|---|
| `phios-dotfiles` | bash + text | Configuration: the install engine, per-host profiles, design tokens, `/etc` material (kept, never applied) |
| `phi` | Go | The unified CLI — `theme`, `state`, `doctor`, `pkg`, `vpn`, `firewall`, `wallpaper`, `query`, `update`, `agent`, `fan` |
| `phi-shell` | QML on Quickshell | The desktop shell: status bars, popouts, launcher, lock screen, settings, notifications, overview, screenshot, magnifier, OSD |
| `phi-packages` | PKGBUILD | Packaging: builds the in-house packages into the private `[phi]` pacman repository |

Each submodule is a full repository with its own history and a single remote
named `origin` (`github.com/phiOS-git/<name>`). `apps/phi-notes` is a fifth,
not yet started.

## How the pieces fit

`phios-dotfiles/design/` holds every colour, font, size, radius and motion
value as shell variables, in a dark and a light variant. `phi theme` renders
those tokens through `design/adapters.txt` into each themed application's own
config format — kitty, btop, yazi, nvim, GTK, Qt, and `phi-shell`'s
`Config/Tokens.qml` and `Config/Colors.json`. Nothing else may contain such a
literal, QML included.

`bin/phios-install` composes a host's profiles (`hosts/<host>.txt`), installs
their packages, symlinks their `home/` trees and renders their templates. It
is idempotent and reversible: everything it creates is recorded in a state
manifest, anything it would overwrite is backed up first, and a path that
leaves the repository is removed from `$HOME` on the next run unless it was
hand-edited since.

`phi-shell` is one shell process for the whole session, not a set of
independent components. It reads the generated tokens, calls `phi` for
anything that is not presentation, and starts from Hyprland on login.

`phi-packages` builds `phi` and `phi-shell` from pinned git tags in a clean
chroot and publishes them to the `[phi]` repository served from `mini`.

## Design language and standing constraints

One accent (pastel pink `#d3a0ac`), base16-style semantic tokens, mono + sans
+ a symbol-only font with a targeted Noto fallback — never a patched font — a
bound motion taxonomy, and a single Φ identity mark. Two variants, dark and
light, switchable live.

These shape what gets built:

- **TUI over GUI.** A GUI is admitted only when it can be themed completely.
- **Every feature names the problem it solves.** Nothing exists "for
  completeness"; a module that duplicates another is removed.
- **No colour, font or size literal anywhere.** Everything comes from
  `design/`.
- **Profiles decide what is installed; capability detection decides what is
  shown.** The shell never asks "am I a laptop", it asks whether this host
  reports a battery.
- **Designed for N monitors** from the first line.
- **One CLI entry point (`phi`), one visual identity (Φ).**
- **`/etc` is versioned, never applied.** `profiles/*/system/` mirrors real
  absolute paths; the user applies them by hand.
- **Nothing proprietary**, and no other project's shell or dotfiles imported
  as a base. Reading someone's code for reference is fine; copying it in is
  not.
- **Each custom app is permanent debt** — a real bar to clear before adding
  one.

## Layout

- `docs/reworks/new-features.md` — the running backlog: what is wanted next,
  what is queued, and known rough edges. The user owns it.
- `references/` — screenshots and the Φ ASCII mark, visual reference for the
  shell.
- `scripts/sync.sh` — fast-forwards `main` and `dev` for the superproject and
  every submodule. Run it first on any machine.
- Each submodule has its own `AGENTS.md` describing that repository.
  `CLAUDE.md` is a symlink to `AGENTS.md` everywhere.

## Working here

Run `scripts/sync.sh`, work inside the relevant submodule, and commit there
first — the superproject commit only records a pointer, it does not upload a
submodule's own commits. Push each submodule you touched, then the
superproject.

Commit messages are `<scope>: <imperative, lowercase>`, with an optional body
for what and why.

## The rules

1. **Only official Arch packages** — `core`, `extra`, `multilib`. No AUR, no
   cloning and building someone's repository, no vendored binaries. Rootless
   containers on the server are the sole exception. Anything outside this is
   not accepted — ask first.

2. **Releases belong to the user.** An agent may create and push a git tag
   (`vX.Y.Z`) on a source repository. Only the user builds signed packages and
   publishes them. The signing key never appears in any repository, in any
   form.

3. **Never touch a live machine.** No `pacman`, `makepkg` or `systemctl`, no
   writes to `/etc`, `/usr` or `/var`, no connecting to `zotac`, `razer` or
   `mini`. This holds whether or not the agent is running on one of them: work
   only in this workspace, never against the files a running session is using.
   `/etc` material is written **into** `phios-dotfiles/profiles/*/system/` and
   applied by the user, by hand.

4. **`dev` is the only branch.** Never `main`, never a topic branch. Several
   agents and the user often work at once, so assume the remote has moved:
   fetch before pushing, and on a rejected push fetch and merge rather than
   rebase. Never discard someone else's work — if a merge conflicts, keep both
   sides unless they genuinely contradict, and never revert a change you did
   not make.

Because the remotes are public, no secrets ever enter a repository: keys,
passwords, IP addresses, overlay hostnames, notification topics.

## Language

Everything written into the repositories is English — code, identifiers, file
names, commit messages, comments, UI strings, documentation. The user may
write in Italian; reply in the language they used.
