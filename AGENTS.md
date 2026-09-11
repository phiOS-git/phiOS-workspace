# phiOS — workspace

phiOS is a personal Arch Linux desktop environment for three machines:
`zotac` (desktop, NVIDIA), `razer` (laptop, primary), `mini` (headless
server, 4 GB RAM). All three are installed and in daily use.

This directory is a git superproject (`phiOS-git/phiOS-workspace`) that ties
the four component repositories together as submodules, so they can be
developed together and synced across machines in one step. Work happens
**inside** a submodule; the superproject only records which commit of each
is current.

## Repositories

| Submodule | Language | What it is |
|---|---|---|
| `phios-dotfiles` | bash + text | Configuration: the install engine, per-host profiles, design tokens, `/etc` material (kept, never applied), bootstrap scripts |
| `phi` | Go | The unified `phi` CLI — one entry point for `theme`, `state`, `doctor`, `vpn`, `firewall`, `pkg`, `update`, `wallpaper`, `query` (the launcher backend) and `agent` |
| `phi-shell` | QML on Quickshell | The desktop shell: status bar, side panels, launcher, lock screen, settings, notifications, window overview, screenshot, magnifier, OSD |
| `phi-packages` | PKGBUILD | Packaging: builds and signs `phi`, `phi-shell`, … into the private `[phi]` pacman repository served from `mini` |

Each submodule is a full repository with its own history and a single
remote named `origin` (`github.com/phiOS-git/<name>`).

## Orientation

- **`PROGRESS.md`** (this folder) is the single, current description of what
  exists, what is in flight, and what is not built yet. Read it first.
- **`docs/archive/`** holds the original planning documents — master plan,
  architecture, agent brief, the step backlog, the installation procedures.
  They are **historical background only, not directives.** This project is
  no longer driven by a step loop or a master plan; `PROGRESS.md` and these
  `AGENTS.md` files are the whole contract.
- **`references/`** holds screenshots and the Φ ASCII mark used as visual
  reference for the shell.

## How to work here

1. Run `scripts/sync.sh` first on any machine — it fast-forwards `main` and
   `dev` for the superproject and every submodule.
2. Work inside the relevant submodule, on a local branch off `dev`.
3. Update `PROGRESS.md` in the same commit as the change it describes.
4. Commit message: `<scope>: <imperative, lowercase>`, optional body for
   what and why. No step trailers.

## Rules — every repository

1. **Branch locally. Only `main` and `dev` go on a remote.** Feature work
   lives on local branches and merges into `dev`; `main` is the known-good
   state. Never push a topic branch.
2. **Only official Arch packages** — `core`, `extra`, `multilib`. No AUR, no
   manual builds, no vendored binaries. Rootless containers on the server
   are the sole exception. Anything outside this is not accepted — ask
   first.
3. **`phi` package releases belong to the user.** An agent may create and
   push git tags (`vX.Y.Z`) on a source repository. Only the user builds
   signed packages and publishes them to the `[phi]` repo. The signing key
   never appears in any repository, in any form.
4. **The three machines are off-limits.** No `pacman` / `paru` / `makepkg`,
   no `systemctl`, no writes to `/etc` `/usr` `/var`, no connecting to
   `zotac` / `razer` / `mini`. `/etc` material is written **into**
   `phios-dotfiles/profiles/*/system/` and applied by the user, by hand.
5. **The remotes are public. No secrets** — keys, passwords, IP addresses,
   overlay hostnames, notification topics — in any repository, ever.
6. **Design tokens are the only source of colour, font, size, radius and
   motion** (`phios-dotfiles/design/`). Nothing else may hardcode one, QML
   included.
7. **Do not import another project's shell or dotfiles as a base.** Reading
   someone's code for reference is fine; copying it in is not.

## Language

Everything written into the repositories is English: code, identifiers,
file names, commit messages, comments, UI strings, documentation. The user
may write in Italian; reply in the language they used.
