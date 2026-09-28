# Agent panel rework — design study and contract

Status: implemented in phi v0.25.0, phi-shell `dev`, phios-dotfiles `dev`.
Scope: `phi-shell` agent panel (`Components/AgentPanel/`, `Services/Agent*.qml`),
Settings › AI Agent, the `phi agent serve` API and CLI verbs it needs, and one
first-party pi extension.

This file is both the design study (§1–§4) and the binding contract every
implementation step is written against (§5–§9). §10 is the phase plan.

---

## 1. What the panel is for

The panel is the one place the user talks to the agent and watches it work.
Settings › AI Agent is where the agent *system* is configured, monitored and
debugged. The split is by frequency: anything done several times a day lives
in the panel; anything done when setting up or diagnosing lives in Settings.

### 1.1 Jobs, ranked by frequency

| # | Job | Frequency | Context | What it needs |
|---|---|---|---|---|
| J1 | Ask something quickly | many times a day | mid-task, summoned by Super+P, back to work in seconds | composer focused on open, last chat or a new one, Enter sends, Esc closes |
| J2 | Continue or find a conversation | daily | returning to a topic | sidebar grouped by recency, live/busy markers, search |
| J3 | Watch a long agentic turn | daily | agent reading files, planning, delegating | thinking, tool calls, plan progress, subagents, context and cost — scannable, not noisy |
| J4 | Steer a running turn | daily | agent going the wrong way | steer, queue a follow-up, stop — without losing typed text |
| J5 | Answer the agent | when asked | an extension or `ask_user` needs a decision | an input card in the timeline, a bar cue when the panel is closed |
| J6 | Watch coding sessions | daily | pi TUI running in a terminal | what each session is doing now, jump to its window, review its timeline |
| J7 | Manage projects | weekly | setting up work | folders, instructions, attachments, memory, its chats and coding sessions |
| J8 | Check the system | weekly, or when something is off | "is it running, what did it cost, what failed" | one overview: health, live work, usage, schedule, proposals, errors |
| J9 | Run prompts unattended | occasionally | a nightly digest, a periodic check | scheduled prompts with cost caps |
| J10 | Configure and debug | rarely | setup, provider change, failure | Settings › AI Agent: prefs, providers, services, logs |

### 1.2 Principles

1. **The conversation is the product.** Every monitor lives next to it (the
   inspector) or summarised above it (the status line), never in front of it.
2. **Progressive disclosure.** A tool call is one line; its arguments and
   output are one click away. Thinking streams live and folds to "Thought for
   12 s" when it ends. A subagent is one card that expands into its own feed.
3. **State is always visible, never modal.** Busy, waiting for input, offline,
   out of date, compacting, retrying — each has one stable place and one
   wording. Nothing blocks the composer except "offline".
4. **Nothing typed is ever lost.** Drafts persist per chat while the shell
   runs; a failed send restores the text; Stop returns queued messages to the
   composer.
5. **Keyboard first, pointer complete.** Every action has a pointer path; the
   frequent ones have a key.
6. **Motion follows the taxonomy.** B (transition) for panel, drawer and
   section changes; A (ambient) only for "working" indicators; nothing
   animates per token.
7. **Honest numbers.** Tokens and cost come from pi's own usage records.
   Where a number is an estimate (context after compaction), it says so.

---

## 2. Information architecture

A left-edge dock (unchanged position and entry points: bar Φ, Super+P,
`qs ipc call agent …`). Four sections on the header tab strip:

| Section | Key | Purpose | Jobs |
|---|---|---|---|
| **Chat** | Ctrl+1 | conversations: sidebar, timeline, composer, inspector | J1–J5 |
| **Code** | Ctrl+2 | coding sessions: live cards, timeline viewer, launcher | J6 |
| **Projects** | Ctrl+3 | project list and detail | J7 |
| **Overview** | Ctrl+4 | health, live work, usage, schedule, proposals, errors | J8, J9 |

The header also carries a **status pill** (right end, before the settings
gear): a dot (engine up / down / out of date), the number of running turns
and today's cost, e.g. `● 2 running · $0.41`. Clicking it opens Overview.

### 2.1 Dock width

Three widths, cycled with Ctrl+\\ or the header width button, remembered in
`AgentPrefs`:

| Mode | Width | Chat layout |
|---|---|---|
| compact | min(46% screen, 72 ch) | timeline only; sidebar and inspector are overlay drawers |
| regular | min(62% screen, 110 ch) | sidebar + timeline; inspector is an overlay drawer |
| wide | min(86% screen, 170 ch) | sidebar + timeline + pinned inspector |

---

## 3. Sections

### 3.1 Chat

