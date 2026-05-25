# indico-agents

Shared agent-facing guidance for Indico-related repositories.

This repository is intended to be imported as a git submodule by client or product repositories. It should contain
reusable guidance, skills, templates, and conventions that are useful across Indico-based work, without binding those
host repositories to one client, deployment, or private workflow.

## What Belongs Here

- Generic coding and testing guidelines for Indico-based projects.
- Reusable agent instructions that can be referenced from host repositories.
- Skills, checklists, prompts, or templates that apply across more than one project.
- Documentation that helps agents make consistent engineering decisions.

## What Does Not Belong Here

- Client-specific requirements, names, credentials, URLs, or deployment details.
- Instructions that apply to only one host repository.
- Secrets, environment values, tokens, or private operational notes.
- Project decisions that should live beside the application code they affect.

## Using As A Submodule

Add this repository as a submodule inside a host repository:

```sh
git submodule add https://github.com/unconventionaldotdev/indico-agents agents/indico
git submodule update --init --recursive
```

See [HOST_INTEGRATION.md](HOST_INTEGRATION.md) for the full integration model, including the symlink pattern for surfacing shared files at host-native paths.

## Documents

- `AGENTS.md`: Generic agent guidance for host repositories. Symlink or reference this from each host repository.
- `CODING_GUIDELINES.md`: Baseline coding, testing, style, git, and PR conventions for Indico-related work.
- `indico/AGENTS.md`: Guidance for agents editing files inside an Indico submodule mounted by a host repository.
- `skills/`: Reusable agent skills for working with Indico. Each subdirectory is one skill (`SKILL.md` plus optional helpers). Skills are plain markdown with YAML frontmatter and work with any AI assistant that follows that convention. Install into a host repository at the assistant's skills directory (e.g. `.claude/skills/` for Claude Code, `.codex/skills/` for Codex) using the manifest's `contents` mode.
- `MAINTAINERS.md`: Instructions for editing this repository.
- `HOST_INTEGRATION.md`: How to add this repository as a submodule and surface files at host-native paths.
- `scripts/install-links.sh`: Bootstrap script that materializes symlinks from a host repository's `.agents-links` manifest.

## Maintenance Principles

- Keep this repository generic by default.
- Put client-specific rules in the host repository.
- Prefer small, surgical edits over broad rewrites.
- Update shared guidance only when the rule should apply to multiple repositories.
