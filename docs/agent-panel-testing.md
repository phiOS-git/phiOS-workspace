# Agent panel rework — install and test guide

Companion to `docs/agent-panel-plan.md` (the design and the API contract).
Run the parts in order: **A** once on `zotac` (build), **B** on every desktop
host (`zotac`, `razer`), then **C–H** on whichever host you test on (`razer`
is the primary one). Each step has a **Check**; stop at the first check that
fails and send the output.

What was verified before this reached you: `go vet`, `go test ./...` (with
the race detector on the agent server) and a Linux build of phi; for the QML,
only mechanical checks (every service member referenced exists, no colour or
size literals, balanced braces). **No QML was executed** — part C's first step
is the first real load.

---

## A. Build and publish phi 0.25.0 (zotac)

1. Sync the workspace.
   ```sh
   cd ~/phiOS-workspace && scripts/sync.sh      # your workspace checkout
   ```
   **Check:** every repository says `up to date` or fast-forwarded; `git -C phi-packages log --oneline -1` shows `phi: 0.25.0`.

2. Build in the clean chroot.
   ```sh
   cd ~/phiOS-workspace/phi-packages && scripts/build phi   # same checkout
   ```
   **Check:** `ls phi/*.pkg.tar.zst` lists `phi-0.25.0-1-x86_64.pkg.tar.zst`; the build log ends with `go vet` passing.

3. Sign and add to your local repo directory, then move it to `mini` the way you always do.
   ```sh
   GPGKEY=<your key id> scripts/publish <repo-dir> phi/phi-0.25.0-1-x86_64.pkg.tar.zst
   ```
   **Check:** `pacman -Sl phi | grep ' phi '` (after `sudo pacman -Sy`) shows `0.25.0-1`.

## B. Install on each desktop host (zotac, razer)

1. Upgrade.
   ```sh
   sudo pacman -Syu
   ```
   **Check:** `pacman -Q phi` → `phi 0.25.0-1`.

2. The new verbs work without the engine.
   ```sh
   phi agent status --json | head -40 && phi agent prefs get --json
   ```
   **Check:** JSON with five `units`, a `profiles` block (general, academic, coding, inline) and `brokers` a1/a2 with `keyPresent`; no key value anywhere. Prefs show `"idleMinutes": 15` and `"scheduler": {"enabled": false, …}`.

3. Pull the dotfiles and install (brings the pi extension and its three profile symlinks).
   ```sh
   git -C "${PHI_DOTFILES:-$HOME/phios-dotfiles}" pull --ff-only
   "${PHI_DOTFILES:-$HOME/phios-dotfiles}"/bin/phios-install
   ```
   **Check:**
   ```sh
   for p in general academic coding; do readlink -f ~/.config/phi-agent/pi/profiles/$p/extensions/phi-workflow.ts; done
   ls ~/.config/phi-agent/pi/profiles/inline/extensions 2>&1
   ```
   Three lines ending in `pi/extensions/phi-workflow.ts` inside the dotfiles checkout; the last command says "No such file or directory".

4. Restart the engine on the new phi.
   ```sh
   systemctl --user restart phi-agent.service && sleep 2 && curl -s 127.0.0.1:4199/health
   ```
   **Check:** `{"api":2,"ok":true,"startedAt":"…","version":"0.25.0"}`.
   If it fails: `journalctl --user -u phi-agent.service -n 50`.

5. Update the shell.
   ```sh
   git -C ~/.config/quickshell/phi pull --ff-only
   ```
   **Check:** `git -C ~/.config/quickshell/phi log --oneline -2` shows `agent: describe the panel the toggle owner opens` on top.

## C. First load — the only QML check there is

1. Restart the shell in a terminal and keep the output.
   ```sh
   pkill -x qs; qs -p ~/.config/quickshell/phi 2>&1 | tee /tmp/qs.log | grep -iE 'error|warn|unable|undefined|is not a'
   ```
   **Check:** nothing mentions `Agent`, `AgentInfra`, `AgentPanel`, `AgentPrefs`, `Timeline`, `Chat…`, `Composer`, `Inspector`, `Code`/`Projects`/`Overview` sections, `rows/`, `AiAgent` or `PhiAgent`. **Paste the whole grep output back either way** — a load error in `Services/Agent.qml` also takes the bar Φ and Settings down, so that is the first thing to look for.

