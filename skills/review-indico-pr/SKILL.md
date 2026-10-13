---
name: review-indico-pr
description: Review an Indico core or plugin change against upstream review standards, then walk the developer through each finding and apply the agreed fix locally. Works on an open PR, on the current branch (committed and uncommitted changes) against master before a PR exists, or on the commits about to be pushed. Use before every push, before opening or requesting upstream review of an Indico change, or when reviewing a teammate's Indico PR.
---

# review-indico-pr

Orchestrator. The checklists live in the layer skills; read all four before producing findings:

- `../review-indico-scope/SKILL.md`: appetite, placement, description, changelog, packaging, process.
- `../review-indico-backend/SKILL.md`: Python, SQLAlchemy, forms, schemas, signals, RHs, config, security.
- `../review-indico-frontend/SKILL.md`: React, SCSS, Jinja, i18n.
- `../review-indico-tests/SKILL.md`: pytest conventions.

## How Upstream Reviews

1. Runs the code. Clicks through every affected page as every affected role. UI bugs come back as screenshots.
2. Reads prose against code: docstrings, comments, PR description, changelog. Any claim not backed by the diff is a finding.
3. Knows the framework. Rejects code that re-implements a helper, a kwarg or a mixin Indico already has.
4. Measures. Performance claims are timed on a large instance.
5. Questions the premise before the code: use case, frequency, real examples, right level (core, plugin, event setting).
6. Fixes small things directly on the branch: changelog, version bump, alignment, typos, escaping. The author's job is to make those commits unnecessary.
7. Labels preferences as preferences and accepts a reasoned tradeoff.

## Workflow

1. **Target.** Three modes:
   - **PR mode** (a PR number or URL is given): `gh pr view <n> --json number,title,body,baseRefName,headRefOid,baseRefOid,url,author,isDraft`, check the branch out, diff against the merge base with the base branch. Review threads already on the PR count as context, not as findings to repeat.
   - **Branch mode** (no PR yet, the default when the developer is on a feature branch): the change set is everything on the branch plus the working tree, committed or not. Locate the base remote (`upstream` when it exists, else `origin`), `git fetch` it, then `git diff $(git merge-base HEAD <remote>/master)` for tracked changes and `git status --porcelain` for untracked files, which are read whole. Never stash, checkout or otherwise touch the working tree. The description and changelog checks run on what exists (commit messages, `CHANGES.rst` or the plugin README diff); missing ones are findings at the "Reviewer would fix" level with a draft text, since the PR description is still to be written.
   - **Push mode** (the developer is about to push): the change set is the commits not yet on the remote branch. `git fetch` the push remote, then `git diff <remote>/<branch>..HEAD` when the branch exists there, else the branch mode diff against master. Uncommitted changes are out of scope: they are not being pushed. Findings fixed here go in a new commit, never an amend, so the review covers exactly what leaves the machine.
   In every mode identify the repository kind (core, `indico-plugins`, `indico-plugins-contrib`, a private plugin) because changelog, commit and packaging rules differ.
2. **Read beyond the diff.** For each touched symbol open the full file, its callers, its siblings (the webinar twin of a meeting path, the other RHs in the module, the other templates showing the same number), and the companion repo when core and plugin change together.
3. **Run the layers** in order scope, backend, frontend, tests. Scope runs once over the whole change. The other three run per changed file: pick the sections that match the file (an RH file gets Request Handlers, Logging and Security; a `.jsx` gets React and Verification; a `_test.py` gets the tests skill) and walk every bullet of those sections against the hunk and its surrounding code. Record each finding with file:line, problem, fix. Run `pre-commit run --files <changed>` (core) or `ruff check` + `ruff format --check` (plugins).
4. **Present** a top-level remark when the premise is off, then:

```markdown
| # | Level | Location | Finding |
|---|-------|----------|---------|
| 1 | Blocking | `path.py:302` | ... |
```

   Levels: **Blocking** (wrong behavior, security, unfiltered surface, unhandled sibling path, architecture upstream will not merge), **Should fix** (works but will be sent back), **Preference** (mentioned, accepted either way), **Reviewer would fix** (changelog, formatting, typos).

5. **Walk through** one finding at a time, highest level first: code with context, the comment in upstream voice, the fix as a diff (GitHub suggestion block when under three lines), then `AskUserQuestion`: Apply as suggested / Apply differently / Skip. No edits before the developer picks. No batching.
6. **Apply.** Failing test first when the area has tests (`../write-indico-test/SKILL.md`). Surgical edits. Re-run the narrowest test and the linters. Remove what the fix orphaned.
7. **Verify as CI would.** After the last applied fix, run what the repository's CI runs and report the result; not green means the review is not finished:
   - Core: `pre-commit run --files <changed files>` (ruff, eslint, prettier, stylelint, headers), `pytest` on every test module whose package was touched (full `pytest` when models, migrations or shared helpers changed), `npm run lint` when JS/SCSS changed, `indico db_diff` when models changed (must print nothing).
   - Plugins: `ruff check` and `ruff format --check` on the plugin, `pytest <plugin dir>`, `npm run lint` when JS changed, the plugin's `tests` workflow when a core version bump is involved.
   - Private hosts: the commands and fixtures listed in the host repository instructions.
   Fix every failure the review introduced; a pre-existing failure is reported with its output, never silenced.
8. **Close** with fixed findings, skipped findings and the reason given, and what still needs a manual check (browser, external service). Draft GitHub comments only on request; ask before posting.

## Voice

- Question first: "Shouldn't this also ...?", "Why not `x`?", "How about `y`?".
- Name the alternative, skip the lecture: "I'd move that to `util.py`."
- Suggestion blocks for short fixes, one line of reason below.
- Evidence when tested: numbers, screenshot, exact error.
- Explicit weight: "I don't have a strong opinion here though.", "Fine for now."
- One or two sentences. No praise padding, no "nit:", no restating the diff, no em dashes.

## Guardrails

- Never edit before the developer picks an option.
- Never commit, push or post without an explicit request.
- Verify every finding against the full file and callers before reporting it.
- Never drop a finding for being small.
