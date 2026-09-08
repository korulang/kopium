---
name: prose
description: ALWAYS CHECK FIRST when you need to orient on recent work or find a specific thing said in a past session. `prose` is a near-stateless CLI that reads agent session journals (Claude Code CLI, ACP, Codex, opencode, Cursor, Devin, pi, OMP). Five read verbs (`snap`, `whisper`, `grep`, `session`, `stats`) are pure — no LLM; two compaction verbs (`gossip`, `standup`) layer one cheap LLM pass on top; one stateful verb (`baton`) persists "you are here" markers. Don't say "I don't remember" or guess from filenames before running prose. Use `grep` when the user references a specific phrase, term, file, or quote from a past session. Use `session <id>` to drill into a specific session — the ids printed in snap/whisper headers are direct handles. Use `baton set` to leave a sign-off for the next session and `baton` to read the latest. Also fire when the user mentions prose itself ("look at prose", "show me prose", "does prose work", "try prose") — default to `snap`, never dump `--help` and ask what to do.
---

# prose — Stateless Inspection Over Your Agent Journal

`prose` is the cheap orientation tool over your AI session history. It reads what your agents (Claude Code CLI, brain personas via ACP, Codex, opencode, Cursor, Devin, pi, OMP) have already written to disk. The read verbs are pure read-side — every call is current; no cursors, no caches, no coordination overhead. The one exception is `baton`: a deliberately stateful "you are here" marker you write at a sign-off and read back next session (persisted to the `~/.prose` vault, so it syncs across machines).

**Reach for prose when:**

- The user references "earlier," "yesterday," "what we were doing," or assumes shared context you don't have.
- You're starting a session in a known repo and want to know what happened before.
- The user asks what they were working on (in this project, the family, or the whole week).
- The user references a specific term, phrase, error message, or quote from a past session ("the bit about migrations," "where we discussed X") — that's `grep`, not `snap`/`whisper`, since recency-based verbs only see tails.
- A prior verb (`snap`, `whisper`, `grep`) surfaced a session id and you want the *whole* session — that's `session <id>`. The 8-char prefix printed in the `=== Claude Code session 72a5eed3 ===` header is the handle.
- You're tempted to say "I don't have context on that" — check prose first; the data is on disk.
- You need to feed a recent session into your reasoning without retracing.
- The user references the prose tool itself ("look at prose", "show me prose", "does prose work", "try prose") — run `snap`, don't dump `--help` and ask what to do. Demonstrating the tool *is* the answer.

**Don't use prose when:**

- The data you need is current code state — use `Read` / `Grep`.
- The user wants persistent memory or fragments — that's `prose evolve`/`search`, different surface.
- You're looking at runtime errors of a running app — use `sidetrack`.

## The verb grid

Two axes: **scope** (how wide a net) and **compaction** (verbatim or LLM paragraph).

|                              | verbatim         | LLM compaction |
|------------------------------|------------------|----------------|
| 1 cwd                        | `snap`           | —              |
| neighborhood (project family)| `whisper`        | `gossip`       |
| all cwds, time-windowed      | —                | `standup`      |
| all cwds, regex-targeted     | `grep`           | —              |
| all cwds, quantitative       | `stats`          | —              |
| 1 session by id              | `session`        | —              |

Read verbs (`snap`, `whisper`, `grep`, `session`, `stats`) are pure — no LLM, no API key, instant, free. Compaction verbs (`gossip`, `standup`) layer one streaming LLM pass on top.

## Pick the right verb

**`snap`** — Verbatim, single cwd, no LLM, instant.
- Use when you want the exact words for *this* repo, the raw transcript, or to feed sessions into your own LLM reasoning.
- Cheap: filesystem read, zero token spend.

