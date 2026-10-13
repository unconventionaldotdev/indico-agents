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
- Core vs plugin: generic in core, service-specific in the plugin; a core hook needs a core consumer.
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

## Consistency

- Apply the same fix everywhere the pattern exists, broken or not. A new option on one upload (CSV delimiter) is expected on every upload of that kind; a follow-up PR is acceptable when announced.
- Close a PR superseded by a newer one instead of leaving both open.
- An extension point your own earlier PR added and nobody else uses is removed when a new approach makes it unused; upstream keeps no code "unlikely to be ever needed".
- Removing a round trip with an external service (a callback endpoint) is welcome; say which API contract changes.
- A new scope, permission or capability lands on every surface at once: declaration tuples (legacy included), README ("optional, only needed for X"), settings check, tests.
- Features touching users without an account must specify how those users receive the result.
- A picker shows only candidates the user can act on (own bookings, matching dates), defaults its filters from the context (the event's room), and labels the entry point precisely ("Link existing booking"). Deferred improvements get a tracking issue linked from the thread.
- Every surface showing filtered data uses the filtered accessor.
- Every entry point building the same payload gets the behavior.

## PR Description

- Root cause for fixes, use case for features, Before/After for behavior changes.
- Every claim is in the diff; drop the claim or add the code.
- Proof: how it was tested, on what data, screenshots for UI; measurements for performance (and be ready to share raw data privately).
- "Running in production since ..." when true.
- No generic feature bullets that carry no information.
- Cross-link companion core and plugin PRs (the plugin description references the core PR as `indico/indico#N` or by URL so CI tests against that branch); keep the description current after review changes.
- Enable "allow edits by maintainers".

## Changelog And Versioning

- Core: `CHANGES.rst` entry in every PR. Improvements or Bugfixes for user-visible, Internal Changes for admin or developer facing. Append at the end of the section. Follow-ups add their `:pr:` to the existing entry. ``(:pr:`N`, thanks :user:`login, org`)``. One short sentence, wrapped at the natural break (`thanks` stays on the first line); `:data:` role only for top-level `indico.conf` keys; nested provider keys are double-backtick literals with their location ("to the identity provider settings").
- All contributors go in one ``:user:`a, b, org` `` block; a long-running PR moves its entry to the version it lands in. One entry per feature; a missing feature is an Improvement, not a Bugfix; wording states the user-visible effect ("Allow linking a booking without exact date overlap", "empty files" rather than "zero-byte files"), never "Improve the X feature". Entry goes under the release being developed, not an older one. `:issue:` lists every issue the PR closes in one role (``:issue:`N, M` ``), grouped per entry when a PR closes issues for two features; numbers are verified against the linked issue; no space before a comma in role lists.
- A follow-up landing in the same release edits the existing entry (wording, `:issue:`, `:pr:` lists) instead of adding a second one; check the numbers land on the right entry.
- No entry for internal building blocks with no user-visible effect yet; add it with the feature that uses them. A PR that extends a feature and adds a new admin option gets two entries (extend the existing one, add one for the option), both wrapped at the surrounding line length.
- Third-party assets (placeholder images, icons) state their license in the thread; CC0 or an icon set already in use is fine.
- When an option is renamed during review, the changelog entry, labels and description follow; one entry per PR, no duplicates left behind.
- Plugins: README changelog bullet under the unreleased version (no new heading while the previous one is unreleased). Version tracks the first two Indico parts; new plugins start at `3.3-dev` with `### 3.3` / "Initial release". `-dev` may stay forever without PyPI releases. `dependencies = ['indico>=3.3.X.dev0']` when built against master.
- README title "<Name> Plugin".

## Packaging And Repo Boilerplate

- `pytest.ini`, `pyproject.toml` (inline `authors`, classifiers, `exclude` with comments), license headers copied from a sibling plugin. Own `.header.yml` allowed for a different `owner`.
- No `MANIFEST.in` with hatchling.
- New contrib plugins added to `build.yml` and `pypi.yml` choice lists after the blank option.
- Plugin names say what they add beyond core (`affiliation_extras`), propagated to directory, package, blueprint, entry point.
- No local workarounds upstream (`--basetemp`, macOS paths).
- Compatibility shims carry `XXX` plus the awaited upstream PR; removed once merged.
- Tooling: `make` alone shows help; Makefiles use 8-wide tabs in `.editorconfig`; CI keeps its own commands when it needs different flags.

## Docs

- Sphinx roles, dummy names (`FooPlugin`, `PLUGIN_FOO_API_KEY`), precise locations ("on the plugin class").
- Settings documented in the matching section.

## Commits And Branch Hygiene

- Core: capitalized plain imperative, no prefix. Plugin repos: `Component: Sentence case`. `indico-plugins` merges unsquashed, so each subject stands alone.
- Rebase, never the "Update branch" button or a merge commit (`git pull --rebase origin master`); rebase after tooling changes (`ruff check --fix`, `ruff format`).
- Pull before pushing; reviewers push to contributor branches.
- Lint-clean before review.
- Run every change once, including one-liners.

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
