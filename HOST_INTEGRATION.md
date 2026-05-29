# Host Integration

Use this guide when adding this repository as a submodule to an Indico-based host repository.

## Add The Submodule

Choose a stable path under the host repository. The examples below use `agents/indico`.

```sh
git submodule add https://github.com/unconventionaldotdev/indico-agents agents/indico
git submodule update --init --recursive
```

Commit the submodule entry and `.gitmodules` in the host repository.

## Install Shared Files Into The Host Repository

This repository ships a single bootstrap script that creates relative symlinks from the host repository into the submodule:

```sh
bash agents/indico/scripts/install-links.sh [--skills] [--claude]
```

The script's behavior is hardcoded, not driven by a manifest. It is idempotent: re-running it refreshes existing links.

### Universal Links (Always Installed)

Run the script without arguments to install the universal markdown files at host-native paths. These are the same for every host repository and should be committed.

```sh
bash agents/indico/scripts/install-links.sh
```

Resulting symlinks:

| Host path | Submodule target |
|---|---|
| `AGENTS.md` | `agents/indico/AGENTS.md` |
| `CODING_GUIDELINES.md` | `agents/indico/CODING_GUIDELINES.md` |
| `indico/AGENTS.md` | `agents/indico/indico/AGENTS.md` (only when an `indico/` directory exists at the host root) |

Commit `AGENTS.md` and `CODING_GUIDELINES.md` after the first run. The `indico/AGENTS.md` symlink lives inside the upstream Indico submodule and cannot be tracked by the host repository; the script appends it to the upstream submodule's local `.git/info/exclude` so it does not pollute that submodule's status. Each contributor must run the script once after cloning to recreate that local symlink.

### Skills (Shared, Cross-Agent)

The shared skill catalog under `agents/indico/skills/` installs into `.agents/skills/`, the cross-agent convention that Codex, Cursor, and other assistants read natively:

```sh
bash agents/indico/scripts/install-links.sh --skills
```

Each shared skill becomes a directory symlink:

```
.agents/skills/locate-in-indico   -> ../../agents/indico/skills/locate-in-indico
.agents/skills/write-indico-test  -> ../../agents/indico/skills/write-indico-test
...
```

### Claude Code Bridge

Claude Code does not read `.agents/` or `AGENTS.md`. It reads `.claude/` and `CLAUDE.md`. Add `--claude` to bridge both:

```sh
bash agents/indico/scripts/install-links.sh --skills --claude
```

This:

- Symlinks `.claude -> .agents`, so Claude finds the shared skills at `.claude/skills/`.
- Writes `CLAUDE.md` (and `indico/CLAUDE.md` when an `indico/` directory exists), each redirecting to its sibling `AGENTS.md` with a single `@AGENTS.md` import.

The `indico/CLAUDE.md` redirect lives inside the upstream Indico submodule, so the script adds it (alongside the `indico/AGENTS.md` symlink) to that submodule's local `.git/info/exclude`. Both stay invisible to the submodule's `git status` without committing anything upstream.

### Commit Or Ignore

The generated `CLAUDE.md` is a stable redirect, identical for every clone, and is committed alongside the root `AGENTS.md`. The per-contributor symlinks are not committed (teammates use different assistants). Add them to the host repository's `.gitignore`:

```
# .gitignore (host repository)
/.agents/skills/
/.claude
```

Contributors run the script once after cloning. A new skill added upstream (in this repository) becomes available to every contributor on the next run, without any host repository change.

### Symlinks Inside Nested Submodules

When a destination lives inside another submodule (for example, the upstream Indico submodule at `indico/`), the bootstrap script adds the destination path to that nested submodule's local `.git/info/exclude`. This keeps the host-side symlink invisible to the nested submodule's `git status` without committing anything upstream.

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
2. Host-owned instructions: nested `AGENTS.md` files the host repository authors beside its own code.
3. Shared guidance from this submodule. The host's root `AGENTS.md` symlinks to it; the generated root `CLAUDE.md` (`@AGENTS.md`) and the `.claude -> .agents` bridge both resolve back to it.

Root `AGENTS.md`, root `CLAUDE.md`, and `.claude/` all surface shared guidance, not host overrides. The generated `CLAUDE.md` is rewritten on each run, so host-owned behavior and client-specific constraints belong in nested `AGENTS.md` files, not appended to it.

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
