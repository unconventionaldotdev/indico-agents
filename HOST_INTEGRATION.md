# Host Integration

Use this guide when adding this repository as a submodule to an Indico-based host repository.

## Add The Submodule

Choose a stable path under the host repository. The examples below use `agents/indico`.

```sh
git submodule add https://github.com/unconventionaldotdev/indico-agents agents/indico
git submodule update --init --recursive
```

Commit the submodule entry and `.gitmodules` in the host repository.

## Surface Shared Files At Host-Native Paths

Host repositories often want shared files to appear at host-native paths (e.g. root `AGENTS.md` or `docs/coding-guidelines.md`) so that contributors and tooling find them where expected. Use relative symlinks that point into the submodule.

### Manifest

Each host repository declares its desired symlinks in a `.agents-links` manifest at the host repository root.

```
# .agents-links
# <src under agents/indico/>   <dst under host repo root>   [mode]
AGENTS.md                       AGENTS.md
CODING_GUIDELINES.md            CODING_GUIDELINES.md
indico/AGENTS.md                indico/AGENTS.md
skills                          .claude/skills              contents
skills                          .codex/skills               contents
```

Lines starting with `#` and blank lines are ignored.

The optional third column selects the link mode:

- `file` (default): symlink the source path directly to the destination.
- `contents`: treat the source as a directory and create one symlink per immediate child inside the destination. Useful for installing the full skills catalog with a single manifest line, and for exposing the same catalog to multiple AI assistants (each one reads skills from its own path).

### Materialize The Symlinks

Run the bootstrap script shipped with this submodule from the host repository root:

```sh
bash agents/indico/scripts/install-links.sh
```

The script reads the manifest, creates each symlink with a path relative to its destination, and is idempotent. Commit the resulting symlinks together with the manifest:

```sh
git add .agents-links AGENTS.md CODING_GUIDELINES.md
git commit -m "chore: add shared indico agent guidance symlinks"
```

Symlinks are stored as blobs in git and resolve on every clone once `git submodule update --init` has been run. Contributors do not need to re-run the script unless the manifest changes.

### What To Symlink

Only files that read as generic guidance for host repositories:

- `AGENTS.md`
- `CODING_GUIDELINES.md`
- `indico/AGENTS.md`: surface inside a host repository's Indico submodule (e.g. at `indico/AGENTS.md`) so agents working in the Indico working tree pick it up.
- `skills` (contents mode): install the shared skill catalog under the assistant's skills directory. The destination depends on which assistants the host repository uses: `.claude/skills` for Claude Code, `.codex/skills` for OpenAI Codex, or both with two manifest lines. Each `SKILL.md` is a plain markdown file with YAML frontmatter and works with any assistant that follows the same convention.

Do not symlink `MAINTAINERS.md`, `HOST_INTEGRATION.md`, or `README.md`. They are repository-specific to `indico-agents` and should stay inside `agents/indico/`.

### Symlinks Inside Nested Submodules

When a destination in `.agents-links` lives inside another submodule (for example, the upstream Indico submodule at `indico/`), the bootstrap script adds the destination path to that nested submodule's local `.git/info/exclude`. This keeps the host-side symlink invisible to the nested submodule's `git status` without committing anything upstream.

The exclude entry is local to each clone, not tracked by either repository. Contributors run `bash agents/indico/scripts/install-links.sh` once after cloning to recreate it.

### Caveats

- Git symlinks require `core.symlinks=true` and developer mode on Windows. Host repositories with Windows contributors should fall back to the path-reference approach below.
- Renaming a file in this repository breaks downstream symlinks. Coordinate renames with host repositories or add a redirect note.
- The submodule must be initialized before symlinks resolve. Document `git submodule update --init --recursive` in host repository setup instructions.

## Reference Without Symlinks

Host repositories that cannot use symlinks (Windows-only contributors, policy constraints) can reference shared files by path instead. Add a short section to the host repository's `AGENTS.md`:

```md
## Shared Indico Agent Guidance

This repository imports shared Indico agent guidance at `agents/indico`.

Before editing Indico-related code, read:

- `agents/indico/AGENTS.md`
- `agents/indico/CODING_GUIDELINES.md`

Host repository instructions override shared guidance when they are more specific. Put product behavior, local commands, branch names, fixtures, deployments, and client-specific rules in this host repository.
```

Adjust the path if the submodule is mounted somewhere else.

## Precedence

Use this order when instructions conflict:

1. System, developer, and direct user instructions.
2. Host-owned instructions (deeper `AGENTS.md` files, `CLAUDE.md`, files under `.claude/`).
3. Shared guidance from this submodule (the host repository's root `AGENTS.md` may itself be a symlink to it).

The shared guidance should define reusable defaults only. Host repositories should define local behavior and client-specific constraints.

## Updating The Submodule

From the host repository, update intentionally and review the diff before committing.

```sh
git submodule update --remote agents/indico
git diff --submodule
```

Commit the submodule pointer change by staging the submodule path by name.

```sh
git add agents/indico
git commit -m "chore: update shared indico agent guidance"
```

## What To Keep Local

Keep these in the host repository, not in this shared submodule:

- Client names, private process, deployment details, and environment values.
- Host-specific test commands, branch policies, and release steps.
- Product behavior and domain decisions.
- Temporary migration notes or reviewer-only context.
