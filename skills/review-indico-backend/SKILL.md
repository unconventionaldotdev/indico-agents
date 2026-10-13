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
- Unreadable nested comprehensions become a named helper; a loop that only appends becomes a comprehension (walrus for the filtered value), never `# noqa: PERF401`.
- `@dataclass(frozen=True)` over `namedtuple`; plain defaults (`name: str = ''`, no `field()`), required attribute first so callers never pass `None, None`.
- Deduplicate by key with a dict (`{r.email: r}`), not by hashing dataclasses; test the overlap case (same email from two sources).
- Expensive work inside a send loop (template module, agenda query) is computed once or memoized with `memoize_request`.
- Early return for the short branch, then flat code for the main one; a two-branch assignment is a ternary.
- Truthiness checks (`if tags:`), never `len(x) > 0`; `not all(...)` over `any(not ...)`.
- `match` over if/elif chains on enums, with `case _: assert False` for the impossible branch.
- Use the existing abstraction (`obj.protection_parent`) instead of `getattr` chains over known parent attributes.
- Behavior of enum options is documented on the enum (`__titles__`, docstring), not in a settings dict comment.
- Short names everywhere (`all_tags`, not `all_tags_must_be_present`); `tpl` for template variables.
- New public symbols are re-exported in the module `__init__` and listed in `__all__`.
- Enums are `IndicoIntEnum` / `IndicoEnum`, never bare `(int, Enum)`.
- Remove methods and imports a refactor left unused.
- Functions that never touch `self` go to `util.py`.
- One definition point for shared infrastructure (one `cache` classproperty, one permission tuple constant, one `is_gravatar` enum property instead of repeated membership checks).
- Several handlers differing only in a parameter collapse into one with `any(...)`.
- Extend the existing mechanism before adding one (`PERMISSION` accepting a tuple instead of new mixins); `isinstance(x, (tuple, set, list))` for such checks.
- Module constants right after imports (or on the API client class), never inside the plugin class; single-use values inlined with a short comment.
- `cached_classproperty` when class-level access is enough.
- Plain defaults in the signature; `None` plus `if x is None` only for mutable defaults and translated strings.
- New optional parameters are keyword-only (`*, flag=True`); check no caller passes the neighbours positionally and make those keyword-only too.
- Argument order: the object acted on first (`add_users_to_group(group, users)`), then the rest.
- Helpers do their own difference (`users - group.members`) so callers cannot misuse them; the name must not promise more than the body does.
- State changes that must be logged go through explicit operations (`grant_admin(user)`, `revoke_admin(user)` in `operations.py`), never through property setters; manual and automated changes log separately.
- Operations take `*, extra_log_data=None` and merge with `{**log_data, **(extra_log_data or {})}` or `dict(extra_log_data or {})`; never mutate the caller's dict.
- CLI command names are set in the decorator (`@cli.command('create')`) when the function must be renamed.
- No guard for values no caller passes (`if not fmt: return None` with no falsy caller).
- Parenthesize `or` chains inside a walrus.
- Reuse the local already computed (`user.email`, not `session.user.email` after `user = session.user`).
- Previews use a lightweight mock object (`MockX(regform, first_name, last_name)`), not an unsaved model plus `self.commit = False`.
- Parsing (CSV sniffing, delimiters) stays server-side; `csv.Sniffer()` over the first lines, empty input returns `[]`, failure raises `UserValueError`.
- Do not store uploads that are consumed immediately; process the stream and return the data instead of `UploadFileMixin` plus state kept in `validate_file`.
- Exercise every caller of a changed shared util (exports from other modules, objects without an ACL) before merging.
- One query for the set, then membership in Python; never a query per candidate inside a loop.
- Do not catch unexpected external errors just to log them; an uncaught exception is more informative and crashes nothing. Catch only the client's exception class (`HTTPError`, `StorageError`), never bare `Exception`; wrap only the call that can raise, not the surrounding block.
- `assert` for states that must never happen (template missing `<body>`), not a warning log.
- `match` with class and sequence patterns for type dispatch over `isinstance` chains.
- Walrus in guards: `if not (x := get()): return`; `if missing := compute(): raise`.
- Boolean names for booleans (`got_access_token`, not `access_token` when only truthiness matters).
- Declare variables where they are used, not at the top of the function.
- Return richer data through a kwarg (`full=True`) instead of reading a side effect (a cache) back.
- Derive capability from the data (stored attachments count equals attachments count) rather than from a config flag; do not block actions on a flag that only gates creation when the data already exists.
- Display logic belongs in the template, not in the renderer or RH.
- Service code tolerates no request context (`session.user if session else None`); test the Celery path, not only "send now".
- Previews use the current user's name and email as sample data, not `<FIRST-NAME>` markers; webargs `location` is omitted when it is the form/json default.
- Custom emails render through `emails/custom.html`; plain-text alternatives via `html_to_markdown(..., inline_links=False)`.
- Upstream prefers text/plain emails; HTML only as multipart with a separate text template. `EmailMultiAlternatives` is safe for plain emails too.
- Keys added to queued payloads (email dicts) are read with `.get()` in the consumer: messages enqueued before the upgrade lack them. Keep related kwargs together (`connection=` last).
- A changed signature lands on every override and subclass.
- Prefer an attribute or keyword with default over a new positional argument when plugins subclass the class.
- Index keys the code itself wrote (`data['body']`, `email['cc']`); `.get('x', [])` only for genuinely optional keys, never `.get('x') or []`.
- Walrus in comprehensions and guards to avoid repeated getter calls (`if flag and (items := data['items']):`).
- Method chains break with the `.` at the start of the continuation line.
- `Model.query` over `db.session.query(Model)`; `query.has_rows()` over `count().scalar()`.
- `html_to_markdown(text, inline_links=False).strip()` for HTML to plain text, not `strip_tags`.
- Inserted content goes inside `<body>`, with a separator (`<hr>`, `-------------`) between preface and original.
- Stored records keep what is needed to recover later (filename, content type) and nothing more; key names follow existing Indico names (`storage_backend`, `storage_file_id`).
- Deduplicate within a request through `flask.g`; unique file names use a uuid, not a content hash (same content saved twice must not fail).
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
- New helper endpoints start admin-only; loosen later when another consumer appears.
- Object lookup in `_process_args` via `@use_kwargs({'obj': ModelField(Model, filter_deleted=True, required=True, data_key='obj_id')}, location='view_args')` with the kwarg named explicitly (never `**kwargs`), also instead of `Model.get(request.view_args[...])`; always call the base `_process_args` even when it is a no-op.
- Base methods are called explicitly (`RHBase._process_args(self)`), never through `super()`; no `__init__` on RHs, attributes are set in `_process_args`. Admin-only overrides of `_check_access` call the base first, then `raise Forbidden`.
- Parallel families (file/picture upload, display/management) share the same base RH data (`self.field`); the public variant mirrors the management one with `normalize_url_spec` and `skipped_args`.
- Child objects are loaded through the parent (`Model.query.with_parent(self.event).filter_by(id=...).first_or_404()`), one chained call per line; the model gets a `locator_property` including the parent id (on the concrete subclass when the base lacks it) and the RH declares `normalize_url_spec = {'locators': {lambda self: self.entry}}`.
- `BadRequest` for a wrong object type or state, `Forbidden` only for permission failures; the server rejects what the UI disables (attachments present, still pending).
- Keys from client-controlled or externally stored data are read with `.get()` so bad input fails with a validation error, not a `KeyError`.
- The response to a mutation carries everything the UI must refresh (`has_pending_invitations`), not only the list.
- "All" is the absence of the key or `None`, never an empty list.
- A mode with its own filtering (linkable bookings) gets its own endpoint with bounded ints (`fields.Int(validate=validate.Range(min=0), load_default=0)`), not extra optional args on a paginated one; the server filters out what the user cannot act on, the client renders everything it receives.
- Query criteria are built per branch as full expressions (`(A > x) & (B <= y)`), never by mutating `criteria[0]` with `db.and_`. Prefer inclusive comparisons over client-side offset hacks unless pagination needs them.
- Schemas, args and selectors made obsolete by the final design are removed in the same PR.
- RH docstrings describe what the handler does now, not the earlier design.
- `@use_args(Schema)` with a positional `data` when the dict is passed on; `@use_kwargs` only when fields are consumed individually.
- Admin-level changes are logged with `AppLogEntry.log()`; models get a `log()` method that prefills `meta`.
- Signals receive the parsed `data`, not `request.json`; an empty payload after plugins ran is a no-op, not `BadRequest`.
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
- No `Optional()` when it is the only validator.
- Uniqueness checks scope to enabled items and run again on re-enable; case-insensitive via `db.func.lower`.
- Per-event behavior is an event or room field, not a global plugin setting.
- Multi-value errors name the offending items.
- `markupsafe.escape` on user strings inside `ValidationError`.
- Forms referencing external accounts must load when the account disappeared; failing to save is fine.
- Never mutate `field.data` in `validate_*`; normalize in `process_formdata` or `post_validate`.
- Field definitions sit with the other fields, one kwarg per line when long; drop descriptions that restate the label.
- Values the client never changes are form constructor kwargs (`def __init__(self, *args, event, mode, **kwargs)`), not hidden fields round-tripped through the browser.
- Relationships are edited through query fields (`IndicoQuerySelectMultipleCheckboxField`, `IndicoQuerySelectMultipleTagField`) so `populate_obj` assigns them; no id lists resolved by hand in the RH. Relationships already exclude soft-deleted rows; sort with `natural_sort_key`.
- "Nothing selected means no restriction" is stated in the description; labels stay short enough not to wrap ("Filter by forms").
- Rich-text fields that end up in emails: `[NoRelativeURLs()]` plus `TinyMCEWidget(absolute_urls=True, height=300)`.
- Widgets that hide or show other fields (`HiddenUnless`) need the underlying input in the widget HTML, not rendered by React: `initForms` runs before the script.
- Never append to `field.validators` or change `field.flags` in `__init__` (leaks into every instance); use `inject_validators` or `del self.field`.
- Subjects and other non-HTML strings get no `strip_tags`; escape where they are rendered.
- Check rendered field order after overriding an inherited field.

