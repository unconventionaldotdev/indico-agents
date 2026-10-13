---
name: review-indico-scope
description: Scope, product and process checklist for reviewing Indico core and plugin changes against upstream review standards. Covers appetite, feature placement, consistency across surfaces, PR description, changelog, versioning, packaging, docs, commit hygiene and the review conversation. Use through review-indico-pr, or before opening an upstream PR.
---

# review-indico-scope

Run first. A PR that fails here gets no line-by-line review.

Two kinds of rules live here: properties the change must have (checked against the diff, the description and the changelog) and ways the author must behave while the PR is under review. The Commits and Conversation sections separate the two with subheadings.

## Appetite And Placement

### Does it belong

- Question the premise before the code: a feature needs a use case, a frequency and real examples before upstream wants it.
- Limits, thresholds and workarounds need a real example and a frequency.
- Restrictions without a reason (a fixed delimiter set) are dropped.
- Niche provider settings belong on the tenant or in a custom plugin, not in a general-purpose plugin.
- A capability the PR does not wire up and describes as untested is dropped until its consumer lands; "should work in theory" is not merged.
- Noise is a product bug: a log or notification fired by an implicit, frequent action is silenced before merge.
- Constraints that are impossible to add later (consistency within an event) are worth adding now.
- Instance-wide constraints that collide on large installations are rejected; plugins add stricter checks via schema signals.
- State the expected data volume of the first deployment when scaling is a known limit.
- Behavior that only works on small instances is redesigned (server-side filtering, bounded ranges) before merge: upstream retests list views against a production-size database.

### Core, plugin or deployment

- Generic code lives in core, service-specific code in the plugin; a core hook needs a core consumer.
- UI that does nothing without a specific plugin is not merged: make it opt-in through a template hook variable (hidden by default) or keep it in the plugin.
- Code that is hard to review or maintain client-side (format sniffing, parsers) stays on the server even when that costs a request.
- Per-event behavior is an event or room setting; a global plugin setting needs a reason.
- Infrastructure-provided secrets stay optional; the admin UI remains the default way to configure them.
- A new third-party integration ships behind a global `indico.conf` flag (`ENABLE_X`, default off); when off, every related surface is hidden and stored configuration is left untouched.
- An option the current user cannot make work (it depends on configuration one level up) is not shown at all.
- An integration that only partly covers a feature states the limitation in the setting description.
- No migrations for pre-release data.

### Settings and toggles

- Changes to existing workflows are opt-in and off by default, or narrowed to the unambiguous case.
- Exception to the previous rule: a setting that only toggles a harmless convenience is dropped and the behavior allowed unconditionally.
- A setting with exactly two values and no plausible third is a boolean named after the non-default behavior (`collapse_days`), not a string option.
- A future related setting is a separate option, never a third value of an existing one.
- Permissions are granted narrowly.
- A configuration that leaves nothing to display (no publishable file type, a hide flag on) is allowed and warned about on the management page.
- A debatable product rule is a warning, never a hard validation error.
- A fallback mode for unconfigured data covers what existing deployments hold; check real events before narrowing a widget (several files per revision means no single-file widget).
- An "Experimental" or "beta" notice needs a condition for its removal; without one it is dropped.
- An admin page configuring rules whose effect is hard to predict (regex patterns, templates) ships a test area rendering sample input with the current rules.
- Resource-heavy per-user features (a full data export) ship with an instance-level cap (`MAX_DATA_EXPORT_SIZE`) and an option to skip the heavy part (`include_files`), both documented with defaults.
- A flow that blocks users until they act (forced acceptance of updated terms) exempts admins and shows them a persistent top banner, like the global announcement and impersonation banners.

### Scope of the PR

- Incremental scope is fine; fold in small related checks when asked.
- Prefer the minimal change that avoids a refactor of adjacent code (a refresh hint over re-fetching state).
- Bugfixes found while building a feature ship as a separate PR with their own changelog entry.
- A follow-up idea raised mid-review ships as a separate PR.
- Two concerns in one PR (rate limiting and the password reset flow) are split when asked.
- A feature and the internal building block it introduces (a design system, a shared stylesheet layer) are split into two PRs only when they already live in separate commits.
- A repository tooling improvement the feature does not need (a converter script for a generated asset block, better region markers) goes to a follow-up PR; the feature lands with the minimal workaround.
- A fix several custom elements need (surviving a temporary disconnect when the DOM moves them) lands as a shared base in its own PR; the feature PR adopts it instead of patching one element.
- A change that needs a library change (`flask-multipass`) waits for the version bump instead of shipping a workaround.
- Do not generalize for hypothetical reuse: a component or endpoint built for one consumer takes that consumer's identifier (the event id), not a free-form parameter (a URL) plus validation.
- Props and kwargs no call site sets to a non-default value are dropped; add them back with the consumer that needs them.
- A generic element that fell out of the work is kept only when it has a plausible consumer.
- Adding missing logging across a module is its own PR with its own changelog entry.

