# External packages — implementation plan

Why this file is in `docs/`: it spans `phi`, `phi-shell`, `phios-dotfiles` and
`phi-packages`, so it belongs to no single submodule. `docs/new-features.md` is
the user's backlog and stays a backlog; this is the worked plan behind the
`[WIP]` items in it. It is finished work, not a running note — fold it into the
submodule `AGENTS.md` files and delete it once the phases below are done.

Policy lives in rule 1 of the workspace `AGENTS.md`. This document is the
implementation of that rule, not a second copy of it.

---

## 1. The problem, restated

Not "how do we allow non-official packages". The requirement is **monitored
installation**: nothing exists on a machine that no one declared, and the
system reports drift rather than relying on the user remembering. Non-official
software is admitted as a consequence, not as the goal.

Three populations, which must not be conflated:

| | What it is | Lives | Treatment |
|---|---|---|---|
| **A** | Development dependencies (`npm`, `pip`, `cargo`, `go`) | Inside a project (`node_modules/`, `.venv/`) | Not installations. Never declared, never tracked. Their **escape paths are asserted empty**. |
| **B** | Applications chosen by the user (WiVRn, a school AppImage) | A closed set of roots | Declared, pinned, checksummed, fingerprinted. |
| **C** | phiOS's own dependencies (`pi`) | Wherever the component needs | Packaged into `[phi]` and treated as a normal component. |

**C is where most of the win is.** Anything permanent to phiOS becomes a signed
`[phi]` package, which makes it T1 and therefore ordinary. The "extra packages"
problem shrinks to B, which is small.

---

## 2. What already exists

This plan is mostly wiring, not new machinery. Inventory, verified in the tree:

**`phi`**
- `internal/pkg/pkg.go` — `Category` (T0 / AUR / T4 / phi-packages) *and* a
  `Manager` abstraction (`phi`, `pacman`, `aur`, `npm`, `flatpak`, `appimage`).
  `ListManager` implements pacman-backed managers and AppImage (listing
  `~/Applications`); npm and flatpak return explicit `Implemented: false`
  placeholders.
- `internal/doctor/packages.go` — `packageCategories` asserts **zero foreign
  packages**, reporting `pacman -Qm` output as a policy violation.
- `internal/cli/pkg.go` — `phi pkg list [--manager N] [--json] | check | state`.
- `internal/state/state.go` — a **closed** key set at `~/.local/state/phi`.

**`phios-dotfiles`**
- `profiles/<p>/packages.txt` — T0 packages, one per line, unioned across a
  host's profiles by `bin/lib/packages.sh`.
- `bin/lib/manifest.sh` — the state manifest at `~/.local/state/phios/manifest`,
  one TSV record per installer-created path (`kind/target/source/profile/digest`).
  It already knows every path the installer owns.
- `profiles/desktop/home/.local/bin/phi-agent-contain` — a complete, fail-closed
  bubblewrap harness: preflight that refuses to run if `bwrap` or user
  namespaces are unavailable, `--clearenv` plus an explicit env allowlist, a
  `.paths` mount grammar (`ro`/`rw`/`ro?`/`rw?`/`dir`/`sym` with `@VAR@`
  expansion), namespace unsharing, `--die-with-parent`, `--new-session`, a
  `path_denied` blocklist, and for A2 `--unshare-net` with a socat/tinyproxy
  egress whitelist.
- `bubblewrap`, `socat`, `tinyproxy` and **`opencode`** are already declared T0
  packages in `profiles/desktop/packages.txt`.
- `profiles/server/` has **no `packages.txt`** — server services are greenfield.

**`phi-shell`**
- `Components/Settings/sections/Updates.qml` — a "Packages" group rendering one
  `ManagerBlock` per manager, already showing the AppImage list and labelling
  npm/flatpak as placeholders. Declared **read-only** by design.

Two corrections worth carrying forward: `~/.local/state/phios/` already exists
(it holds the installer manifest), and `opencode` is already official — so the
only non-official part of the agent rebuild is `pi`.

---

## 3. Design

### 3.1 Declaration — `profiles/<profile>/external.txt`

One record per line, `|`-separated, `#` comments, blank lines ignored — the
same shape the repository already uses, readable with `phios_read_list`.

```
# name | tier | source | ref | sha256 | reason
wivrn  | T2 | flathub:io.github.wivrn.wivrn | 0.22   | -       | VR streaming, no official package
foo    | T4 | https://example.org/foo.AppImage | 3.1.2 | a4f9... | required by <course>, no alternative
```

