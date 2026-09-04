# Agent Instructions

Shared baseline for agents working in Indico-based repositories. Repository-specific instructions in deeper or sibling files (such as `CLAUDE.md`, files under `.claude/`, or nested `AGENTS.md`) override these defaults.

## Scope

These instructions apply to Indico-based applications and the host repositories that build on them. They cover defaults that should hold across multiple clients and deployments. Host repositories define their own commands, fixtures, deployments, and product behavior on top of this baseline.

## Project Files

- `CONVENTIONS.md`: Shared coding, testing, style, git, and PR conventions.
- `indico/AGENTS.md`: Guidance for agents editing files inside an Indico submodule mounted by a host repository.
- `skills/`: Reusable agent skills for working with Indico. Each subdirectory is one skill.

## Before Changing Code

1. Read `CONVENTIONS.md` for the shared baseline.
2. Read host repository instructions (deeper `AGENTS.md` files, `CLAUDE.md`, or files under `.claude/`) for repository-specific rules.
3. Check the Available Skills below; prefer a matching skill over a manual approach.
4. Inspect nearby code before adding new files.
5. Keep changes surgical and scoped to the requested task.

## Available Skills

This repository ships skills under `skills/` (installed at `.agents/skills/`). Prefer them over ad-hoc implementations of the same task. Full triggers and steps live in each `SKILL.md`.

- `add-alembic-migration`: write an Alembic migration for an Indico model change
- `add-indico-rh`: add a request handler (endpoint) to an Indico module
- `bump-indico-submodule`: move the host's Indico submodule pointer forward
- `locate-in-indico`: find where code lives in the `indico/` tree before editing
- `write-indico-test`: write a pytest test for Indico code (test-first)

## Coding And Testing

- Follow `CONVENTIONS.md` for coding, testing, style, git, and PR conventions.
- Keep comments minimal: Indico favours self-evident code over explanation. Default to none and let clear names carry the meaning. Add one only for genuinely non-obvious rationale (the why, never the what). Most fit one short line; a why-comment about an external service's quirk or a fragile invariant may take the lines it needs. A comment that restates the method, signal, or test name is noise. Signal and public-API docstrings that document a contract are the exception and stay.
- Use test-first development for production code, scripts, and helpers.
- Prefer existing test patterns in the host repository over inventing new conventions.
- Do not mock framework internals, ORM sessions, queries, or model classes unless the host repository explicitly instructs otherwise.
- Use mocks only at external boundaries such as HTTP services, filesystem access, third-party SDKs, or process execution.

## Documentation Style

- Write concise, direct, actionable guidance.
- Explain what to do and why it matters when the reason is not obvious.
- Use relative Markdown links for files in the same directory.
- Keep documents ASCII unless a quoted source or code example requires otherwise.
- Do not add comments or prose that merely restates the heading.
- Recurring environment or tooling pitfalls belong in the host repository's own instructions (a Known Pitfalls section), next to the commands they affect, not in this shared baseline.

## Git Workflow

- Stage files explicitly by name.
- Never use broad staging commands such as `git add -A`, `git add .`, or `git add -u`.
- Do not commit secrets, generated caches, local IDE metadata, or build artifacts.
- Use single-line commit messages in the form `type: imperative subject`.
- Never add `Co-Authored-By` trailers.
- After merging another branch, run the full test suite before pushing. A local change to a shared attribute or helper can break code that only lives on the merged branch: green in git, red at runtime.

## Review Standard

Every changed line should trace back to the requested behavior. Avoid drive-by reformatting, renames, or refactors unrelated to the task. Iterating within a session often leaves formatting-only leftovers (a rewrapped line, a moved blank line) after you add and then remove code; revert them. Read your own diff before committing and drop every line that changed for formatting alone.

Correctness checks that repeatedly matter in review:

- **Honour feature gates on every surface.** When a setting or toggle enables a feature, each place that exposes it (a list, a dashboard, a search, a permission check) must test the same gate. One surface that skips the check leaks the feature while it is off. The same applies to declared requirements: a new scope, permission, or capability lands on every surface that lists or checks it (declaration tuples, docs, tests) in the same change.
- **Keep comments and docstrings truthful.** When behavior changes (a default flips, an attribute or helper is replaced), fix the prose that describes it in the same change. A stale comment is worse than none.
- **Remove what the change orphaned.** A removed or replaced call site leaves behind unused functions, imports, routes, templates, fixtures, and config keys. Grep every symbol you removed or stopped calling and delete or rewire the leftovers before finalizing.

## Onboarding A Host Repository

Initialize the submodule and install shared links once after cloning:

```sh
git submodule update --init --recursive

# Universal markdown files (AGENTS.md, CONVENTIONS.md, indico/AGENTS.md)
bash agents/indico/scripts/install-links.sh

# Also install shared skills into .agents/skills (read natively by Codex, Cursor, etc.)
bash agents/indico/scripts/install-links.sh --skills

# Claude users add the bridge (.claude -> .agents and CLAUDE.md symlinks)
bash agents/indico/scripts/install-links.sh --skills --claude
```

The universal symlinks are the same for every contributor and should be committed by the host repository. Skill symlinks are per-contributor (each teammate may use a different assistant) and should be ignored by the host repository's `.gitignore`.

See [HOST_INTEGRATION.md](HOST_INTEGRATION.md) for the full integration model.
