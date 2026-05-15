# Host Integration

Use this guide when adding this repository as a submodule to an Indico-based host repository.

## Add The Submodule

Choose a stable path under the host repository. The examples below use `agents/indico`.

```sh
git submodule add https://github.com/unconventionaldotdev/indico-agents agents/indico
git submodule update --init --recursive
```

Commit the submodule entry and `.gitmodules` in the host repository.

## Reference From Host AGENTS.md

Add a short section to the host repository's `AGENTS.md`.

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
2. Host repository `AGENTS.md` files, with deeper files winning over parent files.
3. Shared guidance from this submodule.

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
