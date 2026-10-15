---
name: write-indico-pr
description: Write or revise a PR title and description for Indico core, official plugins, contrib plugins, or an Indico-based host repository. Use when preparing PR text from a branch, diff, or supplied change summary.
---

# write-indico-pr

Give reviewers the context they need in the fewest useful words. Match the target repository's conventions and scale
the description to the change; do not impose a fixed template.

## Establish The Change

- Identify the target repository and base branch. Read its applicable instructions and PR template.
- When working from a branch, inspect the full diff against the intended base, relevant commits, and any existing PR
  description. Do not describe only the latest commit or include unrelated working-tree changes.
- Establish what changed, why it matters, and any relevant conditions, defaults, compatibility constraints, or
  dependencies. Use issues and review discussions when available to recover missing rationale.
- Describe the final implementation. Replace stale scope or abandoned approaches in an existing description unless
  they explain a tradeoff that still matters.
- Drafting text does not imply creating a PR, editing one on GitHub, pushing commits, or contacting reviewers.

## Title

- Keep PR titles to at most 50 characters, including spaces and any component prefix.
- For `indico/indico`, default to a capitalized imperative with no Conventional Commit prefix or trailing period:
  `Fix registration filters for single choice fields`.
- For a change to one official plugin, commonly use its established component prefix followed by an imperative:
  `VC/Zoom: Drop support for JWT authentication`. Match nearby titles for the component's spelling.
- Contrib plugin changes can use the plugin name as a prefix, such as
  `affiliation_extras: Support contact email settings`. This is a useful convention, not a universal
  requirement. New plugins and repository-wide changes often need no component prefix.
- For host repositories, follow their own title conventions rather than importing upstream style automatically.
- Name the principal behavior or affected concept. Prefer `Add`, `Fix`, `Allow`, `Remove`, or another concrete verb over
  vague claims of improvement. Keep the title easy to scan.

## Description

Start with what changes and why. A small change usually needs one short paragraph; `This PR adds...` or
`This PR fixes...` is natural but optional. Supply information the title does not already convey.

- For a bug, explain the affected operation and triggering condition, then the cause and resulting behavior when
  known. Link the originating PR if it is a regression. Do not invent a root cause to fill out the description.
- For a feature, describe what users, administrators, or plugin developers can now do. Mention important defaults,
  permissions, fallback behavior, or limitations when they affect the result.
- Use bullets for several distinct behaviors and headings for substantial groups of information. Do not automatically
  add `Summary`, `Changes`, `Testing`, bold categories, or an `Alternatives considered` section.
- Explain meaningful tradeoffs or unresolved concerns plainly. Alternatives can be a sentence or paragraph; a section
  is useful only when the discussion warrants it.
- Include implementation details, identifiers, version requirements, examples, or benchmarks when they help explain
  the decision or verify the result. Avoid file-by-file narration and inventories of helpers, tests, or routine cleanup.
- For UI changes, include available screenshots or short recordings, with Before/After labels when helpful. If evidence
  is missing, flag that outside the proposed PR body rather than inventing an attachment or verification claim.
- Use `Closes #NNNN` for an issue actually resolved, and ordinary links for related work, regressions, and follow-ups.
  Use full URLs or `owner/repo#NNNN` across repositories. State companion dependencies explicitly, with reciprocal
  links when writing both descriptions. Contrib CI uses referenced core PRs to select its core branch, so include the
  core PR when the plugin depends on it.
- State a nonstandard target branch or stack relationship when needed to understand how the PR should land.
- Include focused reproduction or manual test steps when they help a reviewer assess behavior. Report checks or
  measurements only if they were actually performed; avoid routine CI status boilerplate.
- Remove the upstream template's submission checklist from the proposed body. Draft TODO lists are appropriate when
  the user wants to track unfinished work, but they are not a standard description section.

## Examples Of Upstream Style

These examples illustrate useful choices, not mandatory formats:

- [Core #7497](https://github.com/indico/indico/pull/7497): a one-sentence bug description names the affected permission,
  failed operation, and originating regression.
- [Core #7439](https://github.com/indico/indico/pull/7439): two behavior changes in bullets followed by Before/After images.
- [Core #6984](https://github.com/indico/indico/pull/6984): a rendering bug needs technical rationale and specific profiler
  instructions to make the fix verifiable.
- [Plugins #297](https://github.com/indico/indico-plugins/pull/297): a descriptive component-prefixed title and a single
  cross-repository dependency line are enough.

## Deliver

Return one recommended title and a body ready to paste. Keep missing evidence or questions outside that body. Before
delivering, check that every claim is supported, the title matches the final scope, and every paragraph helps review.
Empty descriptions occur upstream, but default to a short useful explanation rather than copying that habit.