```
┌ sidebar (26ch) ─┬ conversation ───────────────────────┬ inspector (34ch) ┐
│ [+ New chat]    │ project › title   ● general · model │ Context ▓▓▓░ 38% │
│ scope: All ▾    │ ─────────────────────────────────── │ Usage  in/out/$  │
│ / search        │ you  ………                            │ Model  ▾ Think ▾ │
│ ★ Pinned        │ ▸ Thought for 12 s                  │ Plan   3/5 ▓▓▓░  │
│ Today           │ ✓ read  src/main.go          0.2 s  │ Subagents (2)    │
│  ● chat (busy)  │ ⟳ bash  go test ./...               │ Queue (1)        │
│  ◆ chat (asks)  │ ┌ subagent: survey the api ───────┐ │ Files touched    │
│ Yesterday       │ │ 4 tools · 12k tok · running     │ │ Extension status │
│ Earlier         │ └─────────────────────────────────┘ │                  │
│                 │ agent text (markdown)               │                  │
│                 │ model · 12.4k in · 820 out · $0.03  │                  │
│                 │ ─────────────────────────────────── │                  │
│                 │ [📎 img] message…      [think][Send] │                  │
└─────────────────┴─────────────────────────────────────┴──────────────────┘
```

**Sidebar.** "New chat" (primary), a scope selector (All chats · Unfiled ·
each project) that filters the list and defaults new chats, a search field
(`phi agent search`, results replace the list while the field has text),
then Pinned, Today, Yesterday, Earlier. A row shows title, project (when the
scope is All), and a state glyph: `●` running (ambient pulse), `◆` waiting
for input, `!` last turn failed, nothing when idle. Hover reveals pin and a
`⋯` menu (rename, export, close, delete). Alt+Up/Down moves between chats.

**Conversation header.** Breadcrumb (`project › title`, click title to
rename inline), profile badge, model chip, a thin context meter under the
header line (accent, turns warn at 80 %, error at 95 %), and actions: pin,
inspector toggle (Ctrl+I), `⋯` (export Markdown to clipboard, open project,
compact now, close session, delete).

**Timeline.** One virtualised `ListView` over a flat row model (§7.2). Row
kinds and their rendering:

| Row | Rendering |
|---|---|
| `user` | right-aligned inverted bubble, plain text, image count chip, copy on hover |
| `thinking` | a fold line: live "Thinking…" with streaming faint text while streaming; "Thought for N s" folded when done; click toggles |
| `text` | markdown (plain text while streaming, markdown on block end), copy on hover |
| `tool` | one line: status glyph (`⟳` running, `✓`, `✗`), tool name, one-line summary (path, command, pattern), duration; click expands arguments (mono) and output (mono, capped, "show all" to 20 k) |
| `tool:plan` | a checklist card: steps with status glyphs, progress fraction; the *latest* plan also feeds the inspector |
| `tool:subagent` | a card: task, status, live nested activity (last 5 steps), tokens, cost, elapsed; expands into its full feed and final answer |
| `tool:ask_user` | question and the answer given (or "cancelled") |
| `dialog` | "The agent is asking": title, message, options as buttons, or a text field; countdown when the request has a deadline; answering removes it |
| `turnEnd` | faint footer: model · input · output · cache · cost · duration; a retry action on an error turn |
| `error` | error-toned card with the provider message and "Retry last message" |
| `compaction` | divider "Context compacted · 150 k → 32 k tokens" (expand: summary) |
| `notice` | faint one-liners: model changed, thinking level changed, retrying 2/3 in 4 s, branch summary |
| `bash` | a user-run bash block (not used by the panel today, rendered for completeness of transcripts) |

Autoscroll follows the bottom only while the user is at the bottom; when
scrolled up a "↓ new activity" chip appears. Long chats stay fast because
only visible rows are instantiated.

**Composer.** Multi-line field (grows to 8 lines), attachment chips (image
files: paste from clipboard with Ctrl+V when the clipboard holds an image,
or "Attach image…" picks the latest screenshot or a path), a profile chip
(new chats only), thinking-level chip, model chip, and the send control.

| State | Enter | Shift+Enter | Alt+Enter | Button | Ctrl+. / Stop |
|---|---|---|---|---|---|
| idle | send | newline | — | Send | — |
| busy | queue follow-up (pref: or steer) | newline | steer (the other one) | "Queue" | stop: clears the queue into the composer, aborts |
| offline | disabled, text kept | | | Start service | |

The queue shows above the field as removable chips ("steer: …", "then: …").
Typing `/` at the start opens a command palette from the session's pi
commands (skills, prompt templates). Up in an empty composer recalls the last
sent message. Drafts persist per chat.

**Inspector.** Pinned in wide mode, a drawer otherwise. Groups, each hidden
when empty: Context (meter, tokens / window, "Compact now"), Usage (session
tokens in/out/cache, cost, turns, tool calls), Model and Thinking (pickers,
applied to the live session or on the next prompt), Plan (latest plan tool
state), Subagents (each with state; click scrolls the timeline to it), Queue,
Files touched (read / modified, from tool rows; click copies path), Extension
status and widgets (pi `setStatus` / `setWidget`).

### 3.2 Code

