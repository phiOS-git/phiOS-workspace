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
- **`docs/TODO.md`** is the user's running backlog; **`docs/VERIFICATION.md`**
  is where you hand finished work back for sign-off. See *The TODO /
  VERIFICATION loop* below.

## How to work here

1. Run `scripts/sync.sh` first on any machine — it fast-forwards `main` and
   `dev` for the superproject and every submodule.
2. Work inside the relevant submodule, on a local branch off `dev`.
3. Update `PROGRESS.md` in the same commit as the change it describes.
4. Commit message: `<scope>: <imperative, lowercase>`, optional body for
   what and why. No step trailers.

## The TODO / VERIFICATION loop

`docs/TODO.md` is the user's backlog — they add to it freely; entries are
grouped bullets. `docs/VERIFICATION.md` is where finished work is handed
back for the user to check and sign off. This backlog is worked by more
than one agent session at a time, plus the user directly — assume the
remote has moved since your last fetch at every step below, and that
fetch/push races and routine `docs/TODO.md` / `docs/VERIFICATION.md` merge
conflicts are normal, not a sign something is wrong.

**This loop applies whenever you are asked to work the TODO list, and also
whenever you are asked to do a task *without* a TODO reference.** In the
latter case, check `docs/TODO.md` for a matching entry before starting.
If one exists, treat it as taken from the list — claim it (step 1) and
follow the rest of this loop for it, rather than doing it as a one-off with
no claim, no `[taken]` marker and no `docs/VERIFICATION.md` entry.

1. **Fetch, claim, push — before writing any code.** `git fetch` the
   superproject and confirm the entry is not already `[taken]`. Prefix the
   bullet with `[taken]` — `- [taken] alt+tab does not work: …` — commit,
   and **push the superproject's `dev` immediately**, before starting
   implementation. This push is the only thing that makes the claim visible
   to a parallel session. If it's rejected (remote moved), fetch, merge,
   re-check the entry is still unclaimed, and push again. Claim only what
   you are actually about to work on now.
2. **Do the work** in the relevant submodule, on a **local branch off its
   `dev`** (rule 1 below: never on `main`/`master`, and that local branch
   never itself goes on a remote). A task touching more than one submodule
   repeats this per submodule.
3. **Land it, once committed, in this order:**
   a. In the submodule: fast-forward local `dev` to `origin/dev`, merge the
      local topic branch into it, delete the topic branch.
   b. In the superproject: delete the entry from `docs/TODO.md`, add a
      section to `docs/VERIFICATION.md` (newest first) using the template
      below, and record the new submodule pointer — one commit.
   c. `git fetch` again, then **push `dev` in every repository actually
      touched — each submodule first, then the superproject.** The
      superproject commit only records a pointer; it does not upload the
      submodule's own commits, so a submodule push you skip leaves that
      work invisible to the user on GitHub even though the superproject
      looks finished.
   d. Any push rejected: fetch and merge (never rebase — this history may
      already be shared elsewhere), then push again. A `docs/TODO.md` /
      `docs/VERIFICATION.md` conflict resolves by keeping both sides'
      changes (each stays a "newest first" section). A submodule-pointer
      (gitlink) conflict resolves by keeping whichever SHA is the
      descendant (`git merge-base --is-ancestor <a> <b>`).
4. **Leave it for the user.** They delete the `docs/VERIFICATION.md` entry
   once they have verified it. Never edit or delete an entry you did not
   write.

A change with no matching TODO entry still gets a `docs/VERIFICATION.md`
section — the file is the record of everything awaiting a human check,
backlog-tracked or not. A one-line typo fix or a docs-only change does not.

### VERIFICATION.md entry template

```
## <short imperative title>

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** <hash> <subject line>   — one line per commit
- **Original TODO:** <the entry verbatim, or "none — outside the backlog">

### What was asked
Restate the task in your own words so the user can confirm you understood it.

### What was done
The actual change: files touched, the approach, and any decision you made
that the user did not spell out.

### Honest assessment
Everything that is not clean: known issues, anything cut or deferred,
questions you need answered, anything you could not verify (say why — e.g.
needs hardware), anything you are unsure about. If it is all clean, say so
plainly.

### How to test it
Step by step, assuming no prior context.
- Every command in full and copy-pasteable, in the order to run them.
- For a visual change: what should look different, where on screen, and
  what it looked like before.
- For a feature: the exact steps to exercise it and the correct result at
  each step.
Never write "as before", "the usual way", or anything that assumes the user
remembers how it worked.
```

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