**What goes in this file, and what does not.** `external.txt` starts at T2.
T0 and T1 belong in `packages.txt`: a `[phi]` package comes from a configured
sync repository, so `phios_packages_collect` plus `pacman -T`/`-S` already
install it, `pacman -Qe` already lists it, and `CategoryPhiPackages` already
buckets it. Putting `phi-pi` in `external.txt` would build a second path for
something the installer already does correctly. So §5.2's "T1" outcome means a
line in `packages.txt`, not here.

**Containers are declared too**, with tier `TC` and the image digest as `ref`:

```
prowlarr | TC | docker.io/linuxserver/prowlarr | sha256:9c1f... | - | indexer manager
```

This is why `mini` *does* get an `external.txt`, contrary to a simpler reading
of "server stays official-only". Rootless containers are the one non-pacman
population on that host, so leaving them undeclared would put the single thing
that needs monitoring outside the monitoring — exactly the failure this design
exists to prevent. `mini` carries `TC` entries and nothing else.

- `tier` is explicit, not derived. It records the judgment "this is as high as
  it would go", which is the thing a later reviewer needs.
- `ref` is an exact version or commit hash. **Never `latest`, never a tag** —
  tags move.
- `sha256` is mandatory for T4 and for any fetched artifact; `-` where the
  manager provides its own integrity (pacman, Flatpak).
- `reason` is load-bearing. It is *"every feature names the problem it solves"*
  applied to software, and it is what makes a yearly prune possible.

Scope follows profiles: a host's ladder ceiling is a property of the profiles
it composes, so `mini` is limited to `TC` by construction rather than by a
special case in the tooling.

### 3.2 The closed set of roots

Monitoring is only possible if the places non-pacman software may live are
finite and known. Two roots, neither of which migrates anything that works:

- `~/Applications` — AppImages and single-file binaries. **Already implemented
  and already rendered in Settings.**
- `~/.local/opt/<name>/` — unpacked trees, with symlinks into `~/.local/bin`.

Flatpak keeps its own store; it is not relocatable but is fully enumerable with
`flatpak list`, which is equivalent for our purpose.

**Leak paths**, asserted empty or declared-only:

| Path | Rule |
|---|---|
| `~/.npm-global`, npm prefix, `/usr/lib/node_modules` beyond pacman's | empty |
| `~/.local/lib/python*/site-packages` | empty |
| `~/.cargo/bin`, `~/go/bin` | empty |
| `/usr/local/{bin,lib,share}` | empty — anything here came from a `make install` pacman never saw |
| `~/.local/bin` | only entries in the installer manifest or `external.txt` |

The last one is the nicest result of the existing design: `manifest.sh` already
records every path the installer created, so the check is a diff against
manifest ∪ declaration, with no new bookkeeping.

### 3.3 Containment — `phi-contain`

Generalise `phi-agent-contain` rather than writing a second harness.

- Extract the engine to `phi-contain <profile> [--dry-run] [--workdir D] -- CMD`.
- Containment profiles move to `~/.config/phios/contain/<name>.paths`, reusing
  the existing grammar unchanged.
- A per-profile network mode: `host` | `none` | `proxy:<socket>` — which is
  exactly A1 / A2-without-bridge / A2 today, named instead of branched.
- `phi-agent-contain` becomes a thin wrapper delegating to `phi-contain a1|a2`,
  so agent behaviour is bit-for-bit what it is now.

> **Blocking caveat.** The harness's own header says it has *never run*, and
> refers to verification passes "V-01..V-04" — **that document no longer
> exists**; the identifiers are dangling references to the deleted
> `VERIFICATION.md`. They are replaced by checks C-01..C-06 in Appendix A,
> which are defined here and test the kernel and bubblewrap rather than
> anything phiOS owns. **Phase 0 is exactly this**: prove the containment
> primitive before anything depends on it. Do not reorder.

### 3.4 Monitoring

A new `phi/internal/external` package, surfaced through three `doctor` checks
in a new `internal/doctor/external.go`:

1. **Drift** — enumerate actual state per manager (`pacman -Qm`, `flatpak list`,
   `ls ~/Applications`, `ls ~/.local/opt`) and diff against the union of
   `external.txt` for the host's active profiles. Report **both** directions:
   *undeclared* (something appeared) and *missing* (declared, absent).
