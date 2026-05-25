# Working Inside The Indico Codebase

This directory contains the upstream Indico codebase (https://github.com/indico/indico), mounted as a git submodule of the host repository. These instructions cover defaults for agents editing files under this directory.

## Submodule Discipline

- This directory is a git submodule. Commits made here do not appear in the host repository unless the host repository explicitly bumps the submodule pointer.
- Do not commit changes inside this directory without an explicit request. Most host-repository tasks should not touch upstream Indico code.
- When a change must live in Indico itself, treat it as an upstream contribution and follow the conventions documented at https://github.com/indico/indico.

## Architecture

- Indico is a Flask application with a SQLAlchemy backend and a mixed Jinja/React frontend.
- Each feature lives under `indico/modules/<name>/` and exposes routes through "request handler" (RH) classes registered in that module's blueprint.
- Plugins extend Indico via the entry-point system and hook into signals declared under `indico/core/signals/`.
- Background work runs through Celery. Scheduled jobs are declared per module.

## Locating Code

- Modules: `indico/modules/<name>/`. Look for `controllers/`, `models/`, `forms/`, `views/`, `client/`, `templates/`.
- Routes: each module's `blueprint.py` registers paths and RH classes.
- Signals: `indico/core/signals/` declares all signals. Search for `.connect_via(` to find consumers.
- Database models: each module's `models/` directory. Indico uses custom mixins under `indico/core/db/sqlalchemy/`.
- Templates: each module's `templates/` directory plus shared templates under `indico/web/templates/`.
- Frontend: each module's `client/` directory contains React components, Webpack entry points, and SCSS.

## Patterns

- **Request handlers (RH)**: subclass `RH` (or `RHProtected`, `RHEventBase`, ...). Implement `_process()` or `_process_GET()`/`_process_POST()`. Use `_check_access()` for permission checks.
- **Forms**: WTForms-based, declared in `forms/` per module. Use `IndicoForm` and Indico's custom fields.
- **Permissions**: ACL helpers under `indico/core/db/sqlalchemy/protection.py`. Decorate RH classes with the appropriate `Protection*` mixins or override `_check_access`.
- **i18n**: wrap user-facing strings in `_()` (gettext). Extract translations through Indico's standard tooling.
- **Signals**: declare in `indico/core/signals/<area>.py`. Plugins consume them through `signal.connect_via(...)`.

## Testing

- Indico tests run under `pytest`. Use the host repository's documented test command when available; otherwise run `pytest` from the Indico root with the host repository's environment.
- Use Indico's built-in fixtures (`dummy_user`, `dummy_event`, `dummy_category`, `db`, ...) instead of constructing models by hand. Look under `indico/testing/fixtures/` and module-local `testing/fixtures.py` files.
- Do not mock the database, SQLAlchemy sessions, queries, or ORM models. Use real fixtures.
- Mocks are acceptable at external boundaries: HTTP services, filesystem, third-party SDKs, email gateways, process execution.

## Style

- Indico has its own `pre-commit` configuration. Run `pre-commit run --files <changed-files>` before finalizing changes here.
- Follow surrounding code style. Indico predates several modern Python idioms in places; match the local file rather than introducing inconsistent modernization.
- Keep changes surgical. Do not reformat, rename, or refactor adjacent code unless required for the task.

## Documentation

- Upstream Indico documentation: https://docs.getindico.io/
- Development guide: `docs/source/installation/development.rst` inside this directory.
- For host-repository conventions (deployment, fixtures, branch policy, local commands), refer to the host repository's own instructions in the parent directory.