## Schemas (marshmallow)

- `@validates_schema(skip_on_field_errors=True)`, written explicitly even though default.
- `ValidationError(_('msg'), 'field')`; named placeholders in multi-value strings.
- `data['x']` for fields with `load_default`.
- Free-form metadata is `fields.Dict(keys=fields.Str())`; `null` rejected, empty is `{}`.
- `load_default=lambda: []` for mutable defaults; `@pre_load` hooks copy `data` before popping keys.
- Backend regex validation mirrors the frontend one.

## SQLAlchemy And Migrations

- `contains_eager` after an explicit join; join via relationships (`.join(Model.rel)`), `.with_parent()` where it fits.
- Filter soft-deleted parents at every level, with a test per level.
- Query the subtype class (`RegistrationFormField`) for subtype-only constraints.
- New FK to `User`: backref, alphabetized backref list, `merge_users` handling.
- `#:` column docs; keep the blank line between columns and relationships. `down_revision` points at the current head when the PR is opened and again before merge. `alembic` label on the PR; revision rebased at merge (filename date, `down_revision`); `op.add_column` calls fit on one line when under 120 characters.
- `column_property` changes that back an index update the index in `upgrade` and `downgrade`; `indico db_diff` must be empty.
- Pick NULL or empty string, not both; NULL gets `CheckConstraint("col != ''")`.
- Association tables declare `ondelete='CASCADE'` on both foreign keys; the closing parenthesis of `op.create_table` sits on the last argument line.
- `index=True` on the column instead of separate `op.create_index`; `downgrade` does not drop indexes of a table it drops. Enum copies inside migrations match the model enum member for member. Constraints exist in both migration and model, or in neither (drop a uniqueness check when duplicates are harmless). Blank line after the title in the revision docstring.
- Search over text columns: prefix match over substring, skip words under 3 chars, GIN/FTS index in the migration, results cached with `memoize_redis(ttl, versioned=True)` and the version bumped on writes.
- New relationships on a cloned model update its `EventCloner` (`uses`, mapping through `shared_data`, skip when the dependency was not cloned).
- Switching stored text from plain to HTML uses `RenderModeMixin` with a `render_mode` column (legacy rows stay plain text, new rows HTML), never a destructive data migration.
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
- Log-type or derived data gets its own storage setting (default `None`), never `ATTACHMENT_STORAGE`, which holds long-term user content.

