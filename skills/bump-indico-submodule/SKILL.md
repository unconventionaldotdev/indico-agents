---
name: bump-indico-submodule
description: Bump the upstream Indico submodule pointer in a host repository with a review of migrations, signals, deprecations, and frontend bundles. Use when updating to a newer Indico release or commit.
---

# bump-indico-submodule

Move the host repository's Indico submodule pointer forward. Surface the diff that matters before committing.

## When To Use

Whenever the host repository needs a newer Indico (security fix, new feature, dependency upgrade, periodic refresh).

## Fetch And Inspect

```sh
# From the host repository root
git submodule update --remote indico
cd indico
git log --oneline <old_sha>..HEAD
```

This lists every upstream commit between the previous pin and the new tip. Skim each subject line; flag anything that touches:

- `migrations/versions/` (schema change)
- `core/signals/` (new or modified signal)
- `core/db/` (custom type, mixin, or protection change)
- `web/flask/` (app factory, extensions)
- `client/` and `package.json` (frontend bundle, new dependency)
- `setup.cfg`, `pyproject.toml`, `requirements*.txt` (Python deps)
- `CHANGES.rst` (upstream's own changelog)

## Targeted Diff

For each area flagged above:

```sh
# Migrations between old and new pin
git -C indico diff --name-only <old_sha>..HEAD -- migrations/versions/

# Signal changes
git -C indico diff <old_sha>..HEAD -- core/signals/

# Frontend dependency drift
git -C indico diff <old_sha>..HEAD -- package.json

# Upstream changelog
git -C indico show HEAD:CHANGES.rst | head -60
```

## Validate The Bump

Before committing the pointer change, run host-repository checks:

1. **Apply migrations**: `indico db upgrade head`. Inspect plan with `indico db --sql upgrade <old_sha>:head` if the host has a production-like DB.
2. **Run host test suite**: the host's own tests catch local regressions from API changes.
3. **Run a smoke of Indico's tests** in the host environment if the diff touched core areas.
4. **Frontend rebuild**: if `package.json` changed, run the host's build target. Check bundle size delta.
5. **Plugin compatibility**: if the host depends on plugins from `indico-plugins` or `indico-plugins-contrib`, bump them in step. Mismatched versions break signal contracts.

## Commit The Bump

Stage `indico` (and any plugin submodules bumped together) by name:

```sh
git add indico plugins/indico-plugins plugins/indico-plugins-contrib
git commit -m "chore: bump indico submodule to <short_sha>"
```

The commit message should name the target commit or release tag. Host-repository review needs to see what landed without re-running the same diff.

## When To Hold Off

- The upstream diff contains breaking changes the host has not migrated through yet.
- A new migration requires a backfill the host environment cannot run safely during the bump window.
- A frontend bundle change conflicts with host overrides.
- Plugin submodules have not been bumped to compatible versions.

In any of these cases, file the bump in a feature branch with explicit notes and coordinate with the host team before merging.

## PR Description Template

Use big-picture-only style. List what changed at the upstream level, not file by file.

```md
Bump the `indico` submodule from `<old_sha>` to `<new_sha>`.

Upstream changes worth noting:
- <signal change>
- <migration summary>
- <breaking deprecation>

Host-repository impact:
- <local code adjustments>
- <plugin bumps>

How to test:
- `indico db upgrade head` on a populated test DB
- `<host test command>`
```

## Cross-Reference With Skills

- Inspect migrations introduced by the bump → `../add-alembic-migration/SKILL.md`
- Locate signals or modules touched by the bump → `../locate-in-indico/SKILL.md`
- Re-run / add tests around changed behavior → `../write-indico-test/SKILL.md`
