---
description: "How to use rozum's state.get / state.update / state.reset MCP tools: a durable per-project JSON fact store, independent of the conversation, that survives /clear and a fresh session. Use when starting a task, right after a compaction or a fresh session (to recover where a task stood), whenever a fact or decision must survive to the next turn, or when an AGENTS.md references this file."
argument-hint: "get | update | reset | when-to-use"
---

# task-state — a fact store that outlives the conversation

This skill is agent-independent: plain markdown about a discipline, usable by any
agent that reads it — load it from `AGENTS.md` or invoke it directly. It documents
`state.get` / `state.update` / `state.reset`, three MCP tools rozum serves on the
same connection as `rag.search` and `meeting.*`.

**The point in one sentence:** a conversation keeps growing and gets compacted or
cleared, but a task's STATE — a handful of structured facts, not the transcript
that produced them — does not have to live there at all. Put the fact in
`state.update` the moment you learn it; read it back with `state.get` the moment
you might have lost the conversation that produced it.

## 1. The three tools

| Tool | Does | Notes |
|---|---|---|
| `state.get` | Read the current state — one JSON object | `{}` if nothing has been set yet |
| `state.update(patch)` | Merge an RFC 7396 JSON Merge Patch into the state, persist it, return the merged result | see §2 for the merge rules |
| `state.reset` | Clear the state back to `{}` | only for a genuinely new task — see §3 |

Scoped **per project** (`<project>/.rozum/state.json`, keyed off the same project
detection `rag.search` uses), not per conversation and not per agent — every
session working in this project reads and writes the same object. There is no
schema: the tool is generic across whatever project runs it, so the state's shape
is a convention between whoever writes it and whoever reads it back, the same
trust boundary a hand-edited JSON file already has. Keep it small and flat; this
is a handful of facts, not a database.

## 2. `state.update`'s merge rules (RFC 7396)

- An **object** field merges recursively into the existing one.
- A field set to **`null`** deletes that key.
- **Anything else** (a string, number, array, bool) replaces the field wholesale —
  an array patch is not appended to, it replaces the old array outright.
- Omit fields that did not change; `state.update` only touches what you send.
- A patch that isn't a JSON object is refused outright — the state is never
  silently replaced by a scalar or an array.

**One caveat worth knowing, not working around:** composing two patches yourself
before sending them is not always the same as applying them in order.
`merge_patch(merge_patch(t, p1), p2)` can differ from
`merge_patch(t, merge_patch(p1, p2))` when `p2` deletes a key that `t` had but
`p1` never mentioned — the combined patch never learned the key existed, so it
has nothing to delete. Call `state.update` once per fact as you learn it; don't
batch patches together by hand.

## 3. When to call each

- **`state.get`** — at the start of any task that spans more than one turn, and
  **always** right after a `/clear` or a fresh session picking up existing work.
  The conversation that built the state may be gone or summarized; the state
  itself is not. Treat a non-empty result as "read this before assuming you're
  starting cold."
- **`state.update`** — the moment a fact is learned or a decision is made that
  the NEXT turn (or a future session) needs and the conversation might not
  survive to carry: a chosen approach, a file already checked, a step already
  done, a number already measured. Not a running log — overwrite the field for
  "current step", don't append an ever-growing array of every step ever taken;
  that turns this into a second transcript instead of a fact store.
- **`state.reset`** — only when starting a **genuinely new** task in this
  project, never between steps of the same one. Resetting mid-task throws away
  exactly the recovery information §1 exists to provide.

## 4. What this is not

- **Not the memory system.** An agent's own cross-conversation memory (if it has
  one) is curated, long-lived, and about the user/project in general — this is
  per-project, per-task, and as disposable as the task itself. Don't put durable
  facts about the user here; don't put this session's task state in memory.
- **Not the planning boards.** `scrumban`'s `SPRINT.md`/`BACKLOG.md` are for
  durable, human-and-agent-visible planning that outlives any one task and is
  meant to be read by a person. `state.json` is a private working scratchpad for
  continuity of ONE task, not meant to be read by a human at all — if a fact
  belongs on a board (so a sibling agent or the operator can see it), put it on
  the board, not here, even if you also cache a copy here for your own recovery.
- **Not a log.** Nothing currently records that a `state.*` call happened (unlike
  `rag.search`, which logs every call at `info` by default — see the `rag`
  skill's own §4). If you need to confirm a call fired, check the transcript;
  there is no server-side line to tail yet.

## 5. Connecting it

Comes for free wherever `rag.search` does — the meeting-room MCP proxy
(`rozum launch`, or `rozum mcp install` done once globally) serves `state.*`
next to `rag.search` and `meeting.*` on the same connection, no extra config.
**Unlike `rag.search`, there is no standalone-server option**: the retrieval-only
`{ "command": "rozum", "args": ["rag", "mcp"] } ` server serves `rag.search` and
nothing else by design (a test pins exactly that contract) — `state.*` needs the
meeting-daemon proxy.
