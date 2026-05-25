---
name: add-alembic-migration
description: Generate and write an Alembic migration with Indico's conventions (custom types, indexes, FK cascade, downgrade). Use whenever a SQLAlchemy model change requires a schema change in Indico.
---

# add-alembic-migration

Generate a safe Alembic migration with Indico's conventions. Includes downgrade, custom types, and a pre-merge safety checklist.

## When To Use

Any time a SQLAlchemy model added, removed, or modified under `indico/modules/<area>/models/` changes the database schema. Pure Python-only changes do not need a migration.

## Where Migrations Live

```
indico/migrations/
├── env.py
├── versions/
│   └── <revision_id>_<short_slug>.py
```

## Generate

```sh
indico db migrate -m "Short imperative summary"
```

This calls Alembic's `revision --autogenerate` against the current model snapshot. Review the generated file carefully; autogeneration misses:

- Custom types (re-declare them in the migration).
- Conditional changes (e.g. backfill before constraint).
- Index renames (autogen sees drop+create, sometimes mis-orders).
- Server defaults.

## File Structure

```python
"""Add approval timestamp to registrations

Revision ID: 7f9e3a1b2c4d
Revises: a1b2c3d4e5f6
Create Date: 2026-05-25 14:30:00.000000
"""

from alembic import op
import sqlalchemy as sa

from indico.core.db.sqlalchemy import UTCDateTime, PyIntEnum


revision = '7f9e3a1b2c4d'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'registrations',
        sa.Column('approved_dt', UTCDateTime, nullable=True),
        schema='event_registration',
    )


def downgrade():
    op.drop_column('registrations', 'approved_dt', schema='event_registration')
```

## Indico Conventions

### Schemas

Most modules live in a Postgres schema, not `public`. Pass `schema='<schema>'` to every `op.<op>`. Find the schema in the model:

```python
class Registration(db.Model):
    __tablename__ = 'registrations'
    __table_args__ = {'schema': 'event_registration'}
```

### Custom Column Types

| Indico type | Postgres backing |
|---|---|
| `UTCDateTime` | `TIMESTAMP WITH TIME ZONE` |
| `PyIntEnum(<Enum>)` | `INTEGER` with check constraint |
| `JSONB` | re-export of `sa.dialects.postgresql.JSONB` |
| `UUID` | `UUID` |
| `IndicoProtectionMode` | `INTEGER` with protection constraint |

Import from `indico.core.db.sqlalchemy`. Never use `sa.DateTime` for timestamps; Indico requires timezone-aware columns.

### Foreign Keys

```python
sa.ForeignKey('users.users.id', name='fk_registrations_user_id'),
```

- Reference the target schema: `<schema>.<table>.<column>`.
- Name constraints explicitly (`fk_<table>_<column>`); autogen sometimes drops names.
- Use `ondelete='SET NULL'` or `'CASCADE'` deliberately; default is no action.

### Indexes

```python
op.create_index(
    'ix_registrations_event_id',
    'registrations',
    ['event_id'],
    schema='event_registration',
)
```

Always provide a name. Concurrent index creation requires running outside a transaction; if the table is large, see "Online DDL" below.

## Safety Checklist (Pre-Merge)

Before approving a migration, verify:

1. **Downgrade is symmetric**: every `upgrade()` op has an inverse in `downgrade()`. Test by running `indico db downgrade -1 && indico db upgrade head` on a populated DB.
2. **No `NOT NULL` on existing rows without a backfill**: adding `nullable=False` to a column on a non-empty table fails. Pattern:
   - Add column nullable.
   - Backfill via `op.execute("UPDATE ...")` or a Python helper.
   - Alter to `nullable=False`.
3. **No long lock on large tables**: `ALTER TABLE ... ADD COLUMN` with a default rewrites the whole table in older Postgres. Add column nullable, then update default in a separate step.
4. **Indexes on hot tables**: use `op.execute("CREATE INDEX CONCURRENTLY ...")` outside the transaction. Mark the migration `transactional_ddl = False` if needed.
5. **Enum changes**: removing/renaming Postgres enum values requires manual SQL. Autogen does not handle this.
6. **`down_revision` is correct**: should be the previous `head` at the time you generate.
7. **Schema is set**: every `op.*` call has `schema='<schema>'` when the model uses one.
8. **No data loss in downgrade**: if `downgrade()` drops a column with data, document the loss in the docstring.

## Online DDL Pattern

```python
def upgrade():
    # Step 1: add column, nullable, no default
    op.add_column('registrations',
                  sa.Column('approved_dt', UTCDateTime, nullable=True),
                  schema='event_registration')
    # Step 2: backfill from existing state
    op.execute("""
        UPDATE event_registration.registrations
        SET approved_dt = state_changes->-1->>'timestamp'::timestamptz
        WHERE state = <approved-int>
    """)
    # Step 3: optionally tighten to NOT NULL in a separate migration
```

Splitting into multiple migrations is acceptable when locks are a concern.

## Testing A Migration

```sh
# Run forward and backward to validate symmetry
indico db upgrade head
indico db downgrade -1
indico db upgrade head

# Verify on a populated test DB
pytest indico/modules/<area>/  # tests should still pass
```

## Cross-Reference With Skills

- Locate the model file → `../locate-in-indico/SKILL.md`
- Write tests against the new schema → `../write-indico-test/SKILL.md`
- Bumping the Indico submodule in a host repo → `../bump-indico-submodule/SKILL.md`