**`whisper`** — Verbatim, neighborhood-aware, no LLM.
- Use when you want raw recent activity across the *project family* (e.g. running it in `~/src/6digit-studio` includes the entire `6digit-*` family; `~/src/koru` includes `korulang_org` and other token-related siblings).
- Pass `--cwd-only` to scope to a single directory (then it's basically snap with neighborhood-skip).
- Cheap: filesystem reads only, zero token spend. Use this as the verbatim source for your own pipelines.

**`gossip`** — One short LLM paragraph over a `whisper`.
- Use when you want a quick narrative answer to "what's happening across this project family lately."
- Casual register — colleague catching you up over coffee.
- Cheap: one LLM pass, gemini-flash by default, pennies.

**`standup`** — Structured cross-project breakdown of the last 7 days.
- Use when you want to know what's been happening across **all** your work, project-by-project, this week.
- Time-windowed (default 7d), per-session tail of last 10 messages, grouped by repo, headered output.
- Formal register — daily-standup tone, "what changed / what's next."
- Cheap: one LLM pass over a byte-budgeted window.

**`grep`** — Regex search across the parsed session line-stream, no LLM.
- Use when the user references a specific phrase, file, term, error string, or quote from a past session — when recency-based verbs (`snap`/`whisper`) won't surface it because it's outside the recent tail.
- Operates on the **parsed session content**, NOT on files on disk. Multiple positional patterns are OR-alternated; output is grep-style line context (default ±5).
- Default scope is global: all sources, all cwds, all time. Use `--cwd`, `--source`, `--since` to narrow.
- `-F` for literal strings, `-i` for case-insensitive, `-C N` / `-A N` / `-B N` for context windows, `-m N` to cap matches.
- Cheap: filesystem read + in-memory regex, zero token spend.

**`stats`** — Per-day activity metrics across all sessions, no LLM.
- Use when the question is *quantitative*: "how much did I work this week," "how many sessions/projects per day," "what hours am I active." Not for content — no message text in the output.
- Per local-calendar-day: active hours (message timestamps merged with a 15m idle-gap cutoff), "human" hours (user messages only — presence, not agent runtime), user/assistant message counts, distinct sessions and projects, plus an hour-of-day histogram.
- Default scope is global (all cwds), last 30 days. Use `--cwd`, `--source`, `--since`, `--idle-gap` to narrow or tune.
- `--csv` emits day rows for spreadsheets/plotting; `--json` for the full structure.
- Cheap: filesystem read + counting, zero token spend.

**`session <id>`** — Verbatim readout of one specific session, no LLM.
- The drill-down companion to snap/whisper/grep. When those verbs print `=== Claude Code session 72a5eed3 ===`, pass that prefix (or any unique prefix) to `prose session 72a5eed3` to read the whole session.
- Accepts any unambiguous id prefix; errors clearly on no-match (exit 1) or ambiguous-match (exit 2 with the candidate list).
- No cwd filter — the id is the selector. Scans Claude Code, ACP, Codex, opencode, Cursor, Devin, pi, OMP, and Gemini Antigravity (the widest id-space of any verb).
- Knobs: `--turns N` to tail, `--since <iso>` to slice by timestamp, `--max-message-bytes N` (default 0, no clipping — opposite of snap, since named-session means you want the full text).
- Cheap: filesystem read, zero token spend.

## Decision tree (rough)

```
Need raw text for THIS cwd?               → prose snap
Need raw text across the project family?  → prose whisper
Need a paragraph about the family?        → prose gossip
Need "what did I do this week"?           → prose standup
Need to find a specific phrase/term/quote? → prose grep "..."
Need numbers (hours, volumes, cadence)?    → prose stats
Have an id from snap/whisper/grep?         → prose session <id>
```

## Multi-source by default

`snap`, `whisper`, `grep`, and `stats` read the **union** of:
- Claude Code CLI sessions in `~/.claude/projects/`
- Brain-persona ACP sessions (claude-agent-acp writes the same JSONL format to the same path)
- Codex CLI sessions in `~/.codex/sessions/`
- opencode (sst/opencode) sessions in `~/.local/share/opencode/opencode.db` (SQLite)
- Devin CLI sessions in `~/.local/share/devin/cli/sessions.db` (SQLite; includes cross-cwd work when messages reference the target repo)
- Cursor agent transcripts in `~/.cursor/projects/<cwd>/agent-transcripts/` (JSONL; timestamps synthesized from file mtime)
- pi / OMP agent sessions under `~/.pi/` and `~/.omp/`

`session <id>` resolves against that same union **plus** Gemini Antigravity brain artifacts in `~/.gemini/antigravity/brain/` — its id-space is the widest of any verb, so a named id always resolves regardless of source.

A `gossip` in a directory automatically picks up what your terminal CLI, ACP-driven brain personas, Codex, opencode, Devin, Cursor, pi, and OMP have all been doing there. The boundary between surfaces mostly disappears at the inspection layer. Sources you don't use are silently no-ops — no config to disable.

**Live-session exclusion:** when you run prose from inside an agent session, your *own* in-progress conversation is skipped by default (`CLAUDE_CODE_SESSION_ID`, `CURSOR_CONVERSATION_ID`). Use `--include-current` to override.

## Stateless — call it freely

These verbs hold zero state. There's no "last run," no cursor, no cache. Multiple consumers (terminal, satellite tool, REST endpoint, another Claude session) can call them concurrently and always get a current answer. **Don't worry about whether you should "save" a result for later** — just call again next time you need it.

## Batons — the one stateful verb (leave a sign-off, read it back)

The read verbs reconstruct the past; a **baton** records *where you are now* for the next session to pick up. It's the deliberate exception to statelessness — a small, typed, persisted "you are here" marker.

- **Write one at a sign-off:** `prose baton set "↪ HANDOFF: position — what merged · next: <advisory move> · or pivot"`. The `↪ LABEL:` prefix sets the type; or pass `--type <label>` explicitly. Defaults to the current cwd.
- **Read the latest:** bare `prose baton` shows the **latest baton per project per type** — "you are here," not a backlog. `--history` for the full trail, `--type <label>`/`--cwd <path>` to scope, `--json` for structured output.
- **It rides `snap`/`whisper`:** the cwd's latest batons are prepended as a header to orientation output for free (suppress with `snap --no-batons`).
- **Typed and methodology-agnostic.** A baton's `type` is just a free-form label (`handoff`, `decision`, …). Arbiter-Driven Development's `↪ HANDOFF` is simply `type: handoff` — one consumer of a general primitive, with no special status. Persisted to the `~/.prose` vault, so batons sync across machines.

## Machine-readable mode

Every verb supports `--json`. The verbatim verbs return structured snap/whisper objects (text + per-session metadata + per-member blocks); the LLM verbs return the same plus the emitted paragraph as a field instead of streaming. Use this when you're piping prose into another tool — Claude Code, a script, a downstream agent — and want to consume both the raw verbatim source and any compacted text without parsing trail lines.

## Run it yourself

You have a `Bash` tool. Use it. Don't ask the user to run prose and paste the output — just run it.

```bash
prose snap                                # verbatim, current cwd
prose snap --json --sessions 3            # structured, 3 most recent
prose whisper                             # verbatim across the project family
prose whisper --cwd-only                  # verbatim, just this directory
prose whisper --json                      # structured neighborhood snap
prose gossip                              # paragraph over the family
prose gossip --json                       # structured: source whisper + paragraph
prose standup                             # cross-project standup, last 7 days
prose standup --since 1d                  # tighter window
prose standup --json                      # structured project breakdown + text
prose grep "vision board"                 # regex search across all sessions
prose grep -F "tsc --noEmit"              # literal string (no regex)
prose grep -i "needle" --since 7d -C 3    # case-insensitive, last week, 3 lines context
prose grep "foo" "bar" --cwd /path/here   # OR-alternation, scoped to one cwd
prose grep "..." --json                   # structured matches with line numbers
prose session 72a5eed3                    # full readout of one session by id-prefix
prose session 72a5eed3 --turns 20         # tail the last 20 messages of that session
prose session 72a5eed3 --json             # structured: metadata + full text
prose stats                               # per-day activity table, all cwds, last 30d
prose stats --since 7d --cwd /path/here   # one project, last week
prose stats --csv > activity.csv          # day rows for plotting
prose stats --json                        # full structure: days, totals, histogram
```

`prose --help` is the canonical flag reference. Don't memorize defaults — they evolve.

## Common mistakes

- **Asking the user instead of running it.** Prose is on the user's PATH. Run it. This includes meta-questions ("look at our prose tool") — the right move is `snap`, not `--help` followed by "what do you want me to do?"
- **Treating it like persistent memory.** Prose verbs are *stateless reads*. They don't accumulate. For long-term memory, use `prose evolve` / `search` (different surface).
- **Skipping it because "I'll just guess."** If you're guessing, you're fabricating. Spend the 2 seconds.
- **Reaching for `gossip` when you wanted raw text.** Gossip costs LLM tokens for a paragraph. If you're going to feed the result into your own reasoning, use `whisper` and skip the middle compression.
- **Running `whisper --cwd-only` when the project is part of a family.** Default whisper is the right call ~80% of the time. Use `--cwd-only` only when you genuinely want to ignore siblings.
- **Reaching for `whisper`/`snap` when the user named a specific term or quote.** If they reference a phrase ("the bit about the vision board," "where I said `tsc --noEmit` was clean"), that's `grep` — recency-based verbs only see the tail. `grep` searches the whole archive.
- **Treating `prose grep` as a filesystem search.** It's not. It searches the **parsed session content** (Claude Code JSONLs, ACP records, Codex, opencode/Devin SQLite, Cursor JSONL, pi/OMP). Use ripgrep for files on disk; use `prose grep` for words your agents actually said.

## Pairing with other skills

- **`recall`** — searches *Convex-stored* ACP session history (history search across sessions). Prose reads *local filesystem JSONLs*. Use both: prose for orientation in a cwd; recall for keyword-search across your full ACP history.
- **`sidetrack`** — captures *real-time* console/network/error events from running apps. Prose reads *post-hoc* session transcripts. Different time horizons.
- **`standup` (the existing studio skill)** — runs a standup over **studio Convex ACP events** specifically. The prose `standup` verb runs over **filesystem JSONLs** across all projects on the machine. Different mechanisms, different scopes; use whichever matches the question.