2. **Leaks** — the table in §3.2.
3. **Integrity** — verify each recorded `sha256`; for git sources verify HEAD
   equals the pinned commit.

`packageCategories` is **amended, not deleted**: foreign packages stop being an
automatic violation and become a violation *only when undeclared*. The
invariant moves from "zero foreign" to "zero undeclared", which is strictly
stronger because it also covers Flatpak, AppImage and `~/.local/opt`, none of
which `pacman -Qm` ever saw.

**Change detection** is a polled fingerprint: hash `(path, size, mode, mtime)`
across each root, store it, and report a root that changed without
`external.txt` changing. Stored in a new TSV at
`~/.local/state/phios/external-fingerprints` — *not* in `phi state`, whose key
set is deliberately closed and would be wrong for variable-cardinality data.

No watcher daemon. A path unit or inotify watch costs a background process and
produces constant noise (Flatpak updates itself, AppImages write caches), and
genuine tamper detection is a file-integrity tool's job with its own offline
baseline. A shell that approximates intrusion detection hands out a green light
it has not earned.

### 3.5 CLI surface

No new top-level command — `phi` keeps one entry point. Extend `phi pkg`:

- `phi pkg list --manager external [--json]` — declared entries with status.
- `phi pkg audit [--json]` — runs the three checks, non-zero exit on violation.
- `phi pkg accept <root>` — re-baseline a fingerprint after a legitimate update.

`phi doctor` calls the same audit for its summary line, so there is one
implementation and two surfaces.

### 3.6 Settings panel

The user's model is a "Packages" **section**; today it is a group inside
Updates. Promote it: a new `Components/Settings/sections/Packages.qml` taking
the existing Packages group, leaving Updates with system state and the update
flow. Add an `external` `ManagerBlock` with tier badge and per-entry status
(ok / undeclared / missing / changed), and an audit summary at the top.

**The read-only rule is narrowed, not dropped — and the rationale comment in
`Updates.qml` must be edited to say so, rather than quietly contradicted.**

The real boundary is not "the GUI never acts" — `phi vpn` and `phi firewall`
are already driven from Settings through `sudo -n` drop-ins. It is **"the GUI
never runs an interactive privileged transaction."**

| Allowed from the panel | Handed to a terminal |
|---|---|
| Re-baseline a fingerprint (`phi pkg accept`) | `pacman -Syu` / `phi update` — needs a TTY for conflict and provider prompts |
| Open a declaration file or reveal a path | Installing or removing any system package |
| Toggle a `flatpak --user override` | Anything needing a password prompt |
| Re-run the audit | |

### 3.7 Installer integration

Phase it, to keep the installer's blast radius small:

- **Now:** `bin/lib/external.sh` *reads* `external.txt`, includes it in
  `--check` output, and reports drift. It installs nothing.
- **Later, optional:** assisted install for **T2 only**, because `flatpak
  install` is non-interactive, unprivileged with `--user`, and integrity-checked.
- **Never:** T3/T4 fetching. Downloading and executing an arbitrary artifact
  from the installer is the exact risk this whole design exists to bound. The
  declaration is the record; the user installs.

### 3.8 Launcher and app discovery

Verified in `internal/query/apps.go`: `desktopEntryDirs()` scans
`$XDG_DATA_HOME/applications` and then `$XDG_DATA_DIRS`/applications, falling
back to `/usr/local/share:/usr/share` when `XDG_DATA_DIRS` is unset. That
produces two concrete gaps once non-T0 software exists:

- **AppImages are invisible.** A file in `~/Applications` ships no `.desktop`
  entry, so a declared, monitored, correctly-installed school AppImage cannot
  be launched from the runner at all. The plan must therefore **generate a
  `.desktop` entry into `~/.local/share/applications` for every T4 entry**,
  recorded in the installer manifest like any other created path so it is
  removed when the declaration is. This is the piece of "shell integration"
  the requirement asks for.
- **Flatpak visibility is environment-dependent.** Exports live in
  `~/.local/share/flatpak/exports/share/applications` and
  `/var/lib/flatpak/exports/share/applications`, which reach the launcher only
  when `XDG_DATA_DIRS` carries them. The hardcoded fallback does not, and
  `phi query` is a fresh process per keystroke inheriting the session
  environment. Fix by appending the two Flatpak export directories to
  `desktopEntryDirs()` explicitly, rather than relying on the session being
  set up correctly — the same defensive shape the rest of `phi` uses.