### Designing a replacement

- When a UI direction is contested, propose the simplest model, let upstream and product decide, then implement that model fully, removing the toggle it replaces.
- Prefer an explicit control per intent (one trigger per end of a range) over inferred intent.
- When reviewers call a behavior "too much magic", go back to the explicit model instead of adding hints to explain it.
- Agree on control semantics before building: a field that only accepts the listed options is a (searchable) select; a combobox is a free-text input with suggestions.
- A reimplementation keeps the restriction semantics of the control it replaces.
- A reimplementation of a shared widget lists what the other call sites of the old one need (disabled targets with a reason, programmatic opening, custom action, a range opened from either end, bounds changing after mount).
- Each listed need of the other call sites is covered in the PR or committed to in a follow-up.
- Walk the old widget's flows in every consumer before asking for review.

## Consistency

### Same behavior on every surface

- Apply the same fix everywhere the pattern exists, broken or not.
- Every entry point building the same payload gets the new behavior.
- A new option on one upload (CSV delimiter) is expected on every upload of that kind; a follow-up PR is acceptable when announced in the thread.
- A new scope, permission or capability lands on every surface in the same change: declaration tuples (legacy included), README ("optional, only needed for X"), settings check, tests.
- A new attribute of an existing concept (weekdays on a weekly repetition) reaches every consumer before review: availability search, suggestions, conflict checks, the edit flow and its split logic, email texts and edit-log messages, the public API's short names.
- A new attribute of an existing concept also works for rows created before the attribute existed.
- A new registration field type is checked on every surface that renders field data: list cell and filter (`filter_choices`, `create_sql_filter`), emails (`render_friendly_data`), badges and documents, exports.
- A new registration field type gets an icon no other type uses, taken from the project icon font.
- A feature touching users without an account specifies how those users receive the result.
- A rule with a deliberate exemption (bulk judgment by managers) names it in the setting description or drops the exemption; the wording never contradicts the behavior.
- A second delivery format for the same artifact (a wallet ticket next to the PDF ticket) reuses the existing payload builders and subclasses the existing request handler so check-in and access rules stay identical.
- An operation offered for core (`push`, `pull`) is offered for plugins too unless the description says why not.

### Pickers and CLI entry points

