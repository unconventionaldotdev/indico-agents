---
name: review-indico-backend
description: Backend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers Python style, SQLAlchemy, WTForms, marshmallow, signals, request handlers, config, logging and security. Use through review-indico-pr or on its own for a Python-only change.
---

# review-indico-backend

Check the touched Python files and their callers against every item.

## Structure

- Early return over nested blocks; a guard comment explains a non-obvious sentinel (`is_enabled is None` for unflushed rows).
- Merge adjacent blocks with the same guard.
- Fail loudly instead of silently narrowing: abort when any requested id is not permitted.
- Filter where data is loaded (query criteria), not with a check afterwards; remove mechanisms the filter makes redundant.
- No single-use extraction; no abstraction "for later overrides".
- Unreadable nested comprehensions become a named helper.
- Functions that never touch `self` go to `util.py`.
- One definition point for shared infrastructure (one `cache` classproperty, one permission tuple constant, one `is_gravatar` enum property instead of repeated membership checks).
- Several handlers differing only in a parameter collapse into one with `any(...)`.
- Extend the existing mechanism before adding one (`PERMISSION` accepting a tuple instead of new mixins); `isinstance(x, (tuple, set, list))` for such checks.
- Module constants right after imports; single-use values inlined with a short comment.
- `cached_classproperty` when class-level access is enough.
- Plain defaults in the signature; `None` plus `if x is None` only for mutable defaults and translated strings.
- New boolean parameters are keyword-only (`*, flag=True`).
- One query for the set, then membership in Python; never a query per candidate inside a loop.
- Do not catch unexpected external errors just to log them; an uncaught exception is more informative and crashes nothing.
- Service code tolerates no request context (`session.user if session else None`).
- A changed signature lands on every override and subclass.
- Prefer an attribute or keyword with default over a new positional argument when plugins subclass the class.
- Index keys the code itself wrote (`data['body']`); `.get('x', [])` only for genuinely optional keys, never `.get('x') or []`.
- Walrus in comprehensions to avoid double getter calls.
- 120-character lines; no line breaks that fit on one line; long boolean expressions parenthesized, one operand per line, operator first.
- Do not re-implement framework behavior: `IndicoFlaskParser` already strips surrounding whitespace from request data.

## Naming And Comments

- Names replace comments (`_check_unique_title_in_section`); a comment restating the name is removed; copy-pasted comments are checked for drift.
- Private helpers `_`-prefixed; attributes follow the class convention (no lone `_attr` in a class with public attributes).
- Siblings share a scheme (`auto_register` / `auto_checkin`; `RegistrationCheckinPermission` / `RegistrationModerationPermission`); descriptions follow one template.
- Precise locals (`page_token`); never `i` for non-numeric loop variables; no underscored import aliases.
- Comments state facts that hold; limitations are verified; hardcoded lists cite their source (provider docs).
- `# XXX` for external quirks; a knowingly rough approach gets a one-line why-it-is-safe comment.
- Wording matches the module (the Zoom plugin says "Zoom meeting"); user-facing labels are plain words ("Short name / abbreviation", not "Code").
- Docstrings: Sphinx roles (`:class:`, `:exc:`, `:data:`), double-backtick literals.

## Imports

- All at top, grouped stdlib / third party / indico / plugin. Local import only to break a cycle.
- Long symbol lists become module imports (`from ...management import reglists`).

## Request Handlers And Access

- Override `_check_access` (super first) so errors name the right object; never `_check_management_permission` for object-level checks.
- Shared `PERMISSION` tuples live on an intermediate base class; subclasses never repeat an inherited `PERMISSION`.
- Every endpoint that lists, counts, exports or acts on the same objects applies the same filter and gate; feature-gated endpoints stay closed when the gate is off.
- Narrow permissions grant nothing beyond their purpose: logs, exports, configuration, legacy APIs stay with full management.
- Links embedding a capability (ticket link with registration token) are hidden from roles without it.
- Permission-based redirects happen inside the RH, not by rewriting menu targets.
- Schemas limit what is accepted and returned.
- Validation applies identically on every path (import modes, API, UI).

## Signals

