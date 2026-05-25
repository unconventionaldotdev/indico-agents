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
bash agents/indico/scripts/install-links.sh [<skills-target-dir>]
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

### Skill Links (Per-Contributor, Per-Assistant)

Different contributors may use different AI assistants. The shared skill catalog under `agents/indico/skills/` is therefore installed per-contributor, into the path that the contributor's assistant looks at.

Pass the assistant-specific skills directory as the first argument:

```sh
bash agents/indico/scripts/install-links.sh .claude/skills    # Claude Code
bash agents/indico/scripts/install-links.sh .codex/skills     # OpenAI Codex
bash agents/indico/scripts/install-links.sh .cursor/skills    # Cursor
```

Each shared skill becomes a directory symlink under the chosen path. For example, with `.claude/skills`:

```
.claude/skills/locate-in-indico       -> ../../agents/indico/skills/locate-in-indico
.claude/skills/write-indico-test      -> ../../agents/indico/skills/write-indico-test
...
```

Add the chosen skills directories to the host repository's `.gitignore` so each contributor's choice stays local:

```
# .gitignore (host repository)
/.claude/skills/
/.codex/skills/
/.cursor/skills/
```

Contributors run the script once after cloning. Adding a new skill upstream (in this repository) becomes available to every contributor on the next run, without any host repository change.

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