A useful side effect of §3.2's leak table: `/usr/local/share` is on the default
scan path, so anything that lands there becomes launchable. The leak check and
the launcher are guarding the same door.

---

## 4. Work breakdown

| Phase | Repo | Deliverable |
|---|---|---|
| **0** | — | **User**: run Appendix A's `phios-contain-check` on `zotac` and on `razer` and report the output. It changes nothing. Nothing below ships until C-01..C-05 pass. |
| **1a** | `phios-dotfiles` | `external.txt` format documented in `profiles/README.md`; `bin/lib/external.sh` parser; `--check` reporting. |
| **1b** | `phi` | `internal/external` (parse, enumerate, diff, fingerprint); `internal/doctor/external.go`; amend `packageCategories`; `phi pkg audit` / `accept` / `--manager external`. Table-driven tests. |
| **1c** | `phi` | `desktopEntryDirs()` gains the two Flatpak export directories; `.desktop` generation for T4 entries, manifest-recorded (§3.8). |
| **2** | `phios-dotfiles` | Extract `phi-contain` as a standalone harness with the `.paths` grammar and named network modes. **Do not** preserve `phi-agent-contain` bit-for-bit — the agent is being rebuilt (§4.1), so the old wrapper is left alone and retired with it. |
| **3** | `phi-shell` | Promote `Packages.qml` to its own section; external `ManagerBlock` with status; audit summary; the two permitted actions; **edit the `Updates.qml` rationale comment**. |
| **4** | mixed | The four test targets, §5. |

Phases 1a and 1b are independent and can run in parallel; 3 depends on 1b's
JSON output; 4 depends on 2 for anything contained.

### 4.1 Sequencing — two questions answered

**Does the new agent have to be designed first? No, and coupling them would be
a mistake.** The containment harness is agent-independent; the agent is one
consumer of it. Because the agent is being rebuilt, building the generic
harness *first* is what stops a second private copy of it from growing inside
the new agent — the new agent inherits `phi-contain` instead of carrying its
own. The agent design blocks exactly one thing: tiering `pi` in §5.2, which is
Phase 4, the last step. Going the other way would also be circular, since the
agent rework itself needs the declaration mechanism for its non-official parts.

This does simplify Phase 2: with the old agent being retired, there is no need
to keep `phi-agent-contain`'s behaviour identical. Extract the harness cleanly
and let the old wrapper retire with the subsystem it serves.

**Does the XDG relayout have to happen first? No — but one naming decision
does.** The plan creates exactly two new paths that fall inside the umbrella
question: the fingerprint file (§3.4) and the containment profiles (§3.3).
Both are greenfield, so they can be written into whichever namespace is chosen
at zero migration cost — *provided the choice is made before they are created*,
otherwise they become two more things to migrate later.

The migration itself is better done **later, and mostly for free**: agent-owned
paths are roughly half of all phiOS XDG references in the tree, and a
from-scratch agent rebuild recreates them anyway. Migrating directories that
are about to be deleted and recreated is wasted work. The one genuinely
misfiled item, `dotfiles-root`, is self-contained but sits on the login-shell
bootstrap path — worth folding into the next installer change rather than
doing as a standalone task with its own risk.

---

## 5. Test targets

Deliberately one per tier, to exercise the whole ladder. None of these is added
to the dotfiles yet — they are the acceptance test for the mechanism.

### 5.1 Neovim plugins — target tier **T1**

The best answer, and the one that removes a dependency rather than adding one:
**package the plugin set as `phi-nvim-plugins` in `phi-packages`**, with pinned
git sources and checksums in the PKGBUILD. Neovim plugins are Lua source, not
binaries; this is exactly how Arch packages them.

That gives signed, pacman-tracked, cleanly-removable plugins, drops `lazy.nvim`
entirely, keeps the no-runtime-git-clone property, and needs **no exception to
rule 1 at all**. Load with `:packadd` over the shared `runtimepath` directory
that the Neovim plan already establishes.

- First check what Arch already ships (`pacman -Ss`) — anything found is T0 and
  needs no package at all.
- Cost to state honestly: each plugin update becomes a package rebuild and a
  signed release, which is friction by design and may be too much for
  fast-moving plugins. If it proves so, the fallback is T3: a contained
  plugin-fetch step with pinned commits, never an unpinned runtime clone.

### 5.2 `pi` — tier **unknown, must be confirmed first**

**Do not assume a distribution channel.** Confirming how `pi` ships is a
prerequisite step, because a wrong guess silently sets the tier.