## Logging, Flashing, Errors

- No `flash()` in service methods or signal handlers (cloning, Celery). Log instead.
- Static variant in the format string (meeting vs webinar) for Sentry grouping, `%s` for data; `# noqa: G004` on static f-strings.
- Expected external rejections handled, not logged as warnings each run.
- Errors say how to fix; system-level errors (admin disabled a feature) need no i18n. "not allowed" over "not valid"; proofread grammar ("are entered").
- Event log: module is the object ("Registration"), log only actual changes (compute added/removed before mutating).
- Log summaries are short ("Added to group {name}"); ids go in `meta` for filtering, not in the text; no extra `meta` keys that break existing filters.
- Log `data` stores useful detail (attachment filenames), not a bare count; key names say what they hold. `data` keys are human-friendly (`'User ID'`); keys without a value (`IP` outside a request) are omitted, not set to `None`.
- Email log records `alternatives` so re-sending reproduces the original multipart message.
- Settings pages log changes: `changes = {k: (old[k], v) for k, v in form.data.items() if old[k] != v}`, then `AppLogEntry.log(..., data={'Changes': make_diff_log(changes, log_fields)})`; summary names the single changed field or says "Data updated". Extend `make_diff_log` when a new value type appears.
- Global logging goes through `AppLogEntry.log()` (static, mirrors `Event.log`); nothing is monkeypatched onto `app`.
- Generic logging hooks honor `quiet=True` and the object's `logging_disabled` state (event creation, cloning); implicit side effects (submitter rights on speakers) are logged quietly or not at all.
- Code reachable from the CLI uses `session.user if session else None`; test with the `indico` CLI, where no request context exists.
- Two values are two `data` keys, never squeezed into one key; hierarchical titles use a shared helper and separator. A new log realm gets its icon in `logs.scss`.
- External sync code logs successes at `info` with the Indico ids and emails involved, so an action can be traced later; failures alone are not enough.
- End-user warnings are one concrete sentence; no double spaces or typos in user strings.
- Log arguments carry only what helps (no event id when it cannot be acted on).

