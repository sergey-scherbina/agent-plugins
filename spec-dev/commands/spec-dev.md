---
description: "Spec-driven development workflow. Write the spec before the code, implement against it, keep them in sync. Use when starting a new feature, reviewing an existing spec, or verifying implementation matches spec."
argument-hint: "write <slug> | review <slug> | verify <slug>"
---

# Spec-driven development

Write the spec before the code. The spec is the source of truth — implementation follows it, never silently diverges from it.

**Action dispatch:**

| Task | Section |
|---|---|
| Start a new feature | [→ write](#write-slug) |
| Review an existing spec | [→ review](#review-slug) |
| Check implementation matches spec | [→ verify](#verify-slug) |

---

## Configuration

The spec directory is configurable per project. Add one line to `AGENTS.md`:

```yaml
specs: docs/specs
```

If absent, the default is `specs/`. The skill reads this before every action.

```bash
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
```

---

## Actions

### write `<slug>`

Before writing any code, write the spec.

1. Resolve spec path:
```bash
SLUG="<slug>"
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
SPEC_FILE="$SPECS_DIR/$SLUG.md"
mkdir -p "$SPECS_DIR"
```

2. Create `$SPEC_FILE` using this template:

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
```

The `[ ]` items are behavior checkboxes, not task markers — check them off as tests cover each scenario.

`Design` and `Decisions` are optional — omit them for trivial features. Include `Design` when the architecture is non-obvious. Include `Decisions` whenever a meaningful alternative was considered and rejected, so the next agent doesn't re-investigate the same fork.

3. Commit the spec **before any implementation**:
```bash
git add "$SPEC_FILE"
git commit -m "spec: $SLUG"
```

This commit is the gate. Other agents or humans can review the spec here before implementation starts.

---

### review `<slug>`

Read an existing spec and assess it.

```bash
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
cat "$SPECS_DIR/<slug>.md"
```

Check for:
- Missing interface definition (what do callers actually depend on?)
- Vague behavior items (can a test be written for this?)
- Missing out-of-scope section (scope creep risk)
- Conflicts with other specs in `$SPECS_DIR/`

Report findings and wait for direction before making changes.

---

### verify `<slug>`

Check that the implementation matches the spec.

```bash
SPECS_DIR=$(grep -m1 '^specs:' AGENTS.md 2>/dev/null | awk '{print $2}')
SPECS_DIR="${SPECS_DIR:-specs}"
cat "$SPECS_DIR/<slug>.md"
```

For each `- [ ]` behavior item:
- Find the corresponding test or code path
- Mark `- [x]` if covered, leave `- [ ]` if not

Report uncovered items. If implementation differs from spec:
- Small divergence (impl is right): update the spec, commit `spec-update: <slug>`
- Large divergence (spec is right): file as a bug, do not silently accept

---

## Spec lifecycle

```
write spec → commit "spec: <slug>"
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

---

## Integration with multi-agent

In the autonomous loop, step 5 expands to:

```
5a. Run /spec-dev write <slug> → commit spec
5b. Implement against spec
5c. If spec gaps found → /spec-dev write <slug> (update) → commit spec-update
5d. Run tests until green
5e. Run /spec-dev verify <slug> → check off behavior items
```