- Narrowing signals mutate the passed list in place; `values_from_signal(skip_none=True)` already drops `None`.
- Docstrings state sender, kwargs, return and combination semantics.
- Signals live in their topic module (`signals/affiliations.py`), named like the existing family.
- Core hooks need a core consumer.
- Plugins register handlers with `self.connect(signal, handler, sender=...)` in `init()`, never module-level `connect_via`.

## Forms (WTForms)

- Dependent fields: `HiddenUnless('toggle', preserve_data=True)` plus `DataRequired` when empty makes no sense.
- Per-event behavior is an event or room field, not a global plugin setting.
- Multi-value errors name the offending items.
- `markupsafe.escape` on user strings inside `ValidationError`.
- Forms referencing external accounts must load when the account disappeared; failing to save is fine.
- Never mutate `field.data` in `validate_*`; normalize in `process_formdata` or `post_validate`.
- Field definitions sit with the other fields, one kwarg per line when long; drop descriptions that restate the label.
- Check rendered field order after overriding an inherited field.

## Schemas (marshmallow)

- `@validates_schema(skip_on_field_errors=True)`, written explicitly even though default.
- `ValidationError(_('msg'), 'field')`; named placeholders in multi-value strings.
- `data['x']` for fields with `load_default`.
- Backend regex validation mirrors the frontend one.

## SQLAlchemy And Migrations

- `contains_eager` after an explicit join; join via relationships (`.join(Model.rel)`), `.with_parent()` where it fits.
- Filter soft-deleted parents at every level, with a test per level.
- Query the subtype class (`RegistrationFormField`) for subtype-only constraints.
- New FK to `User`: backref, alphabetized backref list, `merge_users` handling.
- `#:` column docs. `alembic` label on the PR; revision rebased at merge (filename date, `down_revision`).
- `column_property` changes that back an index update the index in `upgrade` and `downgrade`; `indico db_diff` must be empty.
- Pick NULL or empty string, not both; NULL gets `CheckConstraint("col != ''")`.
- Encode invariants as CHECK constraints (e.g. `internal_name` required when `personal_data_type` is set) so edge cases such as cloning cannot produce bad rows.
- Partial-index `WHERE` clauses must be justified.
- Iterate enum members, never `range` over their values; SQL in triple-quoted strings indented under the call.
- Uniqueness scope matches the product: form or event level, never instance-wide constraints that collide on large installations.
- One query per bulk sync, not per item.

## Config And Startup

- Plugin keys under `PLUGIN_<NAME>_<KEY>`; collisions raise, never warn.
- No plugin imports while loading config (mappers not ready); defer to `IndicoPlugin.init()`, validate in `IndicoConfig.validate`.
- Config-provided credentials disable and mask the matching admin UI fields; all credentials of one integration configurable the same way; file-based secrets optional.
- Settings docs go in the matching section ("System", not "Development").

## Logging, Flashing, Errors

- No `flash()` in service methods or signal handlers (cloning, Celery). Log instead.
- Static variant in the format string (meeting vs webinar) for Sentry grouping, `%s` for data; `# noqa: G004` on static f-strings.
- Expected external rejections handled, not logged as warnings each run.
- Errors say how to fix; system-level errors (admin disabled a feature) need no i18n.
- Event log: module is the object ("Registration"), log only actual changes (compute added/removed before mutating).
- End-user warnings are one concrete sentence.

## External Services And Performance

- Check both members of parallel API families (meeting and webinar).
- Match external types exactly; normalize with a quirk comment.
- No O(n) external sweep per request: daily Celery task, scoped cache with TTL above the interval, per-item fallback.
- Common case first.
- Re-fetch after a PATCH when the provider drops values silently.

## Security

- Escape user strings in HTML messages; secrets from config never reach the browser.
- Plugin endpoints scoped to event, category or regform.
- Provider defaults verified (`approval_type`).
- Standard primitives for hardening: `hmac.compare_digest`, `secrets`; no signatures in logs.
- Signed file links via `File.signed_download_url` and `RHFileDownload`; check `UploadFileMixin` before writing an upload handler.

## Behavior Changes

- Changes to existing workflows are opt-in per form, off by default, or narrowed to the unambiguous case.
- Walk state machines with payment (approve, pay, change, approve again) before claiming correctness.
- Warn users before surprising consequences.
- Defaults only where they are what the user would choose.
- Keep source formats when converting data (PNG stays PNG).
- Every entry point building the same payload gets the behavior (user form, manager on-behalf, bulk).
