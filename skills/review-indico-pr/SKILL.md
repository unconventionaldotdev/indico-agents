---
name: review-indico-pr
description: Review an Indico core or plugin change against upstream review standards, then walk the developer through each finding and apply the agreed fix locally. Use before requesting upstream review, when reviewing a teammate's Indico PR, or when asked to review an Indico change.
---

# review-indico-pr

Review a change to Indico core, `indico-plugins` or `indico-plugins-contrib` the way upstream review does, produce the findings upstream would raise, then resolve them one by one with the developer and apply the agreed fix locally.

This skill is the orchestrator. The review material lives in the layer skills; read all of them before producing findings:

- `../review-indico-scope/SKILL.md`: scope, product judgment, PR description, changelog, packaging, docs, process.
- `../review-indico-backend/SKILL.md`: Python, SQLAlchemy, forms, schemas, signals, request handlers, config, logging, security.
- `../review-indico-frontend/SKILL.md`: React, SCSS, Jinja templates, i18n.
- `../review-indico-tests/SKILL.md`: pytest conventions and fixture usage.

## How Upstream Review Works

Knowing how upstream reviews predicts what it finds.

1. **The code gets run.** Non-trivial PRs are checked out, the feature is exercised in a browser or shell, and the result is compared with what the description claims. UI bugs come back as screenshots. Missing surfaces ("I think you missed some other places") come from clicking around, not from reading the diff. Review as if you had to demo the change.
2. **Call sites and docstrings are read against each other.** A docstring that promises "applied in turn" while the code overwrites the result is called out. Verify every claim in prose against the code it describes.
3. **Framework helpers are known.** Redundant code that a kwarg already handles (`values_from_signal(..., skip_none=True)`), a validator that will `KeyError` on partial input (`@validates_schema(skip_on_field_errors=True)`), a `flash()` reachable from event cloning. Before accepting a pattern, ask whether Indico already provides it.
4. **Performance claims are measured.** Expensive paths are timed on a large production tenant and the numbers are posted. A fix that is correct but slow for the common case is sent back ("This needs to be done in Celery").
5. **The premise is questioned first.** "What usecase do people have for changing this?", "How common is it really?", "Do you have any real examples?". Appetite and scope are reviewed before the code.
6. **Small things get fixed by the reviewer** and pushed to the contributor branch: changelog entries, version bumps, alignment, typos, an `escape()` on a user-provided string. The author's job is to make those commits unnecessary.
7. **Preferences are labeled as such.** "Not strictly necessary ... but if you prefer that's fine", "I don't have a strong opinion here though", "Fine for now". Distinguish blocking findings from preferences and label them.

## Workflow

### 1. Identify the target

```sh
# PR number given: review that PR
gh pr view "$pr" --json number,title,body,baseRefName,headRefOid,baseRefOid,url,author,isDraft

# No argument: review the current branch against its upstream base
git fetch upstream
git merge-base HEAD upstream/master
```

Check out the branch. Reviewing from the diff alone misses what running the code reveals.

### 2. Read everything, not only the diff

```sh
git diff "$base"..."$head" --stat
git diff "$base"..."$head"
git log --oneline "$base".."$head"
```

Then, for every touched symbol:

- open the full file, not the hunk;
- find the callers and the siblings (other request handlers in the same module, the webinar twin of a meeting code path, the other templates that show the same number);
- read the signal docstring, the form field, the schema and the template that render the same data;
- check the companion repository when the change spans core and a plugin.

### 3. Run the layer checklists

Go through the four layer skills in order: scope, backend, frontend, tests. For each item that applies, record a finding with the file and line, what is wrong, why upstream would care, and the fix upstream would propose.

Also run the project linters on the touched files; formatting fixes otherwise arrive as reviewer commits:

```sh
pre-commit run --files <changed files>   # core
ruff check <paths> && ruff format --check <paths>
```

### 4. Present the review

Open with the kind of top-level remark upstream leaves when something is off at the premise level (scope, approach, missing manual test). Then the table:

```markdown
## Upstream-style review: <PR title>

<Top-level remark, if any. One or two sentences.>

| # | Level | Location | Finding |
|---|-------|----------|---------|
| 1 | Blocking | `indico/modules/.../reglists.py:302` | Bulk GET export fails now that access is checked after the list is built; apply the filter when populating the list instead |
| 2 | Blocking | `vc_zoom/.../plugin.py:410` | Webinars skipped; `approval_type` exists for webinars too |
| 3 | Should fix | `vc_zoom/.../forms.py:262` | Error does not say which user lacks a Zoom account |
| 4 | Preference | `.../fields.py:140` | Early return would un-indent the rest of the check |
| 5 | Reviewer would fix | `CHANGES.rst` | Entry belongs under Internal Changes, appended at the end |
```

Levels:

| Level | Meaning |
|---|---|
| **Blocking** | Wrong behavior, security, data exposure, a surface left unfiltered, a sibling code path (webinar/meeting, sections/fields) not handled, an architecture upstream will not merge |
| **Should fix** | Works but will be sent back: imprecise error, redundant mechanism, missing test for the scenario upstream will try, inconsistent naming |
| **Preference** | Upstream would mention it and accept either way; usually comes with a GitHub suggestion block |
| **Reviewer would fix** | Changelog, version bump, alignment, typo, escaping. Zero cost to do it first |

### 5. Walk through each finding

One finding at a time, highest level first. For each:

1. Show the code with enough context.
2. Give the comment as upstream would write it (see Voice below).
3. Show the fix as a diff. When the fix is one or two lines, format it as a GitHub suggestion block, because that is how upstream posts it.
4. Ask the developer with `AskUserQuestion`: **Apply as suggested**, **Apply differently**, **Skip**. Keep option text under 160 characters per line.

Do not touch code before the developer picks. Do not batch findings into one question.

### 6. Apply the agreed fixes

- Behavior changes get a failing test first when the area has tests; see `../write-indico-test/SKILL.md`.
- Keep each fix surgical. Do not reformat around it.
- Re-run the narrowest test, then the linters on the touched files.
- Check what the fix orphaned: an import, a helper, a fixture, a template, a now-unused mechanism (a download-blocking check became dead once the bulk endpoints were filtered, and was removed).

Do not commit or push unless the developer asks. When asked, follow the host repository's commit convention (`../../indico/AGENTS.md` for upstream repositories).

### 7. Close

End with:

- fixed findings;
- skipped findings, with the one-line reason the developer gave, so the PR description or a reply can carry it;
- what still needs a manual check in a browser or against the external service, because upstream will do exactly that;
- when reviewing someone else's PR and the developer wants the comments posted, draft them in the voice below and ask before posting.

## Voice

Upstream comments read like a colleague thinking out loud, not like a linter. Patterns:

- **Question first.** "Why can't this use the `create_regform` fixture from the core?", "webinars don't need this?", "Why are these imports underscored?", "What's the reason for not just failing ... ?"
- **"Shouldn't this also be added to ...?"** for a missing surface.
- **"How about `auto_checkin`?"** for a rename; name the alternative, skip the lecture.
- **"I'd move that to ..."**, **"I'd rather ..."**, **"TBH I'd rather ..."** for preferences.
- **"It would be good to ..."** for improvements expected but not blocking.
- **Suggestion blocks** for anything under three lines, with a one-line reason below: "That way the whole rest of this check no longer needs to be indented."
- **Evidence** when something was tested: numbers, screenshots, the exact error text.
- **Explicit weight:** "I don't have a strong opinion here though.", "Fine for now.", "Not strictly necessary ... but if you prefer ... that's fine for me as well."
- **Short.** Most comments are one or two sentences. A long one carries a design alternative with bullet points.
- No praise padding, no "nit:" prefixes, no restating the diff.

Comments produced here use no em dashes.

## Guardrails

- Never edit code before the developer picks an option for that finding.
- Never commit, push or post to GitHub without an explicit request.
- Never report a finding you have not verified against the full file and its callers. Upstream reads them; a wrong finding costs more than a missing one.
- Never drop a finding because it is small. The small ones are the commits a reviewer will otherwise push.
