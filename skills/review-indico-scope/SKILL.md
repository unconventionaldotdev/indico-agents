---
name: review-indico-scope
description: Scope, product and process checklist for reviewing Indico core and plugin changes against upstream review standards. Covers appetite, feature placement, PR description, changelog, versioning, packaging, docs and the review conversation. Use through review-indico-pr, or before opening an upstream PR.
---

# review-indico-scope

Run first. A PR that fails here gets no line-by-line review.

## Appetite And Placement

- Does upstream want it? Niche provider settings belong on the tenant or in a custom plugin, not in a general-purpose plugin.
- Limits, thresholds and workarounds need a real example and a frequency; restrictions without a reason (a fixed delimiter set) are dropped.
- Code that is hard to review or maintain client-side (format sniffing, parsers) stays on the server even when a request is needed.
- Per-event behavior is an event or room setting; global plugin settings need a reason.
- Core vs plugin: generic in core, service-specific in the plugin; a core hook needs a core consumer. UI that does nothing without a specific plugin is not merged: either opt-in through a template hook variable (hidden by default) or kept in the plugin. A PR waiting on that decision goes to draft and is closed when it stalls.
- Infrastructure-provided secrets stay optional; the admin UI remains the default.
- Incremental scope is fine; split follow-ups when asked, fold in small related checks when asked. Prefer the minimal change that avoids a refactor of adjacent code (a refresh hint over re-fetching state).
- State the expected data volume of the first deployment when scaling is a known limit. Upstream retests list views against a production-size database; a behavior that only works on small instances gets redesigned (server-side filtering, bounded ranges) before merge.
- When a UI direction is contested, propose the simplest model, let upstream and product decide, then implement that model fully (removing the toggle it replaces).
- No migrations for pre-release data.
- Changes to existing workflows are opt-in and off by default, or narrowed to the unambiguous case.
- Permissions are granted narrowly; the description must not claim more than the code grants.
- Instance-wide constraints that collide on large installations are rejected; plugins can add stricter checks via schema signals.
- Constraints that are impossible to add later (consistency within an event) are worth adding now.
- Bugfixes found while building a feature ship as a separate PR with their own changelog entry; so does a follow-up idea raised mid-review. Two concerns in one PR (rate limiting and password reset flow) get split when asked.
- A change that needs a library change (`flask-multipass`) lists the related PRs with checkboxes and the required version bump in the description, and waits for the bump instead of a workaround.
- Noise is a product bug: a log or notification fired by an implicit, frequent action gets silenced before merge.
- A configuration that leaves nothing to display (no publishable file type, a hide flag on) is allowed but warned about on the management page; a debatable product rule is not a hard validation error.
- A fallback mode for unconfigured data must still cover what existing deployments hold; check real events before narrowing a widget (several files per revision means no single-file widget).
- A setting that only toggles a harmless convenience is dropped; allow the behavior unconditionally. A setting with exactly two values and no plausible third is a boolean named after the non-default behavior (`collapse_days`), not a string option; a future related setting is a separate option, never a third value.
- An "Experimental" or "beta" notice needs a condition for its removal; without one it is dropped. An experimental feature's changelog entry says so and names the opt-in setting.
- An admin page configuring rules whose effect is hard to predict (regex patterns, templates) ships a test area rendering sample input with the current rules.
- A capability the PR does not wire up and describes as untested is dropped until its consumer lands; "should work in theory" is not merged.
- A reimplementation of a shared widget lists what the other call sites of the old one need (disabled targets with a reason, programmatic opening, custom action, opening a range from either end, bounds that change after mount) and covers it or commits to the follow-up; walk the old widget's flows in every consumer before asking for review.
- Prefer an explicit control per intent (one trigger per end of a range) over inferred intent; when reviewers call a behavior "too much magic", go back to the explicit model instead of adding hints to explain it.
- A new third-party integration ships behind a global `indico.conf` flag (`ENABLE_X`, default off); when off, every related surface is hidden and stored configuration is left untouched. An option the current user cannot make work (it depends on configuration one level up) is not shown at all. An integration that only partly covers a feature states the limitation in the setting description.
- Resource-heavy per-user features (a full data export) ship with an instance-level cap (`MAX_DATA_EXPORT_SIZE`) and an option to skip the heavy part (`include_files`), both documented with defaults.

## Consistency

