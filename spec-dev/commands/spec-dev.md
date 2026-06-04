---
description: "Spec-driven development workflow. Write the spec before the code, implement against it, keep them in sync. Use when starting a new feature, reviewing an existing spec, or verifying implementation matches spec."
argument-hint: "write <slug> | review <slug> | verify <slug> | global"
---

# Spec-driven development

Write the spec before the code. The spec is the source of truth — implementation follows it, never silently diverges from it.

**Two levels of spec:**

| Level | File | Purpose |
|---|---|---|
| Global | `$GLOBAL_SPEC` (default: `SPEC.md`) | Normative whole-project spec — language surface, runtime contract, invariants |
| Feature | `$SPECS_DIR/<slug>.md` (default: `specs/<slug>.md`) | Per-feature design — scope, interface, behavior items |

**Action dispatch:**

| Task | Section |
|---|---|
| Read the global project spec | [→ global](#global) |
| Start a new feature spec | [→ write](#write-slug) |
| Review an existing feature spec | [→ review](#review-slug) |
| Check implementation matches spec | [→ verify](#verify-slug) |

---

## Configuration

Both paths are configurable per project. Add to `AGENTS.md`:

```yaml
specs: docs/specs   # directory for per-feature specs (default: specs/)
SPEC: SPEC.md       # global project spec file         (default: SPEC.md)
```

Resolution (run at the start of every action):

```bash
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
GLOBAL_SPEC=$(grep -m1 '^SPEC:' AGENTS.md 2>/dev/null | awk '{print $2}')
GLOBAL_SPEC="${GLOBAL_SPEC:-SPEC.md}"
```

---

## Actions

### global

Read and summarize the global project spec.

```bash
cat "$GLOBAL_SPEC"
```

Use this before writing any feature spec — feature specs must not conflict with language invariants in `$GLOBAL_SPEC`. Report a summary of the relevant sections and flag any pre-existing gaps or contradictions.

---

### write `<slug>`

Before writing any code, write the spec.

1. Resolve paths:
```bash
SLUG="<slug>"
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
GLOBAL_SPEC=$(grep -m1 '^SPEC:' AGENTS.md 2>/dev/null | awk '{print $2}')
GLOBAL_SPEC="${GLOBAL_SPEC:-SPEC.md}"
SPEC_FILE="$SPECS_DIR/$SLUG.md"
mkdir -p "$SPECS_DIR"
```

2. Read `$GLOBAL_SPEC` first — check that the feature does not conflict with existing language invariants or runtime contracts.

3. Create `$SPEC_FILE` using this template:

```markdown
# <Feature name>

## Overview
<One paragraph — what this feature does and why.>

## Interface
<Public contract: API signatures, CLI flags, config keys, types — whatever callers depend on.>

## Behavior
- [ ] <scenario or invariant>
- [ ] <edge case>

## Out of scope
- <What this feature explicitly does NOT do.>

<!-- Optional sections — include when relevant: -->

## Design
<Architecture, module layout, key types, composition with existing code.
Use when the "how" is non-obvious or has meaningful alternatives.>

## Decisions
<Choices made and alternatives rejected. One entry per decision:>
- **<choice>** — chosen because <reason>. Rejected: <alternative> (<why not>).

## Results
<Actual outcomes after implementation: measurements, benchmarks, test counts,
observed behaviour. Fill in after verify step. Use as "before/after" baseline
for future agents.>
```

The `[ ]` items are behavior checkboxes, not task markers — check them off as tests cover each scenario.

`Design` and `Decisions` are optional — omit them for trivial features. Include `Design` when the architecture is non-obvious. Include `Decisions` whenever a meaningful alternative was considered and rejected, so the next agent doesn't re-investigate the same fork. Fill in `Results` after the verify step — it becomes the baseline for future agents working in the same area.

4. If the feature adds new language constructs or changes runtime behavior, update the relevant section in `$GLOBAL_SPEC` as well.

5. Commit the spec **before any implementation**:
```bash
git add "$SPEC_FILE" "$GLOBAL_SPEC"
git commit -m "spec: $SLUG"
```

This commit is the gate. Other agents or humans can review the spec here before implementation starts.

---

### review `<slug>`

Read an existing spec and assess it.

```bash
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
GLOBAL_SPEC=$(grep -m1 '^SPEC:' AGENTS.md 2>/dev/null | awk '{print $2}')
GLOBAL_SPEC="${GLOBAL_SPEC:-SPEC.md}"
cat "$SPECS_DIR/<slug>.md"
```

Check for:
- Missing interface definition (what do callers actually depend on?)
- Vague behavior items (can a test be written for this?)
- Missing out-of-scope section (scope creep risk)
- Conflicts with `$GLOBAL_SPEC` (language invariants, runtime contracts)
- Conflicts with other specs in `$SPECS_DIR/`

Report findings and wait for direction before making changes.

---

### verify `<slug>`

Check that the implementation matches the spec.

```bash
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
GLOBAL_SPEC=$(grep -m1 '^SPEC:' AGENTS.md 2>/dev/null | awk '{print $2}')
GLOBAL_SPEC="${GLOBAL_SPEC:-SPEC.md}"
cat "$SPECS_DIR/<slug>.md"
```

For each `- [ ]` behavior item:
- Find the corresponding test or code path
- Mark `- [x]` if covered, leave `- [ ]` if not

Report uncovered items. If implementation differs from spec:
- Small divergence (impl is right): update the spec, commit `spec-update: <slug>`
- Large divergence (spec is right): file as a bug, do not silently accept

Also verify that `$GLOBAL_SPEC` is still in sync — if the feature changed global invariants, the global spec must reflect them.

---

## Spec lifecycle

```
read global spec ($GLOBAL_SPEC) → check for conflicts
    ↓
write feature spec → commit "spec: <slug>"
    ↓
implement against spec
    ↓
if spec gap found → update spec first → commit "spec-update: <slug>" → then code
    ↓
verify → check off behavior items → commit "spec-verify: <slug>"
    ↓
spec stays in repo as living documentation
```

**Rules:**
- Never start implementation without a committed spec.
- Never let implementation silently diverge from the spec.
- If the spec is wrong, fix the spec first — in its own commit, before fixing the code.
- Specs are never deleted when a feature is done — they become living documentation.
- `$GLOBAL_SPEC` is the normative source for language-level invariants — feature specs must not contradict it.

---

## Integration with multi-agent

In the autonomous loop, step 5 expands to:

```
5a. Run /spec-dev global → read $GLOBAL_SPEC, check for conflicts
5b. Run /spec-dev write <slug> → commit spec (+ update global spec if needed)
5c. Implement against spec
5d. If spec gaps found → /spec-dev write <slug> (update) → commit spec-update
5e. Run tests until green
5f. Run /spec-dev verify <slug> → check off behavior items
```
