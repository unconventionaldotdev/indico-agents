---
name: review-indico-scope
description: Scope, product and process checklist for reviewing Indico core and plugin changes against upstream review standards. Covers appetite, feature placement, PR description, changelog, versioning, packaging, docs and the review conversation. Use through review-indico-pr, or before opening an upstream PR.
---

# review-indico-scope

Run this layer first. Upstream questions the premise before the code, and a PR that fails here does not get a line-by-line review.

## Appetite And Placement

- **Does upstream want it?** A plugin "was never meant to expose every single advanced setting" of the provider. When the value is niche, the answer is "configure it on the tenant" or "do it in your own plugin". Ask for the use case in the description before upstream does: "what usecase do people have for changing this?"
- **Real examples beat heuristics.** For a limit, a threshold or a workaround, expect "How common is it really?" and "Do you have any real examples?". Put the example in the description.
- **Right level for a toggle.** Behavior some events want and others do not is an event or room setting (with `HiddenUnless` on dependent fields), not a global plugin setting.
- **Core vs plugin.** Generic limits belong in core and service-specific limits in the plugin; a core hook needs a core consumer; a core change that exists only to serve one plugin is viewed with skepticism and judged on the actual diff.
- **Secrets and infrastructure config** stay optional from the admin's point of view. Forcing file-based configuration on web-generated secrets "won't get merged".
- **Incremental scope is fine.** "For now it's enough to make the change here." Split the core follow-up out when asked, but include a small related check in the same PR when asked ("I think checking it here would be nice").
- **Existing data and migrations.** Upstream does not ask for migrations of pre-release data.
- **Breaking an existing workflow needs a switch.** Unconditional new behavior on existing forms (resetting approvals, pre-filling fields) becomes a per-form setting, off by default, or is narrowed to the case where it is clearly right (only custom uploaded pictures).
- **Permissions are granted narrowly.** A "manage participants only" permission does not get logs or configuration; when the description claims more than the code grants, the code wins and the description is corrected.

## Consistency Of The Feature

- The same fix is applied everywhere the pattern exists, "not broken rn" included (`apt-get update` before every install step).
- All credentials of one integration are configurable the same way.
- A new scope, permission or capability lands on every surface at once: the scopes tuples (including legacy ones), the README list, the settings check, and a test. "Shouldn't this also be added to the list of permissions in `AUTO_REGISTRATION_MEETING_SCOPES` etc?"
- Every surface that shows a filtered number or list uses the filtered accessor.

## PR Description

- State the root cause for a fix and the use case for a feature. Behavior changes get a short Before/After.
- Claims come with proof: how it was tested, against which tenant, with a screenshot for UI. When upstream cannot reproduce, the first question is "I assume you tested again today? And there were actually registrations that the plugin synced?"
- No machine-flavored bullet lists ("Server-side rendering, CSP-safe", "No JavaScript framework dependency"); they get "I don't see how this is worth mentioning...". Every sentence carries information the reader needs.
- Cross-link companion core and plugin PRs; contrib CI builds against the core PR referenced in the body.
- Keep the description current when review changes the approach.
- Allow edits by maintainers on the PR; upstream rebases and adds the changelog entry on the branch and asks when it cannot.

## Changelog And Versioning

- Core: every PR adds a `CHANGES.rst` entry ("changelog entry please!" is a common approval message). User-visible changes under Improvements or Bugfixes, admin or developer facing changes under Internal Changes (a raised form limit is internal). New entries are appended at the end of the section, not inserted at the top ("new entries go there and not to the top"). A follow-up PR on the same feature adds its `:pr:` to the existing entry. Credit format: ``(:pr:`NNNN`, thanks :user:`login, org`)``. Entries are one short sentence wrapped at the file's width: "Log registration tag changes in the event log", not a restatement of the implementation.
- Plugins: every PR adds a bullet to the plugin README changelog under the upcoming version. Bullets move between version headings and `pyproject.toml` is bumped at release; a `-dev` suffix in a contrib plugin is "not strictly necessary since you should be building w/ a version suffix anyway".
- Plugin README title: "<Name> Plugin", no "Indico" prefix.

## Packaging And Repository Boilerplate

- `pytest.ini`, `pyproject.toml` (`exclude` list with its comments), license headers: copied from a sibling plugin verbatim, then adapted.
- No `MANIFEST.in` with hatchling.
- A new contrib plugin is added to the `.github/workflows/build.yml` matrix.
- No local-environment workarounds in upstream files (`--basetemp`, macOS path fixes); "AFAIK this can be set via an env var locally. I'd rather not have this upstream."
- Temporary compatibility shims carry an `XXX` with the upstream PR they wait for, and go when that PR is merged.

## Docs

- Sphinx roles over literals: ``:class:`~indico.core.plugins.IndicoPlugin` ``, ``:exc:`RuntimeError` ``.
- Examples use dummy names (`FooPlugin`, `PLUGIN_FOO_API_KEY`), not a real plugin.
- Docs describe where things live precisely ("on the plugin class", not "on the plugin instance" once the API moved).

## Commits And Branch Hygiene

- Core commits: capitalized plain imperative, no type prefix. Plugin repos: `Component: Sentence case`. Core and contrib squash; `indico-plugins` merges unsquashed, so each fixup subject must stand on its own.
- Rebase on conflicts, also mid-review: "Please fix the rebase conflicts (from merging #325)".
- Pull before pushing: reviewers push to contributor branches.
- Formatting is clean before review; otherwise a "Fix ruff formatting" commit lands on the branch.

## The Conversation

- Reply to each thread with the commit that addressed it and, when it is not self-evident, how it was verified.
- Disagree with reasoning and the real-world constraint, then let upstream decide; a documented tradeoff gets "Fine for now" and is remembered.
- When upstream reports it could not reproduce, debug in the thread and post the exact finding (the `type=3` meeting drops the field) rather than "works for me".
- When upstream posts a patch and says "it'd be good if you could also give it a try", apply it, test it and say so ("Tested on my end. All good.").
- Other contributors may test the branch and post fixes; incorporate them with credit in the thread and re-check the scenarios they hit.
- Close a PR yourself when the premise fails ("the audio type can be configured in the Zoom tenant settings, so exposing it per meeting makes no sense").