## External Services And Performance

- Check both members of parallel API families (meeting and webinar).
- Match external types exactly; normalize with a quirk comment.
- No O(n) external sweep per request: daily Celery task, scoped cache with TTL above the interval, per-item fallback.
- Common case first.
- Re-fetch after a PATCH when the provider drops values silently.
- Sync features handle the full lifecycle: created, deleted, state changed (including reset to pending), parent deleted, room created, option enabled on an existing room (sync existing items then).
- Bulk changes within a request: queue in `flask.g`, flush once in `signals.core.after_process`, use the provider's batch endpoints.
- Before pushing a full set, fetch the provider's current list and send only the difference.
- Matching an external account: `find_enterprise_email(user)` first, registration email as fallback; lowercase once at the source (the DB already enforces lowercase on Indico emails).
- Bypass cached tokens (`force=True`) when verifying scopes or permissions.
- Verify required scopes by exercising every API call (status updates, batch endpoints) on a real tenant; error messages list only the missing scopes and never propose legacy scopes unless already in use.
- `@memoize_request` over hand-rolled `flask.g` caches; drop the cache if it never hits.
- Forbid configurations that multiply edge cases (a room with registration enabled attached to several events) instead of supporting them.
- Features whose result reaches users without an account must deliver it where those users can see it (registration summary via token link).

## Security

- Escape user strings in HTML messages; secrets from config never reach the browser.
- Never `| safe` on user content; `sanitize_html` or a render-mode `Markup` wrapper. Plain-text previews render no HTML at all.
- Plugin endpoints scoped to event, category or regform.
- Provider defaults verified (`approval_type`).
- Standard primitives for hardening: `hmac.compare_digest`, `secrets`; no signatures in logs.
- Scanner findings need a proof of concept or a reason; cheap hardening (`parseInt` on an id from the URL) is still accepted.
- Signed file links via `File.signed_download_url` and `RHFileDownload`; check `UploadFileMixin` before writing an upload handler.

## Behavior Changes

- Changes to existing workflows are opt-in per form, off by default, or narrowed to the unambiguous case.
- Features needing extra provider permissions get two switches: plugin-level `allow_x` (validated against the granted scopes at save time) and per-room `x` shown only when allowed; both default off. Related provider recommendations go in the description, not enforced. Link to the README section instead of listing scopes in the description.
- Settings dialogs with several topics use `_fieldsets` on the form and `jsonify_form(form, fieldsets=...)`.
- Walk state machines with payment (approve, pay, change, approve again) before claiming correctness.
- Warn users before surprising consequences.
- Defaults only where they are what the user would choose.
- Keep source formats when converting data (PNG stays PNG).
- Every entry point building the same payload gets the behavior (user form, manager on-behalf, bulk).
- A locked value is written from its source (`value = invitation.email`), not by marking the field read-only and leaving it blank.
- Labels name the behavior plainly ("Lock email address", "cannot be changed during registration"); verbs are consistent across UI, flash messages and changelog ("re-send").