2. Bar Φ.
   **Check:** the Φ segment is there; hovering it for a second shows e.g. `$0 today` (with the engine up) or `Agent offline`.

3. Super+P.
   **Check:** a dock slides in from the left with tabs **Chat · Code · Projects · Overview**, a pill `● $0.00 today` (or similar) and two icons (⇔, settings) on the right. The composer has focus: typing goes straight into it.

## D. Chat

1. **Send and stream.** Type `Explain in three steps how a Linux pipe works, think first.` and press Enter.
   **Check:** your bubble on the right; a faint `Thinking…` fold with a few streaming lines (if the model thinks), then text streaming in plain and becoming formatted markdown when it ends; a faint footer like `model · 1.2k in · 300 out · $0.00 · 6 s`. The pill briefly shows `1 running`, the Φ breathes, and both stop at the end. The sidebar gets the chat under **Today** with a breathing `●` while it ran.

2. **Tool calls.** Ask: `List the files in your home directory and read the first one.`
   **Check:** one line per tool (`⟳ ls …`, turning `✓`, with a duration). Click a line: **Arguments** (JSON) and **Output** open under it; click again closes. The header meta line shows the model; the context meter (thin bar under the header) fills a little.

3. **Queue, steer, stop.** Ask something long (`Write a 1500-word essay about pipes.`). While it streams:
   - type `Also add a conclusion.` + Enter → **Check:** a chip `then: Also add a conclusion.` above the field; it disappears when the agent picks it up and your message appears in the timeline after the first answer.
   - send another long prompt, then type `Stop and summarise in one line.` + **Alt+Enter** → **Check:** chip `steer: …`; the agent changes course after its current step.
   - send another long prompt, queue one follow-up, then press **Ctrl+.** (or **Stop**) → **Check:** the turn stops within a second or two and the queued text is back in the composer.

4. **Recall and drafts.** In an empty composer press ↑. **Check:** your last message is back in the field. Type something without sending, open another chat from the sidebar, come back. **Check:** the draft is still there.

5. **Slash commands.** Type `/`. **Check:** a list of pi commands/skills/templates above the field (it may be empty if none are configured — then nothing appears); ↑/↓ moves, Tab or Enter picks.

6. **Image.** Take a screenshot to the clipboard (your usual keybind), focus the composer, press **Ctrl+V**. **Check:** a chip `image: <number>.png`. Send `What is in this image?` **Check:** the user bubble shows `1 image` and the answer describes it (needs a model with image input). Also try **Image…** → paste an absolute path → Enter.

7. **Model and thinking.** Click the model chip under the field. **Check:** a list opens upwards with your models; picking one updates the header line. Same for `think: …` (levels depend on the model).

8. **Inspector.** Press **Ctrl+I** (with the composer focused). **Check:** a right-hand drawer (or column in wide mode) with Context, Usage, Model and, when present, Plan, Subagents, Queue, Files touched. Click outside or press Esc to close the drawer.

9. **Chat management.** Hover a chat in the sidebar → `☆` pins it (moves under **Pinned**), `⋯` → Rename / Copy as Markdown / Close / Delete…. Click the chat title in the header to rename it inline. **Check:** each action takes effect; Copy as Markdown puts the transcript on the clipboard (a notification says so); Delete asks first.

10. **Search.** **Ctrl+F**, type a word from an earlier chat. **Check:** grouped results; clicking one opens it.

11. **Scope.** In the sidebar scope list pick a project. **Check:** only that project's chats; the header shows `project ›`; a New chat created now belongs to that project.

## E. Agent workflows (the phi-workflow extension)

1. **Plan.** `Plan and then carry out: list your tools, then count the files in your home, then summarise. Use the plan tool.`
   **Check:** a **Plan · 0/3** card with a progress bar that ticks to 3/3 as steps complete; the inspector's Plan group mirrors it.

2. **Subagent.** `Use a subagent to find the three largest files in your home folder, then tell me what they are.`
   **Check:** a **Subagent** card showing `running`, the child's tool steps appearing live, tokens/cost/elapsed, then `done` and its answer; the inspector lists it under Subagents (click jumps to it).
   **Not verifiable here:** whether a nested `pi` can start inside the containment next to its parent. If the card ends in `error`, paste its text and `journalctl --user -u phi-agent.service -n 80`.

