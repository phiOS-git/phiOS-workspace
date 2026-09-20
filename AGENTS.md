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
named `origin` (`github.com/phiOS-git/<name>`), carrying one branch: `dev`.

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
- `scripts/sync.sh` — fast-forwards `dev` for the superproject and
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

1. **Official first, and everything else declared.** `core`, `extra` and
   `multilib` are the default and the preferred answer to every dependency.
   Software that genuinely has no official package is admitted only through
   the tier ladder below, and only when it is **declared, pinned and
   monitored**. Undeclared software is the thing this rule forbids — not
   non-official software as such. Still never accepted without asking: AUR
   helpers, and anything installed by a command nobody recorded.

   The ladder, highest to lowest. A candidate is pushed as high as it will go,
   and the tier is justified in its declaration:

   - **T0 — official.** `core`, `extra`, `multilib`. Always the first answer.
   - **T1 — `[phi]`.** Built from a PKGBUILD in `phi-packages`, in a clean
     chroot, signed by the user, served from `mini`. Anything that is a
     permanent part of phiOS belongs here rather than in a language package
     manager: it gets pacman tracking, a file list, and clean removal.
   - **T2 — Flatpak.** The only tier with real sandboxing. Prefer verified
     publishers, audit the portal permissions, and strip `filesystem=host`.
   - **T3 — contained.** Anything else that can run under the bubblewrap
     harness, with an explicit mount set and no ambient environment.
   - **T4 — bare.** AppImages and unpacked binaries that cannot be contained.
     Last resort, recorded with a checksum, and never on `mini`.
   - **TC — rootless container.** A peer of T2 in isolation, and the right
     answer for a *server service* rather than a reluctant exception. Pinned
     by image digest, never by tag.

   Where a thing is declared follows from its tier. **T0 and T1 go in
   `profiles/*/packages.txt`** — a `[phi]` package comes from a configured sync
   repository, so pacman already installs, tracks and removes it, and a second
   path would be a mistake. **TC, T2, T3 and T4 go in
   `profiles/*/external.txt`**, which is where the declaration, the pin, the
   checksum and the reason live.

   Scope is per host, and lives in the profiles. `mini` is **T0, T1 and TC
   only** — no T2, T3 or T4. It still carries an `external.txt`, holding its
   containers, because "nothing undeclared" has to hold on every host. Language package managers (`npm`,
   `pip`, `cargo`, `go`) are for **project-local development only**: a global
   or user-wide install is a policy violation on every host, and the paths
   they would land in are asserted empty.

   An agent still never installs anything (rule 3). It writes the declaration
   and the tooling; the user installs.

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
