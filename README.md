# phiOS workspace

Superproject that ties the phiOS component repositories together as git
submodules, so they can be developed together and synced across machines in
one step.

| Submodule | What it is |
| --- | --- |
| [phios-dotfiles](phios-dotfiles) | Configuration: install engine, per-host profiles, design tokens, `/etc` material. |
| [phi](phi) | The unified `phi` CLI (Go). |
| [phi-shell](phi-shell) | The desktop shell (QML on Quickshell). |
| [phi-packages](phi-packages) | PKGBUILDs that build the in-house packages into the `[phi]` pacman repo. |

## Setup

```sh
git clone --recurse-submodules <this repo>
./scripts/sync.sh          # or, in an existing clone: git submodule update --init
```

`scripts/sync.sh` fast-forwards `main` and `dev` for the superproject and
every submodule — run it first on any machine.

## Where to look

- **`AGENTS.md`** — what phiOS is, how the repositories fit together, and the
  rules that apply to every one of them. `CLAUDE.md` is a symlink to it, and
  each submodule has its own.
- **`docs/reworks/new-features.md`** — the running backlog.
- **`references/`** — screenshots and the Φ mark used as visual reference.
