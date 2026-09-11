# Features to be verified

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.

---

## Reset the clipboard tab every time the panel opens

- **Date:** 2026-09-11
- **Repo / branch:** phi-shell / dev
- **Commits:** ccf5477 clipboard: reset selection, filter and scroll every time the panel opens
- **Original TODO:** clipboard should reset the current selection every time it's opened, starting back from the top.

### What was asked
Every time the notification panel is opened on the Clipboard tab, it
should start from a clean state: no leftover search filter, the first
entry selected, scrolled to the top — not whatever was left over from the
last time it was open.

### What was done
Found the cause in `Panels/Sidebar.qml`: the tab content is a `Loader`
whose `sourceComponent` only changes when the active tab index changes —
opening and closing the whole panel just toggles `PanelWindow.visible`
upstream, it does not touch the Loader, so the Clipboard tab's `Item` is
never destroyed by a plain show/hide. That means `Component.onCompleted`
(where the reset already happened) only ever ran the very first time the
Clipboard tab was opened in a session; every later reopen — panel closed,
then reopened while still parked on that tab — kept the old search text,
selection and scroll offset.

`Panels/tabs/Clipboard.qml`: moved the existing reset logic into a
`reset()` function, called from `Component.onCompleted` as before, and
now also from a `Connections { target: Services.NotificationPanel;
function onShownChanged() { ... } }` block that fires on the `shown`
transition to `true` — the same `Connections`/`onXChanged` shape already
used the same way in `Settings.qml`, `Spotlight.qml` and `Launcher.qml`,
so nothing new was introduced stylistically. Also added `list.contentY =
0` to the reset (`list` is the id given to the entry `Flickable`, which
previously had no id) — nothing previously reset the scroll position, only
`highlightedIndex`, so "starting back from the top" was only half true
even within a single session.

### Honest assessment
- **Cannot verify visually** — phi-shell's own rule: "you cannot run
  this," every visual result needs the user's own screenshot. This is a
  logic fix (state reset on a property-changed signal), not a visual one,
  so it was reviewed by reading the surrounding code and cross-checking
  the `Connections` pattern against four other files that already use it
  the same way, not by running it.
- One behaviour to be aware of, not a bug: opening the panel straight onto
  the Clipboard tab (`Super+Shift+V`, which sets the tab index *and*
  `shown` together) can run `reset()` twice in a row (once from
  `Component.onCompleted` as the Loader creates the item, once from the
  `Connections` handler as `shown` becomes true right after) — harmless
  since `reset()` is idempotent, just a redundant `Services.Clipboard.refresh()`
  call, not a state problem.
- Switching tabs away from Clipboard and back while the panel stays open
  already reset correctly before this change (a tab switch gives the
  Loader a new `sourceComponent`, so a fresh `Item` is created either
  way) — untouched by this fix, still works the same way.

### How to test it
1. Build `phi-shell` from this branch and reload Quickshell (`pkill -x qs;
   qs -p ~/.config/quickshell/phi`), or just save any `.qml` file to
   trigger its hot reload.
2. Copy two or three different things to the clipboard so there's more
   than one entry.
3. Open the panel onto the Clipboard tab (`Super+Shift+V`), type a few
   characters into the filter box, and press Down/Tab a couple of times so
   a later entry (not the first) is highlighted.
4. Close the panel (click outside it, or `Super+N`) without selecting
   anything.
5. Reopen it onto the Clipboard tab again (`Super+Shift+V`). Before this
   fix: the filter text and the previously-highlighted entry were still
   there. After this fix: the filter box is empty, the first entry
   (topmost, pinned entries first) is highlighted, and if the list had
   been scrolled, it is back at the top.

---

## Recognise phi verbs in the launcher without the "phi " prefix

- **Date:** 2026-09-11
- **Repo / branch:** phi / dev
- **Commits:** 3e7d49a query: recognise phi's own verbs without the leading "phi "
- **Original TODO:** runner bar should read phi commands without writing the phi prefix (eg. "theme set dark" is recognised as "phi theme set dark")

