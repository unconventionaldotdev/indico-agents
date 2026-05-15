# Agent Instructions

Shared instructions for agents working in this repository or in a host repository that imports it as a submodule.

## Project Files

- [README.md](README.md): Repository purpose, scope, and maintenance principles.
- [CODING_GUIDELINES.md](CODING_GUIDELINES.md): Shared coding, testing, style, git, and PR conventions.
- [HOST_INTEGRATION.md](HOST_INTEGRATION.md): Instructions for adding this repository as a submodule and referencing it
  from host repositories.

## Scope

- This repository stores reusable agent-related material for Indico-based work.
- Keep every document generic enough to apply across multiple clients and host repositories.
- Do not add client-private details, credentials, environment values, deployment URLs, or one-off project workflows.
- If a rule only applies to one host repository, add it to that host repository instead.
- When this repository is used as a submodule, the host repository's own `AGENTS.md` overrides this file for local
  commands, branch names, fixtures, deployments, and product behavior.

## Before Changing Files

1. Read [README.md](README.md) and [CODING_GUIDELINES.md](CODING_GUIDELINES.md).
2. Inspect nearby documents before adding a new one.
3. Keep changes scoped to the requested guidance.
4. Preserve generic wording. Use terms like "host repository", "client project", and "Indico-based application".

## Coding And Testing

- Follow [CODING_GUIDELINES.md](CODING_GUIDELINES.md) for coding, testing, style, git, and PR conventions.
- Use test-first development for production code, examples that execute, scripts, and generated helpers.
- Prefer existing host repository test patterns over inventing new conventions.
- Do not mock framework internals, ORM sessions, queries, or model classes unless a host repository explicitly instructs
  otherwise.
- Use mocks only at external boundaries such as HTTP services, filesystem access, third-party SDKs, or process
  execution.

## Documentation Style

- Write concise, direct, actionable guidance.
- Explain what to do and why it matters when the reason is not obvious.
- Avoid client names and project-specific examples unless they are placeholders.
- Use relative Markdown links for files in this repository. Prefer `[CODING_GUIDELINES.md](CODING_GUIDELINES.md)` over
  bare filenames when pointing agents to related guidance.
- When host repositories reference these files, include the submodule path, such as
  `[CODING_GUIDELINES.md](agents/indico/CODING_GUIDELINES.md)`.
- Keep documents ASCII unless a quoted source or code example requires otherwise.
- Do not add comments or prose that merely restates the heading.

## Git Workflow

- Stage files explicitly by name.
- Never use broad staging commands such as `git add -A`, `git add .`, or `git add -u`.
- Do not commit secrets, generated caches, local IDE metadata, or host repository artifacts.
- Use single-line commit messages in the form `type: imperative subject` when committing from this repository.
- Never add `Co-Authored-By` trailers.

## Review Standard

Every changed line should trace back to the requested shared guidance. If a change would only benefit one downstream
repository, leave it out and mention that it belongs in the host repository.
