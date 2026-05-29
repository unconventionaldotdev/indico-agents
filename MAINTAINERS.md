# Maintainer Instructions

Instructions for editing this repository (`indico-agents`). For agent guidance consumed by host repositories, see [AGENTS.md](AGENTS.md).

## Project Files

- [README.md](README.md): Repository purpose, scope, and maintenance principles.
- [AGENTS.md](AGENTS.md): Generic agent guidance, symlinked or referenced from host repositories.
- [CODING_GUIDELINES.md](CODING_GUIDELINES.md): Shared coding, testing, style, git, and PR conventions.
- [HOST_INTEGRATION.md](HOST_INTEGRATION.md): Instructions for mounting this repository as a submodule and surfacing files at host-native paths.

## Scope

- This repository stores reusable agent-related material for Indico-based work.
- Keep every document generic enough to apply across multiple clients and host repositories.
- Do not add client-private details, credentials, environment values, deployment URLs, or one-off project workflows.
- If a rule only applies to one host repository, add it to that host repository instead.

## Skills

- Each subdirectory under `skills/` is one skill (`SKILL.md` plus optional helpers).
- When adding, removing, or renaming a skill, update the Available Skills index in [AGENTS.md](AGENTS.md) so it stays in sync.
- Keep per-skill trigger detail in its `SKILL.md`; the `AGENTS.md` index is a one-line pointer only.

## Before Changing Files

1. Read [README.md](README.md) and [CODING_GUIDELINES.md](CODING_GUIDELINES.md).
2. Inspect nearby documents before adding a new one.
3. Keep changes scoped to the requested guidance.
4. Preserve generic wording. Use terms like "host repository", "client project", and "Indico-based application".

## Documentation Style

- Write concise, direct, actionable guidance.
- Explain what to do and why it matters when the reason is not obvious.
- Avoid client names and project-specific examples unless they are placeholders.
- Use relative Markdown links for files in this repository.
- Keep documents ASCII unless a quoted source or code example requires otherwise.

## Git Workflow

- Stage files explicitly by name.
- Never use broad staging commands such as `git add -A`, `git add .`, or `git add -u`.
- Do not commit secrets, generated caches, local IDE metadata, or host repository artifacts.
- Use single-line commit messages in the form `type: imperative subject`.
- Never add `Co-Authored-By` trailers.

## Review Standard

Every changed line should trace back to the requested shared guidance. If a change would only benefit one downstream repository, leave it out and mention that it belongs in the host repository.
