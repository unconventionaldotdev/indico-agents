# Agent Instructions

Shared baseline for agents working in Indico-based repositories. Repository-specific instructions in deeper or sibling files (such as `CLAUDE.md`, files under `.claude/`, or nested `AGENTS.md`) override these defaults.

## Scope

These instructions apply to Indico-based applications and the host repositories that build on them. They cover defaults that should hold across multiple clients and deployments. Host repositories define their own commands, fixtures, deployments, and product behavior on top of this baseline.

## Project Files

- `CODING_GUIDELINES.md`: Shared coding, testing, style, git, and PR conventions.
- `indico/AGENTS.md`: Guidance for agents editing files inside an Indico submodule mounted by a host repository.

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

If a host repository references this file from a submodule path (e.g. `agents/indico/AGENTS.md`), the submodule must be initialized first:

```sh
git submodule update --init --recursive
```

If the host repository uses the symlink pattern (i.e. files at host-native paths point into the submodule), the symlinks resolve automatically once the submodule is initialized. When a `.agents-links` manifest exists at the host repository root but the expected symlinks are missing or broken, run:

```sh
bash agents/indico/scripts/install-links.sh
```

See [HOST_INTEGRATION.md](HOST_INTEGRATION.md) for the full integration model, including manifest format and caveats.
