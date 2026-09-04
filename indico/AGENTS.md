# Working Inside The Indico Codebase

This directory contains the upstream Indico codebase (https://github.com/indico/indico), mounted as a git submodule of the host repository. These instructions cover defaults for agents editing files under this directory.

## Submodule Discipline

- This directory is a git submodule. Commits made here do not appear in the host repository unless the host repository explicitly bumps the submodule pointer.
- Do not commit changes inside this directory without an explicit request. Most host-repository tasks should not touch upstream Indico code.
- When a change must live in Indico itself, treat it as an upstream contribution: follow upstream's CONTRIBUTING.md plus the Contributing Upstream section below.

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

## Contributing Upstream

Conventions for PRs against `indico/indico`, `indico/indico-plugins`, and `indico/indico-plugins-contrib`, learned from upstream review. They override the defaults in `CONVENTIONS.md` where they conflict.

### Commits And Titles

- Core commits use a capitalized plain imperative subject with no type prefix ("Add changelog entry"). Plugin repos prefix the component in sentence case ("VC/Zoom: Fix auto-checkin with multiple regforms").
- PR titles become merged commit subjects. Core and contrib squash-merge; `indico-plugins` merges branches unsquashed, so every fixup commit subject must stand on its own.
- A commit body is acceptable upstream when the subject cannot carry the rationale.

### Changelogs

- Every core PR adds a `CHANGES.rst` entry. User-visible changes go under Improvements or Bugfixes; admin- and developer-facing changes go under Internal Changes. Credit format: ``(:pr:`NNNN`, thanks :user:`username`)``.
- Every plugin PR adds a bullet to the plugin's `README.md` changelog section.

### Database Checklist

- A new relationship into a core model needs the backref plus an entry in that model's alphabetized backref comment list (`User` has one).
- A second FK to the same model needs `foreign_keys=` on the existing relationship.
- Columns get `#:` doc comments.
- Migration PRs carry the `alembic` label. Expect the revision to be rebased at merge time.

### Comments And Docstrings

- Core reviewers remove explanatory comments; the code must be self-evident. Sanctioned prose homes: signal docstrings (the full contract: sender, kwargs, return value, and how multiple listener returns combine), `#:` attribute docs, and the RST docs.
- The exception: why-comments about external-service quirks and non-obvious invariants. Those take as many lines as the invariant needs and survive review.

### Architecture Expectations

- Prefer the simplest native mechanism (a browser or framework built-in) over a custom layer.
- Shared endpoint behavior goes into an RH base class parameterized by class attributes, not duplicated per handler.
- Hoist guard conditions into early returns instead of nesting loops and conditionals.
- Do not mutate `field.data` inside a `validate_*` method; normalize in `process_formdata()` or `post_validate()`.
- Invalid configuration raises; it does not warn and continue.
- Never import plugin code while loading configuration; SQLAlchemy mappers are not set up yet.
- Reserve an explicit namespace for generated names instead of colliding with user-defined ones.
- Core additions need a core consumer. A hook or column used only by a plugin gets rejected until core itself uses it.
- No UI side effects (`flash()` and similar) in service or hook methods: they also run in non-interactive contexts such as event cloning. Log instead.

### Plugins

- Never monkeypatch or add attributes onto core classes from a plugin. Add a real model, a plain relationship, and helpers next to the model.
- Scope every endpoint to an event, category, or registration form. A global read leaks data across events.
- Expensive external-API sweeps run in a daily Celery task with a scoped cache (`make_scoped_cache`) and a per-item fallback, not per request, and not behind arbitrary size thresholds.
- A scope or capability addition lands on every surface at once: the scopes tuple, any legacy tuple, the README list, and a test.
- Copy plugin boilerplate (`pytest.ini`, packaging basics) verbatim from a sibling plugin. No local-environment workarounds in upstream files; keep those in `.envrc` or similar.
- Zoom: meetings and webinars are parallel API families. Check every change against both endpoints' documentation and never send a parameter the target endpoint does not document.
- JS labels use `Translate.string`. Jinja macro call arguments need `_()`; a `{% trans %}` block does not work there. Use the plugin's bound gettext.

### Testing Upstream

- Test files use the `*_test.py` suffix.
- Side-effect-only fixtures are applied with `@pytest.mark.usefixtures`, never as an unused argument.
- Shared setup becomes a factory fixture, not a module-level helper taking `db` and plugin arguments.
- Frontend changes ship jest specs in `client/js/**/__tests__/*.spec.js` with `it()` names that read as behavior sentences.
- New endpoints get an access-matrix test: each relevant role, including managers of unrelated events, asserted against the expected status code.

### Review Flow

- Gauge maintainer appetite before building anything significant: open an issue or ask first.
- Open as draft; ping the maintainer when ready for review.
- Maintainers push commits onto contributor branches. Pull before pushing more work.
- Resolve conflicts by rebasing, also while the PR is under review.
- When claiming something works, state how it was verified. UI claims come with a screenshot.
- Cross-link companion core and plugin PRs in both descriptions.
- Contrib CI picks the core branch to build against from the core PR referenced in the PR body; reference the core PR whenever the change depends on one.
- Stacked or cross-fork PRs state the target branch in the description. When the base lands, close and reopen the PR against upstream.
- Workflows on upstream repos cannot be rerun without admin rights; recover with a new commit or ask a maintainer.

## Documentation

- Upstream Indico documentation: https://docs.getindico.io/
- Development guide: `docs/source/installation/development.rst` inside this directory.
- For host-repository conventions (deployment, fixtures, branch policy, local commands), refer to the host repository's own instructions in the parent directory.