- A picker shows only candidates the user can act on (own bookings, matching dates).
- A picker defaults its filters from the context (the event's room).
- A picker's entry point is labelled precisely ("Link existing booking").
- A picker over scheduled items shows the time range next to the title, both in the list and in the stored friendly data.
- New CLI subcommands mirror the argument shape of existing tooling (`indico`, `plugin <dir>`, `all-plugins <dir>` as in `build-assets.py`).
- A subcommand named in the plural accepts several targets; otherwise it is singular.

### Completeness of replacements and removals

- A reimplemented widget keeps every affordance of the one it replaces (clear-search button, action button) unless the removal is announced.
- A replacement component never merges under a numbered alias (`DateRangePicker2`): consumers migrate, the old component, its stylesheet and library imports are deleted, and the suffix is dropped in the same PR.
- Replacing a legacy dialog or endpoint means grepping the templates for every trigger of the old one (`url_for('.old')`, `data-href`, buttons in `_common.html`) and walking each variant (one item vs several).
- A CLI command that replaces a script or an older command reproduces every step of what it replaces (cleanup of empty output files, exit codes, per-plugin coverage); diff the old script before claiming parity.
- When a mechanism is copied from a sibling module (editing to paper reviewing), every concept tied to the source module goes: service mixins, context names, user search tokens, validators encoding the source module's rules, options only the source needs.
- An extension point your own earlier PR added and nobody else uses is removed when a new approach makes it unused; upstream keeps no code "unlikely to be ever needed".
- Removing a round trip with an external service (a callback endpoint) is welcome; say which API contract changes.

## PR Description

### What the description states

- Root cause for fixes.
- Use case for features.
- Before/After for behavior changes.
- No generic feature bullets that carry no information.
- A deliberate omission (no checkbox, behavior applied implicitly) is stated with its reason instead of being discovered in review.
- Known limitations are stated with their mitigation ("a catastrophic regex hangs the parser; the surface is admin-only") instead of being discovered in review.
- An accessibility PR names the concrete barriers it removes (options not announced, effect of typing unclear), not "accessibility issues".
- Third-party assets (placeholder images, icons) state their license in the description or the thread; CC0 or an icon set already in use is fine.

### Side changes and scope notes

- State which call sites the PR migrates and which keep the old implementation.
- New third-party dependencies are named with what each is for.
- Plugin extension points added on the way (a template hook, exported components, a block around a form) are listed so each can be judged separately.
- Cross-cutting changes made on the side (CORS enabled for a set of endpoints, a new library) are listed so each can be judged separately.
- A PR adding API endpoints lists each URL with its methods.
- Problems found on the way that are not the PR's topic (validation gaps in an a11y PR) are named as out of scope; fix them in the same PR only when asked.

### Claims, proof and links

- Every claim is in the diff, permissions included: drop the claim or add the code.
- Proof of testing: how it was tested and on what data; screenshots for UI changes.
- Performance claims come with measurements; be ready to share the raw data privately.
- "Running in production since ..." when true.
- Companion core and plugin PRs are cross-linked; the plugin description references the core PR as `indico/indico#N` or by URL so CI tests against that branch.
- A change that depends on a library change lists the related PRs with checkboxes and the required version bump.
- Keep the description current after review changes; when an option is renamed during review, the description and labels follow.
- Enable "allow edits by maintainers".

## Changelog And Versioning

### Entry wording

- One short sentence stating the user-visible effect ("Allow linking a booking without exact date overlap"; "empty files" rather than "zero-byte files"); never "Improve the X feature".
- A feature entry names what users can now do ("take a picture with the webcam, crop and rotate it"), not the artifact ("Add support for the X field").
- A UI change entry leads with the benefit and the condition that triggers it.
- Additions aimed at integrators are worded with the UI's terms ("editing workflow service").
- CLI commands are double-backtick literals (``indico i18n``) and the sentence says what the command now supports; never "Improve X cli and add new cli".
- An experimental feature's entry says so and names the opt-in setting.
- `:data:` role only for top-level `indico.conf` keys; nested provider keys are double-backtick literals with their location ("to the identity provider settings").
- Attribution: ``(:pr:`N`, thanks :user:`login, org`)``, with all contributors in one ``:user:`a, b, org` `` block.
- `:issue:` lists every issue the PR closes in one role (``:issue:`N, M` ``), grouped per entry when a PR closes issues for two features; numbers are verified against the linked issue.
- Role syntax is checked character by character (`:user:` with both colons); no space before a comma in role lists.
- Wrap at the surrounding line length, at the natural break; `thanks` stays on the first line.

### Which section

- Core: a `CHANGES.rst` entry in every PR.
- Exception: a PR shipping only an internal building block with no user-visible effect yet gets no entry; add it with the feature that uses it.
- Improvements or Bugfixes for user-visible changes; Internal Changes for admin- or developer-facing changes and for integrator additions (a service hook, an API endpoint).
- A missing feature is an Improvement, not a Bugfix.
- Accessibility work goes under `Accessibility`, worded by the user-visible result; when the version has no such section yet, create it between Bugfixes and Internal Changes.
- New custom elements get a separate Internal Changes entry naming each (``<ind-with-tooltip>``).
- "Major Features" is filled when preparing the release; a new feature goes under Improvements and is promoted later.

### Entries per PR and position

- Append at the end of the section.
- The entry goes under the release being developed, never an older one; a long-running PR moves its entry to the version it lands in.
- One entry per feature and per PR; a follow-up landing in the same release edits the existing entry (wording, `:issue:`, `:pr:` lists) instead of adding a second one, and the numbers land on the right entry.
- When an option is renamed during review, the changelog entry follows.
- A PR that extends a feature and adds a new admin option gets two entries: extend the existing one, add one for the option.
- A PR shipping a feature plus an internal building block (a design system, a shared stylesheet layer) gets two entries: the feature under Improvements, the building block under Internal Changes.
- The two blank lines closing a version block stay.
- After a rebase the changelog diff adds only this PR's entries.

### Versioning

- Plugins: the changelog bullet goes in the README under the unreleased version; no new heading while the previous one is unreleased.
- The plugin version tracks the first two Indico parts; new plugins start at `3.3-dev` with `### 3.3` / "Initial release".
- `-dev` may stay forever without PyPI releases.
- `dependencies = ['indico>=3.3.X.dev0']` when built against master.

## Packaging And Repo Boilerplate

### New plugin boilerplate

- `pytest.ini`, `pyproject.toml` (inline `authors`, classifiers, `exclude` with comments) and license headers are copied from a sibling plugin.
- An own `.header.yml` is allowed for a different `owner`.
- No `MANIFEST.in` with hatchling.
- New contrib plugins are added to the `build.yml` and `pypi.yml` choice lists after the blank option.
- Plugin names say what they add beyond core (`affiliation_extras`), propagated to directory, package, blueprint and entry point.
- README title is "<Name> Plugin".
- New data directories (templates, static files, translations) are added to the package data configuration so they ship in the wheel.

### Dependencies and shims

- Adding one npm package must not rewrite `package-lock.json`: `npm ci` on a clean tree, then `npm i <pkg>`; a lockfile diff that downgrades unrelated packages is regenerated.
- New Python dependencies go in `requirements.in`; `requirements.txt` is regenerated with `pip-compile` (alphabetical, `# via` comments) pinning the latest release, never hand-edited.
- Tooling from the Indico organisation (`unbeheader`) is installed unpinned in CI.
- Compatibility shims carry `XXX` plus the awaited upstream PR and are removed once it merges.

### CI and tooling

- No local workarounds upstream (`--basetemp`, macOS paths).
- `make` alone shows help.
- Makefiles use 8-wide tabs, declared in `.editorconfig`.
- CI keeps its own commands when it needs different flags than the Makefile.
- When a PR replaces a command CI invokes, every workflow step moves to the new invocation, including steps the author did not touch (JS and React extraction next to Python).
- CI runs the variant that can fail (`--react`): steps exist to catch failures.
- `::add-matcher::` / `::remove-matcher::` blocks around a step stay when the command changes; they produce the PR annotations.
- Scripts that regenerate or normalize project assets (icon font CSS) live in `bin/maintenance/`, never behind an external pastebin or codepen link.
- Machine-maintained regions in source files are delimited by markers that say so (`/* BEGIN GENERATED ... */`, `/* END GENERATED ... */`).

## Docs

### Sphinx and settings docs

- Use Sphinx roles.
- Use dummy names (`FooPlugin`, `PLUGIN_FOO_API_KEY`).
- Give precise locations ("on the plugin class").
- Settings are documented in the matching section.
- Every `.. data::` setting entry ends with a `Default:` line, after a blank line, showing the literal default; units take a space (`10 GB`).
- A setting storing a URL to an externally fetched asset documents that it must be publicly reachable and whether changes affect existing objects.
- After editing an `.rst` sentence, rejoin the wrapped lines so no short leftover line remains ("Run the command ``x`` and:" on one line).
- Settings docs go in the section matching the setting's topic ("System", not "Development").

### READMEs and prose

- A new custom element ships a `<name>.README.md` next to it with the expected markup and known pitfalls.
- Spell-check READMEs and inline docs before review.
- README and other prose files carry no license header: the header-update tool does not track them.
- Project documentation is Markdown (`README.md`), never `.txt`.
- Code samples in READMEs follow the project style (2-space SCSS indentation, single quotes in `@use` paths).
- Directive and keyword names in prose are backticked (`@extend`, `@media`).
- The product is "Indico", not "the Indico app".
- A README introducing a new pattern documents its known caveats and the workaround (placeholder `@extend` does not apply inside `@media`; keep a mixin for those cases).

## Commits And Branch Hygiene

### Commit messages and history (check the change)

- Core: capitalized plain imperative, no prefix.
- Plugin repos: `Component: Sentence case`.
- `indico-plugins` merges unsquashed, so each subject stands alone.
- Review-stage history is small single-purpose commits, one per review point, pushed as fix-ups; squash only when asked.
- Contested visual tweaks go in their own commit so before and after can be compared.
- Debug leftovers in review-stage commits (`console.log`, half-done `TODO fix properly and remove` adapters) are removed by the next push; reviewers delete them silently and judge the cleaned state.

### What the diff must not contain (check the change)

- Lint-clean before review.
- No trailing whitespace in any file type (`.rst`, `.html`, `.scss`): the linters only cover Python and JS.
- Values lowered for manual testing (a page size of `N`) are reverted before review; build a dataset large enough to exercise the real default.
- Developer conveniences added while building (a `?preview` query arg that bypasses date checks) are removed before review; anything not used by the feature is dropped.
- Never run a formatter over a whole file: format only the changed selection, disable format-on-save, stage with `git add -p`; a diff that rewraps unrelated code is reverted before review.
- Never regenerate `.pot` or `.po` catalogs in a PR: extraction and the translation upload run upstream separately, and the line-number churn only creates conflicts.
- No debug leftovers (`print`, `console.debug`, throwaway routes); stage with `git add -p` to keep them out.
- A changed user-facing string is drive-by only when the feature left its meaning intact; a description that would become false without the edit is in scope.
- A rewrap that fixes visibly wrong indentation in a hunk the change touches anyway is reviewed on its merits; ask to revert only when the result is no better than the original.

### Working the branch (author behavior)

- Rebase, never the "Update branch" button or a merge commit (`git pull --rebase origin master`).
- Rebase after tooling changes (`ruff check --fix`, `ruff format`).
- Pull before pushing: reviewers push to contributor branches.
- Run every change once, including one-liners.
- A PR closed by an accidental empty push is recovered with `git push --force origin <sha>:<branch>` and the reopen button, then rebased.
- Before becoming unavailable mid-review, push the current state so the reviewer can continue from it.
- A PR with an Alembic revision gets the `alembic` label.

## Conversation

### Answering review

- Reply per thread with the commit link and, when not self-evident, how it was verified.
- Answer every thread, including the ones GitHub collapses as outdated or hides behind "load more"; questions raised in issue comments get answered like inline threads.
- Before replying "fixed", confirm the commit is on the PR branch, the build picked it up and the fix was re-tested.
- Resolve every thread you addressed once its fix is pushed and re-tested; outdated code hides unresolved threads otherwise.
- Resolve every TODO in the description before asking for the final review.
- Flip draft to ready once the open threads are closed; the final review waits on drafts.
- A PR waiting on a product or placement decision goes to draft and is closed when it stalls.
- Disagree with reasoning and real constraints, then let upstream decide; a documented tradeoff is accepted.
- When a reviewer asks whether an update can be skipped, point at the flag that already gates it (`update=False` default) rather than defending the design.

### Working with reviewers

- Upstream may push refactors directly (moving config to columns, extracting a controller component); build on them instead of keeping a parallel implementation.
- Apply and test patches posted by upstream or other contributors, credit them, re-check their scenarios and say so in the thread.
- Feedback you give names the concrete fix: expected structure in a code block, screenshot with the problem marked.
- One thread per point: open review comments on a dummy diff line rather than piling points into one issue comment.
- Adding technical debt (framework overrides) is agreed explicitly in the thread before it is written.

### Agreeing on design in the thread

- Multi-state interaction logic (selection state x trigger used x click target) is agreed as an outcome table in the thread before coding, every row readable on its own.
- Contested widget behavior (where the search box lives, how clearing works) is prototyped in a standalone sandbox linked from the thread and agreed there before it goes into the PR.
- A replacement for an existing feature may keep the legacy path behind a separate button ("PDF (Legacy)") while reviewers compare output; the legacy code is removed in the same PR before merge.

### Reproducing and debugging

- When upstream cannot reproduce, debug in the thread and post the exact finding.
- A claim that a simpler equivalent "does not work" comes with the failing output; reproduce with a minimal snippet before accepting it.
- A visual bug that cannot be reproduced: ask for the reporter's browser and steps, then retry there.
- A bug found with local modifications comes with the exact patch used to reproduce it.
- A reviewer who wires the new component into another module to test it pushes that commit instead of keeping a stash.

### Closing and follow-ups

- When a side feature stalls the review, revert it and merge the core change; remove every leftover of the reverted part (imports, widget options, whitespace).
- Close your own PR when the premise fails.
- Close a PR superseded by a newer one instead of leaving both open.
- Follow-up discussions (the next widget to replace) and deferred improvements move to a tracking issue linked from the thread.