### What was asked
Typing a `phi` verb straight into the launcher, e.g. `theme set dark`,
should be recognised as if `phi ` had been typed first, and offered as a
result that runs `phi theme set dark`.

### What was done
Added `PhiCommandProvider` (`internal/query/phicommand.go`): it fires when
the query's first word matches one of phi's own verb names, and offers a
result whose action runs `phi <the whole query>` in a terminal — the same
`ActionExecTerminal` action `CommandProvider` already uses for "phi theme
set dark" typed in full (so it fires because `phi` itself resolves as a
PATH binary), so output stays visible either way.

The verb list comes from `view.Commands` — the single list `phi help`,
zsh completion and the man page already render from — so a verb added
there needs nothing else touched. It's passed in by `internal/cli` rather
than imported straight into `internal/query.Providers`, because
`internal/view` already imports `internal/query` (to render
`QueryResults`); the reverse import would be a cycle. `Providers()` picked
up a second parameter for this (`phiVerbs map[string]bool`); it has
exactly one call site (`internal/cli/query.go`), now updated.

Placed in the same `tierAction` band as `CommandProvider`, `system`, `ssh`
and `directory` (from the ranking fix earlier in this same session — see
the entry above).

### Honest assessment
- **Verb match is on the first word only**, case-insensitive, with no
  minimum query length — typing just `doctor` recognises `phi doctor`
  exactly as `theme set dark` recognises `phi theme set dark`. But for a
  *bare single-word* verb with no other candidate competing (an app, a
  file, a window), a **pre-existing, unrelated quirk in the calculator
  engine** (`internal/mathx`) often wins instead: it treats any single
  unrecognised word as a one-variable expression and offers to *plot* it
  (`evalNumeric` in `internal/mathx/engine.go` — "if there is exactly one
  free variable... the useful answer is a plot of it"). E.g. `phi query
  doctor` today ranks `y = doctor` (a spurious plot) above `phi doctor`,
  because that path sits in this session's own math tier, above the
  action tier `phi doctor` sits in. Multi-word verb invocations like
  `theme set dark` are unaffected — the calculator's parser doesn't treat
  three bare words as one plottable expression, so it produces nothing
  there. Left alone rather than fixed here: it's a mathx behaviour with
  its own separate cause, not something this TODO entry named, and
  narrowing what mathx treats as "one free variable worth plotting" is a
  bigger, riskier change than this entry asked for. Worth its own backlog
  entry if it bothers you in practice.
- Not run against `phi-shell`'s actual launcher UI (no compositor here) —
  verified with `go build ./...`, `go vet ./...`, `go test ./...`, and
  manual `phi query "<text>"` runs from a terminal.

### How to test it
1. From a terminal, on a machine with this branch: `phi query "theme set
   dark"` (or, with the shell running, type the same into the launcher).
   Confirm a result titled `phi theme set dark` appears, and selecting it
   opens a terminal running `phi theme set dark`.
2. Try a few more: `phi query "vpn status"`, `phi query "firewall status"`
   — each should offer to run the equivalent full `phi …` command.
3. Try a bare single-word verb, e.g. `phi query "doctor"` — see the
   Honest Assessment above: today this may rank a spurious calculator
   plot above the `phi doctor` result rather than putting it first.
4. Try a word that is not a phi verb, e.g. `phi query "firefox"` — no `phi
   …` result should appear at all.

---

## Rank launcher results by category before match quality

- **Date:** 2026-09-11
- **Repo / branch:** phi / dev
- **Commits:** 6b5f4c9 query: rank by category tier before match quality
- **Original TODO:** ranking for the runner should be rearranged in a reasonable way. Currently it has latest features appearing first (like the calculator) but it does not make sense. Apps should be always first, non hidden files second, math when obvious,

### What was asked
The launcher's result ranking felt wrong — the calculator was showing up
above things like applications, which doesn't match how the launcher is
actually used. The requested order: applications first, always; non-hidden
files second; math results third, and only when the query is unambiguously
math.

### What was done
`phi query`'s ranking (`internal/query/rank.go`) previously scored every
provider on one shared 0–100-ish scale. `CalculatorProvider` and
`CurrencyProvider` trust their own confidence and set a flat `Score: 100`
(matchWeight can't judge a numeric answer like "4" against the query "2+2"
that produced it), which routinely tied or beat a genuine exact-title app
match — that's the reported bug.

Added a `providerTier` band per provider category, spaced 1000 apart (well
clear of the largest possible per-query contribution: 100 from matchWeight
+ 15 from frecency), added on top of whatever score a provider already
computed. Category now always dominates; match quality and frecency only
decide order *within* a category. Order, highest first: applications, open
windows, files, math (calculator + currency), then the narrower/deliberate
providers (system actions, ssh hosts, zoxide, run-command), then web
search last.

Two things not explicitly named in the TODO entry, decided by judgment:
- **Windows sit just under apps**, not with files. `query.go`'s own header
  already calls switching to an open window "likely the most frequent
  launcher action on a tiling compositor" — closer in kind to launching
  than to a file search.
- Everything else the TODO entry didn't name (system actions, ssh hosts,
  zoxide, run-command, web search) kept its previous *relative* order
  (already established by each provider's own flat Score), just moved
  below math as a block, since each is a narrower, more deliberate action.

"math when obvious" is read as already true today: `CalculatorProvider` /
`CurrencyProvider` only produce a result once `mathx` actually parses the
query as math or a currency conversion — this change only affects where
that result ranks once it exists, not whether it appears. "Non hidden"
files come from `fd`'s own default (it excludes dotfiles/gitignored paths
unless told otherwise) — no explicit flag was added.