- If it is packaged for Arch → T0, done.
- If it ships as source → T1, a `phi-pi` PKGBUILD, which is the preferred
  outcome given it is a permanent phiOS component (population C).
- If npm-only → T1 vendoring the pinned tarball, or T3 with an npm prefix
  inside the container.

Independent of tier: `pi` is a coding agent, so it runs **contained** either
way. The existing A2 profile — `--unshare-net` plus a socat/tinyproxy egress
whitelist, no ambient environment, one writable working directory — is the
right shape and already exists. `AiAgent.qml` is already correct that the
code-blocklist is *"a guard-rail on the picker, not the security boundary"*: an
in-process blocklist is advisory, and the boundary is the mount set.

### 5.3 WiVRn — target tier **T2**

Needs GPU (`/dev/dri`), headset access over USB or network, and a running
service. That is a poor fit for bubblewrap: a VR runtime under `--unshare-net`
is a different shape from an agent, and the device and Vulkan surface is wide.

Flatpak is the better fit — it can grant device access through overrides and is
the only tier with real sandboxing. Plan: **T2 if it is on Flathub, T4 with a
checksum if not.** `zotac` and `razer` only; never `mini`.

Open: whether the Monado/OpenXR runtime registration works from inside a
Flatpak for host applications, which decides whether T2 is usable at all.
Answer this before building anything around it.

### 5.4 Prowlarr stack — **rootless containers on `mini`**

The cleanest of the four: rootless containers are rule 1's stated exception,
and this is greenfield — `profiles/server/` has no `packages.txt` to disturb.

- Create `profiles/server/packages.txt` with `podman` (verify it is in `extra`).
- Quadlet `.container` units under `profiles/server/system/`, following the
  repository's existing "versioned, never applied" rule — the user applies them
  by hand.
- Data under `/srv`, which is already the unlocked LUKS volume.
- Pin image digests, not tags — recorded as `TC` entries in a new
  `profiles/server/external.txt` (§3.1), which is the first `external.txt` any
  host gets.

Two constraints to face early: **`mini` has 4 GB of soldered RAM** and the *arr
stack is memory-hungry, so the stack's composition needs sizing before it is
chosen; and container images are a supply chain of their own — pin by digest
and prefer a single well-known publisher.

---

## 6. Risks and open questions

1. **The containment base is unverified.** `phi-agent-contain` has never run,
   and the verification passes it cites were deleted with `VERIFICATION.md`.
   Appendix A replaces them. Phase 0 is not optional.
2. **`pi`'s distribution channel is unknown** and determines its tier. It is
   also downstream of an agent design that does not exist yet (§4.1), so it is
   the last target, not the first.
3. **WiVRn's OpenXR runtime registration from a Flatpak** may not work for host
   applications; it decides T2 vs T4.
4. **`mini`'s 4 GB** may not fit the intended *arr stack.
5. **Plugin packaging friction** — §5.1's fallback exists for a reason.
6. **Fingerprint noise.** Some roots legitimately churn. If re-baselining
   becomes routine, the fingerprint is worthless — measure this before relying
   on it, and narrow the hashed set rather than lowering the bar.
7. **`external.txt` is a new file the installer must not over-trust.** It is
   repository content and therefore reviewed; but the checksums it carries are
   only as good as the review that added them.

---

## 7. Definition of done

- Rule 1 in `AGENTS.md` states the ladder and the per-host scope. *(done)*
- `external.txt` is parsed by both the installer and `phi`, from one documented
  format.
- `phi pkg audit` reports drift, leaks and integrity, and `phi doctor`
  summarises it.
- `packageCategories` asserts zero **undeclared**, not zero foreign.
- `phi-contain` exists, the agent goes through it, and its `--dry-run` argv is
  unchanged from `phi-agent-contain`'s.
- Settings has a Packages section with per-entry status and the two permitted
  actions, and `Updates.qml`'s rationale comment reflects the narrowed rule.
- A T4 entry is launchable from the runner, and a Flatpak app appears there
  without depending on how `XDG_DATA_DIRS` happens to be set.
- The four targets in §5 are each tiered, declared, and installed by the user —
  the end-to-end test of the mechanism.

---

## Appendix A — `phios-contain-check` (Phase 0)

The concrete replacement for the dangling V-01..V-04 references. It tests the
kernel and bubblewrap, not anything phiOS owns, so it is valid regardless of
what happens to the agent. It installs nothing, writes nothing outside a temp
directory it removes, and needs no privileges.

