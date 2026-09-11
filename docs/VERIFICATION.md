# Features to be verified

Finished work waiting for the user to check and sign off. Newest first.
Agents append a section per completed item using the template in
`AGENTS.md` (*The TODO / VERIFICATION loop*). The user deletes an entry
once it is verified.

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