### Honest assessment
- **Consequence worth flagging:** typing the exact name of an app that is
  already open now always ranks "launch a new instance" above "switch to
  that open window", because `tierApps` unconditionally beats
  `tierWindows`. That follows literally from "Apps should be always
  first," but it may not be what's wanted day-to-day — easy to swap
  (`tierApps`/`tierWindows` are two lines in `rank.go`) if so.
- The tier boundaries for the categories the TODO entry didn't name
  (system/ssh/zoxide/command all share one "action" tier, below math) are
  a judgment call, not something requested — flag if any of those feel
  wrong once used for real.
- Not run against real launcher usage or `fzf` (`rank_test.go`'s own
  header already notes this limitation predates this change) — verified
  with `go test ./...`, `go vet ./...`, and manual `phi query` runs from a
  terminal, not on real hardware with the shell attached.
- Confirmed `phi-shell`'s `Launcher.qml` never reads `Result.Score` (it
  only renders the list `phi query` already returned in order), so scores
  moving from ~0–100 to ~0–5115 is safe — it's an internal ranking value,
  not part of the JSON contract the shell interprets.

### How to test it
1. On a machine with `phi` built from this branch (or after the next
   package build once this reaches `main`), open the launcher and type an
   application name that also happens to look like it could match another
   category — e.g. a query that both an app title and a calculator
   expression could answer.
2. Confirm the application result appears above any calculator/currency
   result, regardless of how exact the app-title match is.
3. Type a partial file name (something under `$HOME`, at least 2
   characters) that also loosely matches an installed application's title
   — confirm the application still ranks above the file, and the file
   ranks above any calculator result.
4. Type a plain arithmetic expression, e.g. `2+2` — confirm it still
   appears (math results are unaffected when nothing else matches).
5. From a terminal, `phi query "<your query>" | jq .` also works without
   the shell — each result's `score` field shows the new tier bands
   (5000s = apps, 4000s = windows, 3000s = files, 2000s = math, 1000s =
   the rest, 0s = web search) if you want to see the ordering directly.

---
