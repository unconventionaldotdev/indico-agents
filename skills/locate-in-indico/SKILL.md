---
name: locate-in-indico
description: Find code in the Indico codebase by feature, signal, route, model, form, or template. Use when an agent needs to identify where something lives in the `indico/` submodule before editing.
---

# locate-in-indico

Find code in Indico's large, modular codebase without grepping the world.

## When To Use

Before any edit under `indico/` when the relevant location is not already known.

## Mental Model

Indico organizes code by **module**. Each module owns its own controllers, models, forms, schemas, view layer, frontend assets, templates, and tests. Cross-cutting concerns live in core packages.

```
indico/
├── core/
│   ├── signals/            ← all signal declarations
│   ├── db/sqlalchemy/      ← SQLAlchemy base, mixins, custom types, protection
│   ├── plugins.py          ← plugin system
│   ├── celery.py           ← Celery app + scheduling
│   └── notifications.py    ← shared email infrastructure
├── modules/<area>/
│   ├── controllers/        ← Request Handler (RH) classes (one per concern)
│   ├── models/             ← SQLAlchemy models, query classes
│   ├── forms/              ← WTForms
│   ├── schemas/            ← Marshmallow schemas
│   ├── views.py            ← view-layer helpers (sidebar, breadcrumbs)
│   ├── client/             ← React components, Webpack entries, SCSS
│   ├── templates/          ← Jinja templates (incl. templates/emails/)
│   ├── testing/            ← module-local pytest fixtures
│   ├── notifications.py    ← email/notification senders
│   ├── util.py             ← module utilities
│   ├── tasks.py            ← Celery tasks
│   └── blueprint.py        ← URL routes + RH registration
├── web/
│   ├── flask/              ← Flask app factory, extensions
│   ├── forms/              ← shared form widgets
│   ├── views.py            ← shared view helpers
│   └── templates/          ← shared Jinja templates
└── testing/
    ├── fixtures/           ← global pytest fixtures
    └── util.py             ← test helpers
```

## Lookup Table

| Question | Where to look |
|---|---|
| Where does URL `/event/<id>/foo` route? | `git grep -nE "/event/.*foo" indico/modules/*/blueprint.py` |
| What signals fire on area X? | `indico/core/signals/<area>.py` (e.g. `event/registration.py`) |
| Where is feature X (registration, payment, abstracts, ...)? | `indico/modules/events/<feature>/` |
| What email is sent on Y? | `indico/modules/<area>/notifications.py` + `templates/emails/` |
| What model backs Z? | `indico/modules/<area>/models/` |
| How is permission P checked? | `indico/core/db/sqlalchemy/protection.py` + `_check_access` in module RH |
| Where is the React frontend for module M? | `indico/modules/M/client/` |
| How are background jobs scheduled? | `indico/core/celery.py` and module-local `tasks.py` |
| Where are global fixtures? | `indico/testing/fixtures/` |
| Where are module-local fixtures? | `indico/modules/<area>/testing/fixtures.py` (or `testing/`) |

## Signal Discovery

```sh
# Where is a signal declared?
git grep -nE "named_signal|signal *= *.*Signal" indico/core/signals/

# Who fires a signal?
git grep -nE "<signal_name>\.send" indico/

# Who consumes a signal?
git grep -nE "<signal_name>\.connect" indico/
```

## Route Discovery

```sh
# All blueprints
git grep -l "Blueprint(" indico/modules/*/blueprint.py

# Routes that match a pattern
git grep -nE "_bp\.add_url_rule.*<pattern>" indico/
```

## Model Discovery

```sh
# Find a model by class name
git grep -nE "^class <ModelName>\b" indico/modules/*/models/

# Find all models in an area
ls indico/modules/<area>/models/
```

## Cross-Reference With Skills

- New endpoint → `../add-indico-rh/SKILL.md`
- Database change → `../add-alembic-migration/SKILL.md`
- Test infrastructure → `../write-indico-test/SKILL.md`
- Submodule bump → `../bump-indico-submodule/SKILL.md`