It lives at **`scripts/phios-contain-check.sh`** in this superproject, so
`scripts/sync.sh` carries it to every machine. Run it on `zotac` and on
`razer`; C-01..C-05 must pass, C-06 only matters if the proxied-egress shape is
adopted. If it graduates to a permanent tool it belongs at
`phios-dotfiles/bin/phios-contain-check`, beside `phios-capabilities`.

The copy below is kept in sync by hand and is here so the plan stays readable
on its own.

```bash
#!/usr/bin/env bash
#
# phiOS — containment preflight (Phase 0 of docs/external-packages-plan.md).
#
# Proves that bubblewrap containment works on THIS machine. It is deliberately
# independent of the agent: it tests the kernel and bwrap, nothing phiOS owns.
#
# Run as your normal user, on zotac and on razer. It changes nothing: no
# install, no systemctl, no writes outside a temp dir it removes.

set -uo pipefail

pass=0; fail=0
ok() { printf '  \033[32mok\033[0m    %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }

# The minimal container the harness builds: /usr read-only, the Arch symlinks,
# pseudo-filesystems, and no environment at all.
base=(
	--unshare-user-try
	--ro-bind /usr /usr
	--symlink usr/bin /bin --symlink usr/bin /sbin
	--symlink usr/lib /lib --symlink usr/lib /lib64
	--proc /proc --dev /dev --tmpfs /tmp
	--clearenv --setenv PATH /usr/bin
)

echo
echo "C-01  bubblewrap present and runnable"
if command -v bwrap >/dev/null 2>&1 && bwrap --version >/dev/null 2>&1; then
	ok "$(bwrap --version)"
else
	no "bwrap missing or not runnable"
	echo; echo "STOP — install bubblewrap before anything else."; exit 1
fi

echo "C-02  unprivileged user namespaces enabled"
unpriv=1
if [[ -r /proc/sys/user/max_user_namespaces ]] \
	&& [[ "$(< /proc/sys/user/max_user_namespaces)" == 0 ]]; then unpriv=0; fi
if [[ -r /proc/sys/kernel/unprivileged_userns_clone ]] \
	&& [[ "$(< /proc/sys/kernel/unprivileged_userns_clone)" == 0 ]]; then unpriv=0; fi
if ((unpriv)); then ok "available"
else no "disabled by sysctl — T3 containment is impossible on this kernel"; fi

echo "C-03  the full namespace set the harness uses"
if bwrap "${base[@]}" \
	--unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup \
	--new-session --die-with-parent \
	-- /usr/bin/true 2>/dev/null
then ok "container starts and executes a binary"
else no "one of the namespace flags is refused by this kernel"; fi

echo "C-04  \$HOME is invisible unless explicitly bound"
if bwrap "${base[@]}" -- /usr/bin/test -d "$HOME" 2>/dev/null
then no "\$HOME WAS VISIBLE inside the container — containment is not working"
else ok "\$HOME unreachable, as required"; fi

echo "C-05  --unshare-net leaves no network at all"
if bwrap "${base[@]}" --unshare-net \
	-- /usr/bin/timeout 5 /usr/bin/curl -sS --max-time 4 https://archlinux.org \
	>/dev/null 2>&1
then no "NETWORK REACHABLE inside --unshare-net — egress control would be a lie"
else ok "no network, as required"; fi

echo "C-06  a bound unix socket still crosses the netns boundary (optional)"
if ! command -v socat >/dev/null 2>&1; then
	printf '  skip  socat not installed — only needed for proxied egress\n'
else
	d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
	socat UNIX-LISTEN:"$d/t.sock",fork EXEC:'/usr/bin/echo phios-ok' >/dev/null 2>&1 &
	sp=$!
	sleep 0.4
	got=$(bwrap "${base[@]}" --unshare-net --bind "$d" /run/br \
		-- /usr/bin/timeout 5 /usr/bin/socat -T3 - UNIX-CONNECT:/run/br/t.sock 2>/dev/null)
	kill "$sp" 2>/dev/null
	if [[ $got == *phios-ok* ]]
	then ok "socket bridge works — the proxied-egress shape is viable"
	else no "socket bridge did not return (re-run once; a slow listener can race)"; fi
fi

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
if ((fail)); then
	echo "Containment is NOT proven on this machine. Send me the output above."
	exit 1
fi
echo "Containment proven. Phase 1 can proceed."
```