Coding sessions are pi's terminal UI (`phi agent code`), by decision
(phios-agente-pi.md §3, TUI over GUI). The panel monitors and launches them;
it never becomes a second coding UI.

- **Running** cards: directory (middle-elided), project, model, elapsed,
  state (`working` — transcript written in the last 10 s; `waiting` — last
  assistant turn ended with `stop`; `idle`), the current activity line
  ("bash: go test ./…"), plan progress, tokens and cost. Actions: Focus
  window, View timeline.
- **New coding session**: a project's rw folder or a typed path, opens a
  terminal running `phi agent code`.
- **Ended** sessions, grouped by day: View timeline (read-only).
- **Timeline viewer**: the same Timeline component as Chat, read-only, live
  refreshed while the session is active (`coding.changed` events).

### 3.3 Projects

List (title, description, default profile, counts: chats, coding sessions)
and "New project". Detail page with a back action (Esc): Overview
(description, default profile, "New chat here", "New coding session here"),
Instructions, Folders (name, ro/rw toggle, per-host path, add/remove),
Attachments (list, add path, remove — through `phi agent project
attachment`), Memory (project memory text, pending proposals with the
literal diff and accept/reject), Chats (list, opens in Chat), Coding
sessions, Usage (this project, 30 days).

### 3.4 Overview

- **Health strip**: engine (`phi-agent.service`), broker a1, a2, proxy —
  each a dot and a word; engine version and API level; "out of date" banner
  when the API level is below the shell's (§5.1). Start/restart actions.
- **Running now**: every live chat turn and active coding session with its
  activity line; click jumps to it.
- **Needs you**: pending dialogs and memory proposals (with the literal diff
  review, accept/reject).
- **Usage**: today / 7 d / 30 d tokens and cost; a 30-day DotGraph of daily
  cost; split by profile and by model.
- **Schedule**: jobs with next run, last result, enabled toggle, Run now,
  edit, delete, "New scheduled prompt". A caption states that jobs fire only
  while `phi-agent.service` runs and only when the scheduler is enabled in
  Settings.
- **Recent errors**: the last errors from the engine log, each with session
  and time; "Open logs" goes to Settings › AI Agent › Logs.

### 3.5 Settings › AI Agent

Settings configures and diagnoses; it does not chat. Groups:

1. **Engine** — Activation (start/stop `phi-agent.service`), Start at login
   (enable/disable), status line (up/down, version, API level, live
   sessions), Restart, Open agent panel.
2. **Defaults** (phi prefs, §8) — default profile for new chats; default model
   and thinking level per chat profile; idle close minutes; dialog timeout.
3. **Panel behaviour** (shell prefs, §9.3) — Enter while busy (follow-up or
   steer), thinking display (expanded / folded / hidden), tool detail
   (compact / expanded), notify when a background turn finishes (off / long
   turns / always), notify when the agent asks, open last chat on summon,
   daily cost warning threshold.
4. **Providers and models** — per profile: providers and base URLs from
   `models.json`, the models pi reports, key presence per broker instance;
   Edit buttons (terminal editor) and Restart.
5. **Usage** — today / 7 d / 30 d, per profile, per model, per project;
   broker request count.
6. **Scheduler** — enable, daily cost cap, catch-up policy; link to Overview
   for the jobs themselves.
7. **Coding** — A2 support services, egress whitelist entry count, the
   blocklist editor.
8. **Memory** — system and per-profile memory text (read-only view, Open in
   editor), pending proposal count with a link to the panel.
9. **Services** (advanced) — every unit with active/enabled state, Restart
   and "Journal" (opens `journalctl --user -fu <unit>` in a terminal).
10. **Logs** — live engine log (level filter, session filter, follow),
    recent broker requests (time, instance, status, model, duration), Copy.
11. **Maintenance** (advanced) — `phi agent init`, prune ended coding-session
    records.

Removed: the duplicated "pending proposals" row, the low-level broker
listen/auth-header readouts outside Advanced, the caption referring to
retired behaviour, and every shell-side file read (models.json, meter,
broker.json are now read through phi).

---

## 4. Cross-cutting behaviour

- **Bar Φ.** Ambient breathe while any chat turn or coding session is
  working; an accent dot when something needs the user (dialog pending,
  proposals, failed turn); hover shows "2 running · 1 asking · $0.41 today".