- Apply the same fix everywhere the pattern exists, broken or not. A new option on one upload (CSV delimiter) is expected on every upload of that kind; a follow-up PR is acceptable when announced.
- Close a PR superseded by a newer one instead of leaving both open.
- A rule with a deliberate exemption (bulk judgment by managers) names it in the setting description or drops the exemption; the wording never contradicts the behavior.
- An extension point your own earlier PR added and nobody else uses is removed when a new approach makes it unused; upstream keeps no code "unlikely to be ever needed".
- Removing a round trip with an external service (a callback endpoint) is welcome; say which API contract changes.
- A new scope, permission or capability lands on every surface at once: declaration tuples (legacy included), README ("optional, only needed for X"), settings check, tests.
- Features touching users without an account must specify how those users receive the result.
- A picker shows only candidates the user can act on (own bookings, matching dates), defaults its filters from the context (the event's room), and labels the entry point precisely ("Link existing booking"). Deferred improvements get a tracking issue linked from the thread.
- Every surface showing filtered data uses the filtered accessor.
- Every entry point building the same payload gets the behavior.
- Replacing a legacy dialog or endpoint means grepping the templates for every trigger of the old one (`url_for('.old')`, `data-href`, buttons in `_common.html`) and walking each variant (one item vs several).
- When a mechanism is copied from a sibling module (editing to paper reviewing), every concept tied to the source module goes: service mixins, context names, user search tokens, validators encoding the source module's rules, options only the source needs.
- A new registration field type is checked on every surface that renders field data: list cell and filter (`filter_choices`, `create_sql_filter`), emails (`render_friendly_data`), badges and documents, exports; a list value never appears as its Python repr. It gets an icon no other type uses, from the project icon font.
- A picker over scheduled items shows the time range next to the title, in the list and in the stored friendly data.
- A reimplemented widget keeps every affordance of the one it replaces (clear-search button, action button) unless the removal is announced. A replacement component never merges under a numbered alias (`DateRangePicker2`): consumers migrate, the old component, its stylesheet and library imports are deleted and the suffix dropped in the same PR.
- A second delivery format for the same artifact (a wallet ticket next to the PDF ticket) reuses the existing payload builders and subclasses the existing RH so check-in and access rules stay identical.
- Inherited category configuration follows the three-state model used for protection (`disabled` / `enabled` / `inheriting`); no boolean plus "not set" inside a JSON blob.

## PR Description

- Root cause for fixes, use case for features, Before/After for behavior changes.
- Every claim is in the diff; drop the claim or add the code.
- Proof: how it was tested, on what data, screenshots for UI; measurements for performance (and be ready to share raw data privately).
- "Running in production since ..." when true.
- No generic feature bullets that carry no information.
- Cross-link companion core and plugin PRs (the plugin description references the core PR as `indico/indico#N` or by URL so CI tests against that branch); keep the description current after review changes.
- Enable "allow edits by maintainers".
- Known limitations are stated with their mitigation ("a catastrophic regex hangs the parser; the surface is admin-only") instead of being discovered in review.
- State which call sites the PR migrates and which keep the old implementation. New third-party dependencies are named with what each is for. Commits that add plugin extension points on the side (a template hook, exported components, a block around a form) are listed so each can be judged separately.

## Changelog And Versioning

- Core: `CHANGES.rst` entry in every PR. Improvements or Bugfixes for user-visible, Internal Changes for admin or developer facing. Append at the end of the section. Follow-ups add their `:pr:` to the existing entry. ``(:pr:`N`, thanks :user:`login, org`)``. One short sentence, wrapped at the natural break (`thanks` stays on the first line); Additions aimed at integrators (a service hook, an API endpoint) go under Internal Changes, worded with the UI's terms ("editing workflow service"). `:data:` role only for top-level `indico.conf` keys; nested provider keys are double-backtick literals with their location ("to the identity provider settings").
- All contributors go in one ``:user:`a, b, org` `` block; a long-running PR moves its entry to the version it lands in. One entry per feature; a missing feature is an Improvement, not a Bugfix; wording states the user-visible effect ("Allow linking a booking without exact date overlap", "empty files" rather than "zero-byte files"), never "Improve the X feature". Entry goes under the release being developed, not an older one. `:issue:` lists every issue the PR closes in one role (``:issue:`N, M` ``), grouped per entry when a PR closes issues for two features; numbers are verified against the linked issue; no space before a comma in role lists.
- A follow-up landing in the same release edits the existing entry (wording, `:issue:`, `:pr:` lists) instead of adding a second one; check the numbers land on the right entry.
- No entry for internal building blocks with no user-visible effect yet; add it with the feature that uses them. A PR that extends a feature and adds a new admin option gets two entries (extend the existing one, add one for the option), both wrapped at the surrounding line length.
- Third-party assets (placeholder images, icons) state their license in the thread; CC0 or an icon set already in use is fine.
- When an option is renamed during review, the changelog entry, labels and description follow; one entry per PR, no duplicates left behind.
- Plugins: README changelog bullet under the unreleased version (no new heading while the previous one is unreleased). Version tracks the first two Indico parts; new plugins start at `3.3-dev` with `### 3.3` / "Initial release". `-dev` may stay forever without PyPI releases. `dependencies = ['indico>=3.3.X.dev0']` when built against master.
- README title "<Name> Plugin".
- "Major Features" is filled when preparing the release; a new feature goes under Improvements and is promoted later. Accessibility work goes under `Accessibility`, worded by the user-visible result; new custom elements get a separate Internal Changes entry naming each (``<ind-with-tooltip>``).
- A feature entry names what users can now do ("take a picture with the webcam, crop and rotate it"), not the artifact ("Add support for the X field"); a UI change leads with the benefit and the condition that triggers it.
- Role syntax is checked character by character (`:user:` with both colons). The two blank lines closing a version block stay. After a rebase the changelog diff adds only this PR's entries.

## Packaging And Repo Boilerplate

- `pytest.ini`, `pyproject.toml` (inline `authors`, classifiers, `exclude` with comments), license headers copied from a sibling plugin. Own `.header.yml` allowed for a different `owner`.
- No `MANIFEST.in` with hatchling.
- New contrib plugins added to `build.yml` and `pypi.yml` choice lists after the blank option.
- Plugin names say what they add beyond core (`affiliation_extras`), propagated to directory, package, blueprint, entry point.
- No local workarounds upstream (`--basetemp`, macOS paths). Tooling from the Indico organisation (`unbeheader`) is installed unpinned in CI.
- Compatibility shims carry `XXX` plus the awaited upstream PR; removed once merged.
- Tooling: `make` alone shows help; Makefiles use 8-wide tabs in `.editorconfig`; CI keeps its own commands when it needs different flags.
- Adding one npm package must not rewrite `package-lock.json`: `npm ci` on a clean tree, then `npm i <pkg>`; a lockfile diff that downgrades unrelated packages is regenerated.
- New Python dependencies go in `requirements.in`; `requirements.txt` is regenerated with `pip-compile` (alphabetical, `# via` comments) pinning the latest release, never hand-edited.

## Docs

- Sphinx roles, dummy names (`FooPlugin`, `PLUGIN_FOO_API_KEY`), precise locations ("on the plugin class").
- Settings documented in the matching section.
- A new custom element ships a `<name>.README.md` next to it with the expected markup and known pitfalls. Spell-check READMEs and inline docs before review.
- Every `.. data::` setting entry ends with a `Default:` line showing the literal default after a blank line; units take a space (`10 GB`). A setting storing a URL to an externally fetched asset documents that it must be publicly reachable and whether changes affect existing objects.

## Commits And Branch Hygiene

- Core: capitalized plain imperative, no prefix. Plugin repos: `Component: Sentence case`. `indico-plugins` merges unsquashed, so each subject stands alone.
- Rebase, never the "Update branch" button or a merge commit (`git pull --rebase origin master`); rebase after tooling changes (`ruff check --fix`, `ruff format`).
- Pull before pushing; reviewers push to contributor branches.
- Lint-clean before review.
- Run every change once, including one-liners.
- Review-stage history is small single-purpose commits, one per review point, pushed as fix-ups; squash only when asked. Contested visual tweaks go in their own commit so before and after can be compared.
- Before replying "fixed", confirm the commit is on the PR branch and the build picked it up. Flip draft to ready once the open threads are closed; the final review waits on drafts.
- Values lowered for manual testing (a page size of `N`) are reverted before review; build a dataset large enough to exercise the real default.
- No trailing whitespace in any file type (`.rst`, `.html`, `.scss`); the linters only cover Python and JS.
- A PR closed by an accidental empty push is recovered with `git push --force origin <sha>:<branch>` and the reopen button, then rebased.

## Conversation

- Reply per thread with the commit link and, when not self-evident, how it was verified; resolve threads you addressed (outdated code hides them otherwise).
- One thread per point: open review comments on a dummy diff line rather than piling points into one issue comment.
- Upstream may push refactors directly (moving config to columns, extracting a controller component); build on them instead of keeping a parallel implementation. Resolve every TODO in the description before asking for the final review.
- When a side feature stalls the review, revert it and merge the core change; remove every leftover (imports, widget options, whitespace) of the reverted part.
- Disagree with reasoning and real constraints, then let upstream decide; a documented tradeoff is accepted.
- When upstream cannot reproduce, debug in the thread and post the exact finding.
- Apply and test patches upstream posts; say so.
- Incorporate fixes other contributors post, with credit, and re-check their scenarios.
- Close a PR yourself when the premise fails.
- Feedback names the concrete fix: expected structure in a code block, screenshot with the problem marked. Questions raised in issue comments get answered like inline threads; answer every thread, including the ones GitHub collapses as outdated or hides behind "load more". Resolve a thread only after the fix is pushed and re-tested.
- Follow-up discussions (the next widget to replace) move to a new issue. Adding technical debt (framework overrides) is agreed explicitly in the thread before it is written.
- A replacement for an existing feature may keep the legacy path behind a separate button ("PDF (Legacy)") while reviewers compare output; the legacy code is removed in the same PR before merge.
- A claim that a simpler equivalent "does not work" comes with the failing output; reproduce with a minimal snippet before accepting it. A visual bug that cannot be reproduced gets the reporter's browser and steps asked for and is retried there.
- Multi-state interaction logic (selection state x trigger used x click target) is agreed as an outcome table in the thread before coding, every row readable on its own, and implemented as pure functions so a corrected row is a one-line change.
- A bug found with local modifications comes with the exact patch used to reproduce it; a reviewer who wires the new component into another module to test it pushes that commit instead of keeping a stash. Before becoming unavailable mid-review, push the current state so the reviewer can continue from it.
- When a reviewer asks whether an update can be skipped, point at the flag that already gates it (`update=False` default) rather than defending the design.
