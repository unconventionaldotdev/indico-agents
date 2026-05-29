# Agent Instructions

Shared baseline for agents working in Indico-based repositories. Repository-specific instructions in deeper or sibling files (such as `CLAUDE.md`, files under `.claude/`, or nested `AGENTS.md`) override these defaults.

## Scope

These instructions apply to Indico-based applications and the host repositories that build on them. They cover defaults that should hold across multiple clients and deployments. Host repositories define their own commands, fixtures, deployments, and product behavior on top of this baseline.

## Project Files

- `CODING_GUIDELINES.md`: Shared coding, testing, style, git, and PR conventions.
- `indico/AGENTS.md`: Guidance for agents editing files inside an Indico submodule mounted by a host repository.
- `skills/`: Reusable agent skills for working with Indico. Each subdirectory is one skill.

## Before Changing Code

1. Read `CODING_GUIDELINES.md` for the shared baseline.
2. Read host repository instructions (deeper `AGENTS.md` files, `CLAUDE.md`, or files under `.claude/`) for repository-specific rules.
3. Inspect nearby code before adding new files.
4. Keep changes surgical and scoped to the requested task.

## Coding And Testing

- Follow `CODING_GUIDELINES.md` for coding, testing, style, git, and PR conventions.
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

## Git Workflow

- Stage files explicitly by name.
- Never use broad staging commands such as `git add -A`, `git add .`, or `git add -u`.
- Do not commit secrets, generated caches, local IDE metadata, or build artifacts.
- Use single-line commit messages in the form `type: imperative subject`.
- Never add `Co-Authored-By` trailers.

## Review Standard

Every changed line should trace back to the requested behavior. Avoid drive-by reformatting, renames, or refactors unrelated to the task.

## Onboarding A Host Repository

Initialize the submodule and install shared links once after cloning:

```sh
git submodule update --init --recursive

# Universal markdown files (AGENTS.md, CODING_GUIDELINES.md, indico/AGENTS.md)
bash agents/indico/scripts/install-links.sh

# Also install shared skills into .agents/skills (read natively by Codex, Cursor, etc.)
bash agents/indico/scripts/install-links.sh --skills

# Claude users add the bridge (.claude -> .agents and CLAUDE.md redirects)
bash agents/indico/scripts/install-links.sh --skills --claude
```

The universal symlinks are the same for every contributor and should be committed by the host repository. Skill symlinks are per-contributor (each teammate may use a different assistant) and should be ignored by the host repository's `.gitignore`.

See [HOST_INTEGRATION.md](HOST_INTEGRATION.md) for the full integration model.