3. **Question.** `Ask me which of three colours I prefer using ask_user, then comment on my answer.`
   **Check:** a card **The agent is asking** with three buttons and a countdown; pick one → the card disappears and the agent continues. The bar Φ gets an accent dot and the pill says `1 asking` while it waits.

4. **Question while the panel is closed.** Same prompt, then close the panel (Esc) before the question appears.
   **Check:** a notification "The agent is asking"; reopen with Super+P and answer.

5. **Dialog timeout.** `phi agent prefs set dialogTimeoutSeconds 20`, `systemctl --user restart phi-agent.service`, repeat step 3 and do not answer.
   **Check:** after ~20 s the card disappears and the agent continues with "(no answer)". Set it back: `phi agent prefs set dialogTimeoutSeconds 600`.

## F. Code, Projects, Overview

1. **Coding monitor.** Code tab (**Ctrl+2**) → **New coding session** → choose a project folder or type a path → **Open terminal**. Give pi a task in the terminal.
   **Check:** a Running card with the directory, `working ●` while it acts, the current tool as activity line, tokens and cost; `waiting for you` when it stops. **Focus window** jumps to the terminal; **Timeline** replays the session live (read-only). The Code tab shows a badge while it works.

2. **Projects.** **Ctrl+3** → **New project** (name, description, profile) → open it.
   **Check:** Overview, Instructions, Folders, Attachments, Memory, Chats, Coding sessions all present; add an instruction, a folder (ro), an attachment path — each appears; **New chat here** switches to Chat scoped to the project.

3. **Overview.** **Ctrl+4.**
   **Check:** health dots for engine/brokers/proxy, `phi 0.25.0 · API 2`; Running now lists active chats and coding sessions; Usage tiles for today/7/30 days and a 30-day dot graph; Recent errors (probably empty).

4. **Scheduler.** Settings › AI Agent › **Scheduler**: enable it, daily cap `0.20`. Back in Overview → **New scheduled prompt**: title `test`, prompt `Say hello and the time.`, Every 5 minutes (or Once, two minutes from now), max cost `0.05`, Save.
   **Check:** the job shows its next run; at that time a new chat appears (badge `◷` in the sidebar), a notification says the agent finished (if the turn was long enough for your notify setting), and the job's last run reads `ok` with a cost. **Run now** starts it immediately. Disable the scheduler again afterwards.

## G. Settings › AI Agent

1. Open it (settings icon in the panel header). **Check:** groups Engine, Defaults, Panel behaviour, Providers and models, Usage, Scheduler, Coding, Memory, Logs (Services and Maintenance appear with Advanced on).
2. **Defaults:** set a default model for general. Start a new chat. **Check:** the header shows that model.
3. **Panel behaviour:** set Enter while busy to *Steer*, Thinking to *Expanded*. **Check:** the composer placeholder while busy says "Steer the running turn…"; thinking folds render open.
4. **Logs:** turn on Follow. **Check:** engine lines appear as you chat (sessions started, tool failures, retries); **Broker requests** lists recent calls with status and duration.
5. **Search:** type `logs` or `scheduler` in the Settings search. **Check:** it jumps to and pulses that group.

## H. Layout, keys, IPC

1. **Ctrl+\\** (or ⇔) cycles compact → regular → wide. **Check:** compact hides the sidebar (Ctrl+B opens it as a drawer), wide shows sidebar + chat + inspector side by side; the choice survives closing the panel.
2. With the composer focused try **Ctrl+N** (new chat), **Ctrl+F**, **Ctrl+B**, **Ctrl+I**, **Ctrl+1…4**, **Alt+↑/↓** (previous/next chat). **Check:** each works without clicking elsewhere first.
3. **Esc** order. **Check:** first Esc leaves the field, the next closes an open drawer / goes back from a project or a coding timeline, the last closes the panel.
4. IPC:
   ```sh
   qs ipc call agent overview; sleep 1; qs ipc call agent code; sleep 1; qs ipc call agent close
   ```
   **Check:** the panel opens on Overview, switches to Code, closes.

---

When something fails, send: the step number, a screenshot, the relevant lines of `/tmp/qs.log`, and `journalctl --user -u phi-agent.service -n 80`.
