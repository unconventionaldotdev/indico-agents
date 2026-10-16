---
name: review-indico-pr
description: Review an Indico core or plugin change against upstream review standards. On the developer's own work (the current branch, the commits about to be pushed, or their own PR) it fixes the findings locally, all at once or one by one as the developer chooses; on a teammate's PR it posts the findings as review comments on GitHub. Use before every push, before opening or requesting upstream review of an Indico change, or when reviewing a teammate's Indico PR.
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
   - **PR mode** (a PR number or URL is given): `gh pr view <n> --json number,title,body,baseRefName,headRefOid,baseRefOid,url,author,isDraft`, check the branch out, diff against the merge base with the base branch. Review threads already on the PR count as context, not as findings to repeat. Compare `author.login` with `gh api user --jq .login`: the developer's own PR is **own work** and ends in local fixes like the other two modes; someone else's PR is a **teammate review** and ends in GitHub comments, never in local edits to their branch.
   - **Branch mode** (no PR yet, the default when the developer is on a feature branch): the change set is everything on the branch plus the working tree, committed or not. Locate the base remote (`upstream` when it exists, else `origin`), `git fetch` it, then `git diff $(git merge-base HEAD <remote>/master)` for tracked changes and `git status --porcelain` for untracked files, which are read whole. Never stash, checkout or otherwise touch the working tree. The description and changelog checks run on what exists (commit messages, `CHANGES.rst` or the plugin README diff); missing ones are findings at the "Reviewer would fix" level with a draft text, since the PR description is still to be written.
   - **Push mode** (the developer is about to push): the change set is the commits not yet on the remote branch, minus what an earlier review of this conversation already covered: when a review of the same `HEAD` already ran (any mode), do not repeat it, say so and let the push go on; when commits were added since, review only those. `git fetch` the push remote, then `git diff <remote>/<branch>..HEAD` when the branch exists there, else the branch mode diff against master. Uncommitted changes are out of scope: they are not being pushed. Before reviewing, bring the branch up to date: fetch the base remote and, when its `master` moved, `git rebase <base remote>/master`. On conflicts, abort the rebase and report them to the developer instead of resolving them silently; with uncommitted changes, skip the rebase and say so, never stash. Commits already on the remote get new hashes, so the push needs `--force-with-lease`, which the developer approves, and the change set is what `git cherry <remote>/<branch>` marks `+`. A finding fixed here is folded into the commit that introduced the offending code (`git commit --fixup=<commit>`, then `git rebase --autosquash <remote>/<branch>`) when that commit is not on the remote yet, so the history that leaves the machine has no fix-up noise. A commit already on the remote, or a branch whose PR is under review, gets a new commit instead; pushed history is never rewritten.
   In every mode identify the repository kind (core, `indico-plugins`, `indico-plugins-contrib`, a private plugin) because changelog, commit and packaging rules differ.
2. **Read beyond the diff.** For each touched symbol open the full file, its callers, its siblings (the webinar twin of a meeting path, the other RHs in the module, the other templates showing the same number), and the companion repo when core and plugin change together.
3. **Run the layers** in order scope, backend, frontend, tests. Scope runs once over the whole change. The other three run per changed file, as a loop, never as one pass over the whole diff:
   - Pick the layer by file kind: `.py` gets backend (plus tests when the path is a test module), `.jsx`/`.js`/`.ts`/`.tsx` and `.scss` get frontend, `.html` templates get frontend Jinja, `CHANGES.rst`, docs and `package.json` get scope.
   - Inside the layer, pick the `## ` sections that match the file (an RH module gets Structure, Naming, Request Handlers And Access, Logging and Security; a model gets Structure, Naming and SQLAlchemy; a `.jsx` gets React plus Verification; a `.scss` gets SCSS) and walk every `### ` group of those sections, bullet by bullet, against each hunk and its surrounding code. Structure and Naming apply to every Python file; any Python file whose hunks build a query (`.query`, `db.session.query`, `select(`) also gets the SQLAlchemy groups Queries, Query style, Eager loading and Soft deletion; React naming, i18n and imports apply to every JS file.
   - Record each finding with file:line, problem, fix, and the bullet it comes from. A bullet that does not apply to the file is skipped silently; a bullet that applies and holds is not reported.
   - After the loop, run the Scenarios groups of the tests skill that match the touched areas as a "what to try manually" list.
   - **Mechanical pass.** Upstream spends most of its comments on conventions the loop above tends to skip. Grep the whole diff for each of these, including hunks already reported for another reason, and check the matching bullet; a hit is a finding at the "Reviewer would fix" level unless the code already follows the rule:
     - `jsonify(` next to `.dump(`: `Schema().jsonify(data)` instead.
     - `methods=(` with `PATCH` or `PUT`: payload-less action endpoints are `POST`; `data-method` in templates matches.
     - `add_url_rule(`: endpoint names without redundant qualifiers; URL prefix matches the audience.
     - `.query` or `.filter(` spanning lines: Query style (`(` on its own line or chained calls aligned, one criterion per line, style of the adjacent queries).
     - `import typing`, `: typing.`: `import typing as t`.
     - Trailing `# ` comments longer than the code before them, or two consecutive statements each ending in a trailing comment: comment on its own line above.
     - Removed or added blank lines, rewrapped lines and renamed strings with no behavior change in the same hunk: drive-by, unless the change made the old text false.
     - `load_only(` followed by attribute reads the dump needs: deferred-column spam.
     - New `def can_` or `is_` wrappers that only call `can_manage` or `is_admin`: remove, call `can_manage` directly.
     - Helpers, imports, fixtures and templates whose last caller the diff removed or guarded away: orphans.
   Run `pre-commit run --files <changed>` (core) or `ruff check` + `ruff format --check` (plugins) before presenting.