- **Notifications** (via the shell's own notification server, `notify-send
  -a "phi agent"`): a background turn finished (pref), the agent asks
  (pref), a scheduled job finished or hit its cap.
- **Offline.** Chat and Code need the API, so they show the diagnosis card
  (which unit is down, whether a key is configured) with Start service and
  Recheck. Projects and the proposal review work from the CLI and stay usable.
- **Out of date.** If `/health.api` is missing or below the shell's
  required level, the panel shows a single banner: "phi is older than this
  shell — rebuild and install phi ≥ 0.25.0" and falls back to basic chat.
- **Keyboard map.**

| Key | Action |
|---|---|
| Super+P | toggle panel |
| Esc | blur field → back one level → close |
| Ctrl+1…4 | sections |
| Ctrl+N | new chat |
| Ctrl+F | search chats |
| Ctrl+B | toggle sidebar |
| Ctrl+I | toggle inspector |
| Ctrl+\\ | cycle dock width |
| Ctrl+. | stop the running turn |
| Alt+Up / Alt+Down | previous / next chat |
| Enter / Shift+Enter / Alt+Enter | send / newline / alternate queue mode |

---

## 5. API contract — `phi agent serve` (API level 2)

Loopback `127.0.0.1:4199`, JSON bodies, errors as `{"error": "…"}` with a
4xx/5xx status. Level 1 endpoints keep their behaviour.

### 5.1 Health and overview

`GET /health` → `{"ok":true,"version":"0.25.0","api":2,"startedAt":RFC3339}`.
A missing `api` means level 1.

`GET /overview` →
```json
{
  "api": 2, "version": "0.25.0", "startedAt": "…",
  "live": [SessionRow…],                 // live chat sessions only
  "coding": [CodingRow…],                // active coding sessions only
  "dialogs": 1,                          // pending dialogs, all sessions
  "usageToday": Usage,                   // §5.6
  "scheduler": {"enabled": false, "next": {"job": "id", "title": "…", "at": "…"} | null},
  "errors": [LogEntry…]                  // last 10 error-level log entries
}
```

### 5.2 Sessions

`SessionRow` (GET /sessions rows; level 1 fields plus new ones):
```json
{"id","title","profile","project","pinned","updated","live","busy",
 "activity": "",          // §5.4 activity string, "" when idle
 "needsInput": false,     // a dialog is pending
 "failed": false,         // the last assistant message ended with stopReason "error"
 "scheduled": ""}         // schedule job id that created it, "" otherwise
```

`POST /sessions` body `{"profile","project","model":"provider/id"?, "thinking"?, "title"?}` → `201 {"id"}`.
`model`/`thinking` override the prefs defaults (§8) for this session.

`GET /sessions/{id}/timeline` → `Timeline` (§6). For a live session it is
built from pi `get_entries`; otherwise from the session JSONL. Both go
through the same normaliser. A live session also carries `pending`: the
in-progress turn's blocks accumulated from events (§6.3), so a client that
opens a busy chat mid-turn sees what has streamed so far.

`GET /sessions/{id}/state` →
```json
{
  "id", "live": true, "busy": true, "activity": "bash: go test ./...",
  "compacting": false,
  "retry": {"attempt":1,"maxAttempts":3,"delayMs":2000,"error":"…"} | null,
  "model": Model | null,            // pi model object subset: provider,id,name,contextWindow,reasoning,input
  "thinkingLevel": "medium",
  "thinkingLevels": ["off","minimal","low","medium","high"],
  "queue": {"steering": ["…"], "followUp": ["…"]},
  "dialogs": [Dialog…],
  "status": {"key": "text"},        // extension setStatus
  "widgets": {"key": ["line"]},     // extension setWidget
  "stats": Stats
}
```
For a session that is not live: `live:false`, `busy:false`, `model`
reconstructed from the last assistant message (id/provider only), `stats`
computed from the JSONL, every live-only field empty.

`Stats`:
```json
{"userMessages","assistantMessages","toolCalls",
 "tokens":{"input","output","cacheRead","cacheWrite","total"},
 "cost": 0.0,
 "context": {"tokens": 60000 | null, "window": 200000 | null, "percent": 30 | null},
 "files": {"read": ["…"], "modified": ["…"]},
 "first": RFC3339, "last": RFC3339}
```
Live: tokens/cost/context from pi `get_session_stats`; files from the
timeline. Disk: summed from assistant `usage` and `usage` entries; context
tokens estimated as the last assistant message's `input+cacheRead+cacheWrite+output`,
window null.

Control endpoints (all `POST`, all return `200 {}` unless stated, `404` if
the session is unknown, `409` if it must be live and is not):

| Endpoint | Body | Behaviour |
|---|---|---|
| `/sessions/{id}/prompt` | `{"text","images":["/abs/path.png"]?,"mode":"auto"\|"steer"\|"followUp"?,"model":"provider/id"?,"thinking"?}` | Resumes the session if needed. Applies `model`/`thinking` first when they differ. `auto` = prompt when idle, follow-up when busy. Images are read by phi (≤ 8 MiB each, png/jpeg/webp/gif), base64'd, sent as pi `images`. `202 {}` |
| `/sessions/{id}/abort` | `{}` | `clear_queue` then `abort`; returns `{"steering":[…],"followUp":[…]}` — the cleared text, for the composer |
| `/sessions/{id}/queue/clear` | `{}` | returns the cleared queue like abort |
| `/sessions/{id}/model` | `{"model":"provider/id"}` | live only (409 otherwise); returns `Model` |
| `/sessions/{id}/thinking` | `{"level"}` | live only |
| `/sessions/{id}/compact` | `{"instructions"?}` | live only; returns `{"tokensBefore","tokensAfter"}` |
| `/sessions/{id}/dialog/{dialogId}` | `{"value"?:string,"confirmed"?:bool,"cancelled"?:bool}` | answers a pending dialog |
| `/sessions/{id}/title`, `/pin` | unchanged | |

`GET /sessions/{id}/commands` → `[{"name","description","source"}]` (live
only; `[]` otherwise). `GET /sessions/{id}/export` → `text/markdown` body.
`DELETE /sessions/{id}` closes the live process; `DELETE /sessions/{id}?purge=1`
also deletes the transcript and sidecar.

`GET /models?profile=general` → `{"models":[Model…],"default":"provider/id"|""}`.
Answered from a per-profile cache filled by the first live session of that
profile, or by a short-lived contained `pi --mode rpc --no-session` that is
asked `get_available_models` and closed. `Model`:
`{"provider","id","name","contextWindow","maxTokens","reasoning","input":["text","image"],"cost":{"input","output","cacheRead","cacheWrite"}}`.

### 5.3 Dialogs

pi's dialog extension-UI requests (`select`, `confirm`, `input`, `editor`)
are no longer auto-cancelled. phi keeps them per session as `Dialog`:
```json
{"id","method":"select|confirm|input|editor","title","message","options":["…"],
 "placeholder","prefill","deadline": RFC3339}
```
The deadline is the request's own `timeout` or the prefs `dialogTimeoutSeconds`
(default 600). At the deadline phi answers `cancelled` and emits
`dialog.close {reason:"timeout"}`. Closing a session cancels its dialogs.

### 5.4 SSE — `GET /events`

`data: {json}` lines; every event has `type` and (except global ones)
`session`. Text and thinking deltas are **coalesced** per session and block
(flushed every 60 ms or at a block boundary); tool partial results are
**throttled** to one per 250 ms per call and carry only the last 2000 chars.
The per-client buffer is 1024 events; a client that falls behind is dropped
and must reconnect and refetch.

| type | fields | from pi |
|---|---|---|
| `session.created` | profile, project | — |
| `session.busy` | — | `agent_start` |
| `session.idle` | — | `agent_settled` |
| `session.exited` | code | process exit |
| `session.error` | error | failed command, assistant `stopReason:"error"` |
| `session.title` | title | title endpoint, `session_info_changed` |
| `session.activity` | activity | derived, on change |
| `session.stats` | stats (Stats) | after each `turn_end`, via `get_session_stats` |
| `turn.start` | — | `turn_start` |
| `turn.end` | — | `turn_end` |
| `block.start` | index, block (`text`\|`thinking`\|`tool`), callId?, name? | `text_start`, `thinking_start`, `toolcall_start` |
| `message.delta` | index, text | `text_delta` (coalesced) |
| `thinking.delta` | index, text | `thinking_delta` (coalesced) |
| `block.end` | index, block, text? (final), tool? (ToolBlock without result) | `text_end`, `thinking_end`, `toolcall_end` |
| `message.done` | usage (Usage), stopReason, error?, model, provider | assistant `message_end` |
| `tool.start` | callId, name, args, summary | `tool_execution_start` |
| `tool.update` | callId, name, partial: {text, details?} | `tool_execution_update` (throttled) |
| `tool.end` | callId, name, isError, result: {text, truncated, details?} | `tool_execution_end` |
| `queue` | steering[], followUp[] | `queue_update` |
| `compaction.start` | reason | `compaction_start` |
| `compaction.end` | reason, tokensBefore, tokensAfter, aborted, error | `compaction_end` |
| `retry.start` | attempt, maxAttempts, delayMs, error | `auto_retry_start` |
| `retry.end` | success, attempt, error | `auto_retry_end` |
| `thinking.level` | level | `thinking_level_changed` |
| `ext.status` | key, text | `setStatus` |
| `ext.widget` | key, lines | `setWidget` |
| `ext.notify` | level, message | `notify` |
| `dialog.open` | dialog (Dialog) | dialog `extension_ui_request` |
| `dialog.close` | id, reason (`answered`\|`timeout`\|`cancelled`) | — |
| `coding.changed` | id, state | coding transcript or record changed (2 s poll) |
| `schedule.changed` | — | job list or run state changed (global) |
| `schedule.fired` | job, session | a job started (global) |

The level-1 events (`session.*`, `message.delta` with `text`, `message.done`)
keep their fields, so a level-1 client keeps working.

Activity strings (`activity`, derived in phi): `"thinking"`, `"writing"`,
`"<tool>: <summary>"` while a tool runs, `"compacting"`, `"retrying
2/3"`, `"waiting for you"` while a dialog is pending, `""` when idle.

### 5.5 Coding sessions

`GET /coding` → `[CodingRow]`, newest first:
```json
{"id","dir","project","status":"active|ended","state":"working|waiting|idle|ended",
 "started","ended","windowAddr","activity","title",
 "plan": {"done":2,"total":5} | null, "stats": Stats}
```
`GET /coding/{id}/timeline` → `Timeline` from the JSONL.
Watcher: while at least one `/events` client is connected, phi stats every
active coding session's JSONL every 2 s and emits `coding.changed` when its
size, mtime or state changed.

### 5.6 Usage

`GET /usage?days=30` →
```json
{"days":[{"date":"2026-09-28","tokens":Tokens,"cost":0.41,"turns":12}],
 "byProfile":{"general":{"tokens":Tokens,"cost":…,"turns":…}},
 "byModel":{"provider/id":{…}}, "byProject":{"":{…},"name":{…}},
 "today":Usage, "week":Usage, "month":Usage}
```
`Usage` = `{"tokens":Tokens,"cost":0.0,"turns":0}`; `Tokens` =
`{"input","output","cacheRead","cacheWrite","total"}`. Summed from every
transcript under the data root (chats, projects, coding): assistant message
`usage` bucketed by the message timestamp in local time, plus `usage` and
`compaction`/`branch_summary` entry usage. Parsed files are cached by path,
size and mtime. Same data from `phi agent usage [--days N] --json`.

### 5.7 Schedule

Stored at `$XDG_DATA_HOME/phi-agent/schedule.json`. `Job`:
```json
{"id","title","prompt","profile","project","model"?,"thinking"?,
 "when": {"kind":"once","at":RFC3339}
       | {"kind":"daily","time":"HH:MM","weekdays":[1,2,3,4,5]}   // 1=Mon…7=Sun, empty = every day
       | {"kind":"interval","minutes":60},
 "target": "new" | "session:<id>",
 "maxCost": 0.50,           // per run; 0 = no cap
 "enabled": true,
 "next": RFC3339 | null,    // computed
 "last": {"at","status":"ok|error|capped|skipped","session","cost","error"} | null}
```
`GET /schedule` → `{"enabled":bool,"dailyCap":float,"spentToday":float,"jobs":[Job]}`;
`POST /schedule` (Job without id/next/last) → Job; `PUT /schedule/{id}` →
Job; `DELETE /schedule/{id}`; `POST /schedule/{id}/run` → `{"session"}`
(runs now, even when disabled). CLI: `phi agent schedule list|add|set|rm|run
--json` with the same shapes.

Runner: a 30 s tick while serve runs. A due job runs only when the scheduler
is enabled (prefs) and `spentToday + maxCost ≤ dailyCap` (cap 0 = none).
A run creates (or resumes) the session, sends the prompt, and watches
`session.stats`; when the run's cost exceeds `maxCost` it aborts and records
`capped`. A job whose time passed while serve was down runs once at start
if it is less than 1 h late, otherwise records `skipped` and moves on.

### 5.8 Logs

phi keeps the last 2000 log entries in memory: `LogEntry =
{"seq","time","level":"debug|info|warn|error","session","source":"serve|pi|broker|schedule","text"}`.
pi stderr lines are `info` (lines containing "error" are `warn`); session
errors, failed commands and scheduler failures are `error`. `GET
/logs?since=<seq>&level=<min>&session=<id>&limit=200` → `{"entries":[…],"next":seq}`.
`GET /broker/requests?instance=a1&limit=50` → the last broker meter records
(time, instance, method, path, status, model, dur_ms, resp_bytes).

---

## 6. Timeline

### 6.1 Normaliser

`BuildTimeline(entries, leafID)`: select the active branch by walking
`parentId` from the leaf (the last entry in file order when reading a JSONL;
pi's `leafId` for `get_entries`), in root-to-leaf order. If a `compaction`
entry is on the branch, render everything before it as history as usual —
the timeline shows the full branch, with a `compaction` item where it
happened. Tool results are merged into the owning assistant's tool block by
`toolCallId`.

### 6.2 Items

```json
{"kind":"user","id","time":ms,"text","images":0}
{"kind":"assistant","id","time":ms,"provider","model","stopReason","error"?,
 "usage":{"input","output","cacheRead","cacheWrite","total","cost"},
 "blocks":[Block]}
{"kind":"compaction","id","time","tokensBefore","summary"}
{"kind":"branch","id","time","summary"}
{"kind":"notice","id","time","text"}          // model_change, thinking_level_change
{"kind":"bash","id","time","command","output","exitCode"}
{"kind":"custom","id","time","customType","text"}   // custom_message with display:true
```
`Block`:
```json
{"type":"thinking","text","redacted":false}
{"type":"text","text"}
{"type":"tool","callId","name","args":{…},"summary",
 "result": {"text","isError","truncated","details"?} | null, "endTime": ms | null}
```
Tool result text is capped at 20 000 chars (`truncated:true`). `details` is
passed through only for `plan`, `subagent` and `ask_user`, capped at 64 KiB
(dropped when larger). `summary` rules: `read|write|edit|ls` → `path`;
`bash` → first line of `command` (≤ 80 chars); `grep` → `pattern` and
`path`; `find` → `pattern`; `plan` → "done/total steps"; `subagent` → first
line of `task`; `ask_user` → `question`; otherwise the first string argument.

`Timeline` = `{"items":[Item],"leafId","pending": {"blocks":[Block], "startedAt"} | null}`.

### 6.3 Pending turn (live only)

phi accumulates, per live session, the blocks of the assistant message being
streamed (text/thinking deltas, tool calls from `toolcall_end`, tool results
from `tool_execution_*`). It resets at `message_end` for completed messages
and at `agent_settled`.

---

## 7. First-party pi extension — `phi-workflow`

`phios-dotfiles/profiles/desktop/home/.config/phi-agent/pi/extensions/phi-workflow.ts`,
reached by the general, academic and coding profiles through a symlink in
each profile's `extensions/`. First-party, so D-PI-06 is satisfied by it
living in the repository. Optional: the panel renders these tools specially
when they appear and like any other tool otherwise.

| Tool | Arguments | Behaviour | Result `details` |
|---|---|---|---|
| `plan` | `{"steps":[{"title","status":"pending\|in_progress\|done\|skipped"}],"note"?}` | Replace the session's plan. TUI: a widget above the editor. | `{"steps","note"}` |
| `subagent` | `{"task","tools"?:[names],"label"?}` | Run a child `pi --mode json -p --no-session --no-extensions` with the parent's model, tools ⊆ the parent's read-only tools unless the parent profile has `bash` (then the parent's set), 10-minute timeout. Streams progress as partial results. Returns the child's final text. | `{"status":"running\|done\|error\|timeout","label","events":[{"kind":"tool\|text\|thinking","name"?,"summary"}],"text","usage":{"input","output","cost"},"model","turns","elapsedMs"}` (events: the last 50) |
| `ask_user` | `{"question","options"?:[…],"allowOther"?:bool}` | `ctx.ui.select` (options) or `ctx.ui.input`; returns the answer or "(no answer)". | `{"question","answer","cancelled"}` |

---

## 8. phi prefs and CLI additions

Prefs at `$XDG_STATE_HOME/phi-agent/prefs.json` (UI-written, regenerable),
read on every spawn:
```json
{"defaultProfile":"general",
 "models":{"general":"provider/id","academic":""},
 "thinking":{"general":"medium","academic":""},
 "idleMinutes":15, "dialogTimeoutSeconds":600,
 "scheduler":{"enabled":false,"dailyCap":1.0}}
```
Empty strings mean "pi's default". Applied as `--model` / `--thinking` at
spawn (RPC and TUI chat profiles).

New CLI verbs (all with `--json`):

- `phi agent prefs get | set KEY VALUE` (dotted keys: `models.general`,
  `scheduler.enabled`, …).
- `phi agent usage [--days N]`.
- `phi agent schedule list | add --json-body JSON | set ID --json-body JSON | rm ID | run ID`.
- `phi agent project attachment list NAME | add NAME PATH | remove NAME FILE`.
- `phi agent memory read --level system|profile|project [--profile P] [--project N]`
  → `{"text","path"}`.
- `phi agent status` → units, keys present, models.json providers per
  profile, whitelist entry count, broker config summary (no secrets) — what
  Settings used to read with `sh`.
- `phi agent session prune [--older-than DAYS]` — deletes ended terminal
  session records (never transcripts).

---

## 9. Shell contract

### 9.1 `Services/Agent.qml` (singleton) — public surface

State:
`available`, `healthChecked`, `apiLevel` (int), `outdated` (bool: api < 2),
`version`, `profiles`, `projects`, `sessions` (SessionRow[]), `sessionsLoading`,
`selectedProject`, `defaultChatProfile`, `currentSessionId`,
`rows` (ListModel, §9.2), `timelineLoading`, `currentState` (state object, §5.2,
`{}` when none), `pendingModel` / `pendingThinking` (choices for the next
prompt of a non-live or new chat), `models` (Model[] for the current
profile), `commands`, `processing` (current session busy), `anyBusy`,
`busyCount`, `needsInputCount`, `failedCount`, `activityById` (id → string),
`overview`, `usage`, `schedule`, `codingSessions` (CodingRow[]),
`codingRows` (ListModel for the open coding timeline), `openCodingId`,
`logs` (LogEntry[] tail), `brokerRequests`, `searchResults`, `searching`,
`proposalsByLevel`, `totalPendingProposals`, `materials`, `projectMeta`,
`lastError`, `drafts` (id → text), `queue` (current session queue).

Functions (all async, never dropped — every request goes through one
queue-free helper):
`refreshHealth()`, `refreshProjects()`, `refreshSessions()`,
`openSession(id)`, `newChat()` (clears current; next send creates),
`send(text, images, mode)`, `stop()` (returns cleared queue into `drafts`),
`clearQueue()`, `setModel(ref)`, `setThinking(level)`, `compact()`,
`answerDialog(sessionId, dialogId, answer)`, `setChatPinned(id, on)`,
`setChatTitle(id, t)`, `closeSession(id)`, `deleteSession(id)`,
`exportSession(id)` (copies Markdown), `refreshModels(profile)`,
`refreshCommands()`, `refreshOverview()`, `refreshUsage(days)`,
`refreshSchedule()`, `saveJob(job)`, `deleteJob(id)`, `runJob(id)`,
`refreshCoding()`, `openCoding(id)`, `closeCoding()`, `focusCodingWindow(addr)`,
`newCodingSession(dir, project)`, `refreshLogs()`, `refreshBrokerRequests()`,
project/memory/attachment/search functions as today (names kept),
`setActivated(on)`.

Signals: `sendFailed(text)`, `queueRestored(text)`, `notify(kind, title, body, sessionId)`.

### 9.2 Row model

`rows` and `codingRows` are `ListModel`s with a fixed role set, one row per
renderable unit; live events update rows in place (`setProperty`) so the
`ListView` never rebuilds while streaming:

| role | type | meaning |
|---|---|---|
| `key` | string | stable id: `u:<entry>`, `b:<entry>:<i>`, `t:<callId>`, `e:<entry>`, `live:<n>` |
| `kind` | string | `user`, `thinking`, `text`, `tool`, `turnEnd`, `error`, `compaction`, `notice`, `dialog`, `bash`, `custom` |
| `text` | string | body text (user, text, thinking, error, notice, compaction summary) |
| `name` | string | tool name, dialog method |
| `summary` | string | tool summary, compaction headline |
| `args` | string | tool arguments, JSON |
| `result` | string | tool output text |
| `details` | string | tool details, JSON (plan/subagent/ask_user), dialog JSON |
| `status` | string | `streaming`, `running`, `done`, `error` |
| `isError` | bool | tool error |
| `time` | real | ms since epoch (start) |
| `endTime` | real | ms, 0 when unknown |
| `meta` | string | JSON: turnEnd `{model,provider,usage,durationMs,stopReason}`, user `{images}` |

Reconciliation on `session.idle`: refetch the timeline, flatten, and update
the model by key (update changed rows, append missing, remove extra) — never
`clear()` while the chat is on screen.

### 9.3 `Config/AgentPrefs.qml`

Flat JSON at `Paths.agentPrefsFile` (`<stateDir>/agent.json`):
`dockWidth` (`compact|regular|wide`), `sidebar` (bool), `inspector` (bool),
`busyEnter` (`followUp|steer`), `thinkingDisplay` (`expanded|folded|hidden`),
`toolDetail` (`compact|expanded`), `notifyFinish` (`off|long|always`),
`notifyAsk` (bool), `openLastChat` (bool), `costWarn` (real, 0 = off).

### 9.4 Components (`Components/AgentPanel/`)

```
AgentPanel.qml                 dock, header, tabs, status pill, keys, IPC
modules/Timeline.qml           ListView over a rows model; props: model, readOnly, live
modules/rows/UserRow.qml  TextRow.qml  ThinkingRow.qml  ToolRow.qml
modules/rows/PlanCard.qml  SubagentCard.qml  DialogRow.qml  TurnEndRow.qml
modules/rows/MarkerRow.qml     compaction, notice, error, bash, custom
modules/ChatSection.qml        sidebar + conversation + inspector layout
modules/ChatSidebar.qml  ChatHeader.qml  Composer.qml  Inspector.qml
modules/CodeSection.qml        running/ended cards, launcher, timeline viewer
modules/ProjectsSection.qml    list + detail (ProjectDetail.qml)
modules/OverviewSection.qml    health, running, needs-you, usage, schedule, errors
modules/ScheduleEditor.qml     job form
modules/ProposalReview.qml     literal diff review, shared by Overview and Projects
```

---

## 10. Phases

| Phase | Repository | Content | Verification |
|---|---|---|---|
| P1 | phi | timeline normaliser, rich SSE, state/stats, controls, dialogs, models, logs, api 2 | `go test ./...`, `go vet ./...` |
| P2 | phi | usage, coding monitor, prefs, schedule, CLI verbs | same |
| P3 | phi-shell | Services/Agent.qml, AgentPrefs, Timeline + rows, Chat | user screenshots |
| P4 | phi-shell | Code, Projects, Overview, bar, notifications | user screenshots |
| P5 | phi-shell | Settings › AI Agent, AgentInfra retired into phi calls | user screenshots |
| P6 | phios-dotfiles | phi-workflow extension, profile symlinks | user runs a plan/subagent turn |
| R | all | tag phi v0.25.0, bump phi-packages, push, superproject pointer | — |
