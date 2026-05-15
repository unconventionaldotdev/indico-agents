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

Add this repository as a submodule inside a host repository, then reference the shared documents from that host
repository's `AGENTS.md`.

```sh
git submodule add https://github.com/unconventionaldotdev/indico-agents agents/indico
```

Recommended host guidance:

```md
Read `agents/indico/AGENTS.md` and `agents/indico/CODING_GUIDELINES.md` before editing code. Host repository
instructions override shared guidance when they are more specific.
```

## Documents

- `AGENTS.md`: Shared instructions for agents working in this repository or consuming it as a submodule.
- `CODING_GUIDELINES.md`: Baseline coding, testing, style, git, and PR conventions for Indico-related work.

## Maintenance Principles

- Keep this repository generic by default.
- Put client-specific rules in the host repository.
- Prefer small, surgical edits over broad rewrites.
- Update shared guidance only when the rule should apply to multiple repositories.