4. **Present** a top-level remark when the premise is off, then:

```markdown
| # | Level | Location | Finding |
|---|-------|----------|---------|
| 1 | Blocking | `path.py:302` | ... |
```

   Levels: **Blocking** (wrong behavior, security, unfiltered surface, unhandled sibling path, architecture upstream will not merge), **Should fix** (works but will be sent back), **Preference** (mentioned, accepted either way), **Reviewer would fix** (changelog, formatting, typos).

   The table holds Blocking and Should fix. Preference and Reviewer would fix go below it as one compact list, one line each, so the findings that decide the review stay visible; a long tail of minor findings dilutes them.

5. **Choose the outcome by mode.** The findings are on the table; what happens to them depends on whose work it is.
   - **Own work** (branch mode, push mode, own PR): one `AskUserQuestion` with two options: *Fix everything* (apply every Blocking, Should fix and Reviewer would fix finding as proposed, list Preferences as skipped unless the developer adds them) or *Walk through one by one* (for each finding, highest level first: code with context, the comment in upstream voice, the fix as a diff, then Apply as suggested / Apply differently / Skip). No edits before the developer answers. Then step 6.
   - **Teammate review** (a PR by someone else): no local edits. Draft one review comment per finding in upstream voice (step "Voice"), anchored to the file and line (a multi-line suggestion block takes `start_line` and `line`), with a GitHub suggestion block when the fix is under three lines. No summary comment and no review body: the top-level remark and the manual checks go to the developer in the chat, not to GitHub, unless the developer asks to post them. Show the full draft set, then one `AskUserQuestion`: *Post as a review* (one `gh api` review with the inline comments only, event `COMMENT`, or `REQUEST_CHANGES` when a Blocking finding exists) / *Post only selected ones* / *Do not post*. Post exactly what was confirmed; never post Preferences the developer did not pick. Then step 8.
6. **Apply.** Failing test first when the area has tests (`../write-indico-test/SKILL.md`). Surgical edits. Re-run the narrowest test and the linters. Remove what the fix orphaned. In *Fix everything* mode report each applied finding in one line as it lands, and stop to ask when a fix turns out to need a design decision the finding did not anticipate.
7. **Verify as CI would.** After the last applied fix, run what the repository's CI runs and report the result; not green means the review is not finished:
   - Core: `pre-commit run --files <changed files>` (ruff, eslint, prettier, stylelint, headers), `pytest` on every test module whose package was touched (full `pytest` when models, migrations or shared helpers changed), `npm run lint` when JS/SCSS changed, `indico db_diff` when models changed (must print nothing).
   - Plugins: `ruff check` and `ruff format --check` on the plugin, `pytest <plugin dir>`, `npm run lint` when JS changed, the plugin's `tests` workflow when a core version bump is involved.
   - Private hosts: the commands and fixtures listed in the host repository instructions.
   Fix every failure the review introduced; a pre-existing failure is reported with its output, never silenced.
8. **Close.** Own work: fixed findings, skipped findings with the reason given, the verification result, and what still needs a manual check (browser, external service). Teammate review: the URL of the posted review, the findings left unposted and why, the top-level remark if there is one, and the manual checks the author should run.

## Voice

- Question first: "Shouldn't this also ...?", "Why not `x`?", "How about `y`?".
- Name the alternative, skip the lecture: "I'd move that to `util.py`."
- Suggestion blocks for short fixes, one line of reason below.
- Evidence when tested: numbers, screenshot, exact error.
- Explicit weight: "I don't have a strong opinion here though.", "Fine for now."
- One or two sentences. No praise padding, no "nit:", no restating the diff, no em dashes.

## Guardrails

- Never edit before the developer picks an option; never edit a teammate's branch at all.
- Never commit or push without an explicit request. Post to GitHub only the comments the developer confirmed in step 5.
- Verify every finding against the full file and callers before reporting it.
- Before calling a branch dead, a check redundant or a base attribute unused, read the helper the code actually calls and the full body of the class it extends; cite that code, never a sibling helper that looks similar.
- A finding that undoes a rename, a split, a rewrap or an icon choice first checks whether the current shape was asked for in an earlier review round (PR mode: the existing threads; branch and push mode: the developer). If it was, drop the finding.
- A convention the codebase already follows locally (one icon per concept, locale-neutral badge text, an accepted signature layout) wins over a generic rule in the layer skills; report the generic rule only when the surrounding code does not already settle it.
- Every bullet of a `### ` group applies to every function of the file it matches; a group walked for one finding is still walked to the end for the same function.
- A Preference with no bullet behind it is not reported; a consistency argument invented on the spot ("the sibling is unannotated") is not a rule.
- A mechanical-pass hit is checked against its neighbours before it is reported: a query-layout finding quotes the adjacent query that uses a different layout (same shape everywhere means no finding); a Jinja whitespace finding accounts for the whitespace inside the following inline element; a wording finding quotes the exact words it objects to.
- Never drop a finding for being small.
