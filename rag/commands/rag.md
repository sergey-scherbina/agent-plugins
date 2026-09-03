---
description: "How to connect to and use rozum's rag.search retrieval tool well: when it earns a call over grep/glob/Read, how to read a result honestly (pointer, not answer; staleness), how to wire it into a project for the first time, and how to check it is actually being used. Use when a project has rozum available and you're deciding whether/how to reach for semantic search, when setting rag.search up for a project that doesn't have it yet, or when an AGENTS.md references this file."
argument-hint: "when-to-use | connect | verify | troubleshoot"
---

# rag — retrieval that has to earn its call

This skill is agent-independent: plain markdown about a discipline, usable by any
agent that reads it — load it from `AGENTS.md` or invoke it directly. It documents
`rag.search`, an MCP tool rozum serves over a project's own code and docs: markdown
chunked by heading, code chunked by item (`fn`/`struct`/`impl`/…), ranked by BM25
fused with embeddings when both are available.

**The whole skill fits in one sentence: a coding agent already has grep, glob and
Read — exact, instant, always current — so `rag.search` is worth a call only where
those genuinely lose.** Everything below is either that bar applied to a specific
situation, or the mechanics of getting the tool connected and confirming it fired.

## 1. When it earns the call — and when it doesn't

Reach for `rag.search` when:

- **the exact token is unknown** — a concept or a symptom, not a name: "where is
  admission decided", "why does this retry loop", "how are moves proven sound";
- **the answer is spread across files that share no literal string** — a design
  decision explained in a spec, implemented in three unrelated modules, and none
  of them say the decision's name;
- **you are new to an area and need the shape before the detail** — which files
  exist for this, roughly how they relate — before you commit to reading one.

Do **not** reach for it when:

- **you already know the string, the symbol, or the path.** `grep -rn` or a direct
  `Read` is exact, instant, and immune to a stale index — a tool that returns what
  grep would have returned, slower and less precisely, gets correctly ignored, and
  training yourself to ignore a tool's results is worse than never calling it.
- **you're re-reading something you already opened this session.** The index has
  no notion of what you've seen; you do.
- **the project has no `rag.search` connected at all** — see §3 before assuming
  it's just not needed here.

If you're unsure which side a query is on, ask yourself: *"would `grep -rn` have
found this in one try?"* If yes, that was always the right tool.

## 2. Reading a result honestly

A hit is `path#item` (`crates/rozum-core/src/share.rs#fn acquire_residency`) with a
score and a text excerpt — **a pointer to open, not the answer.** Two things the
response always carries and you should always look at, not just the `results`:

- **`stale`** (bool) — the index may predate a recent edit. `age_secs` says by how
  much. A stale hit pointing at code that moved is worse than no hit; if `stale` is
  true and the query matters, `grep` to confirm before trusting the pointer.
- **`fused`** (bool) — `true` means BM25 + embeddings both ran; `false` means the
  embedding half was unavailable (no gateway, no vectors yet) and you got lexical
  search only, which is closer to a fuzzy grep than to semantic search. A run of
  `false` results is a signal to check §4, not a reason to stop using the tool.

Never quote a hit's text as fact in a reply — open the file. The chunk is old the
moment it's fused into the response; the file on disk is not.

## 3. Connecting it to a project

`rag.search` is opt-in per client, on purpose: injecting it into every gateway
request costs schema tokens on every call whether or not that call needed it (the
`reference` tool-schema-bloat measurement, ~4.9K tokens/request, is why `--lean`
exists). It is registered per MCP client instead. Two shapes, pick one:

- **Already have rozum's meeting-room MCP proxy connected** (`rozum launch`, or
  `rozum mcp install` done once globally)? You already have `rag.search` — it is
  served next to `meeting.*`/`rooms.*` on the same connection, no extra config.
  Confirm with the client's own MCP status command (e.g. `claude mcp list`) — look
  for the `rozum` server, `Connected`.
- **Want retrieval only, no meeting room** (a client that doesn't want the room, or
  doesn't want to join one for this task)? Register the standalone server:
  ```json
  { "rozum-rag": { "command": "rozum", "args": ["rag", "mcp"] } }
  ```
  Self-contained in the `rozum` binary — chunks, embeds (in-process) and serves in
  one process, no meeting daemon, no separate gateway required.

**First use in a fresh checkout:** the index doesn't exist yet. `rozum rag index`
builds it once (tens of seconds on a real repo); after that, both server shapes
refresh it incrementally on every search — editing a file and searching again picks
it up in under a second, not at the next server restart.

## 4. Verifying it's actually being used

Two independent signals, check both — and note the two server shapes log to
DIFFERENT places, an easy thing to check in the wrong file and conclude
"nothing is calling it":

- **In your own session**, a `rag.search` call is a visible tool-call entry in the
  transcript — scroll back and look, or ask the operator to.
- **Server-side**, every successful call logs one line, but where depends on
  which shape is serving it:
  - **Meeting-proxy shape** (`rozum-meet`/`rozum mcp-http` — what a normal
    `rozum` MCP connection actually runs) has NO tracing subscriber at all, so
    it uses its own lightweight file logger instead: `~/.run/rozum/mcp-proxy.log`
    (`$XDG_RUNTIME_DIR/rozum/mcp-proxy.log` if that's set), on by default, off
    with `ROZUM_MCP_PROXY_LOG=0`:
    ```
    1788417832 pid=41048 rag.search query="..." top_k=5 fused=true hits=5 chunks=10782 stale=false
    ```
  - **Standalone shape** (`rozum rag mcp`) DOES run inside the full `rozum-gateway`
    binary, which inits a real tracing subscriber — its line goes to that
    process's own stderr, `info` level, target `rag_search`, on by default:
    ```
    INFO rag_search: rag.search query="..." top_k=5 fused=true hits=5 chunks=10742 stale=false
    ```
  No line for a stretch of active work is the honest answer to "is anyone
  actually calling this" — not a guess from silence, but check the RIGHT file
  for the shape you actually connected to.

## 5. Troubleshooting a `false` you didn't expect

- **`"no_index": true`** — nobody has run `rozum rag index` yet in this project, or
  the background build hasn't finished. The response's own `hint` says which; use
  grep/Read until it's done, or run the index build yourself.
- **`fused: false` every time** — the embedding half isn't reachable: no gateway
  running, or the standalone server's in-process embedder isn't available in this
  build. Retrieval still works (BM25 only), just closer to fuzzy-grep than to true
  semantic search — worth fixing if concept-level queries matter here, not worth
  blocking on if they don't.
- **A hit that's obviously wrong or from a deleted file** — the index is stale in a
  way the incremental refresh hasn't caught (a rare race, not the common case);
  `rozum rag index --full` rebuilds it from scratch.
