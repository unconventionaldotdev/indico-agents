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
- Early return for the short branch, then flat code for the main one; a two-branch assignment is a ternary. Never a nested ternary: three branches become a local `def` with `if/elif/else`.
- Truthiness checks (`if tags:`), never `len(x) > 0`; `not all(...)` over `any(not ...)`.
- `match` over if/elif chains on enums, with `case _: assert False` for the impossible branch.
- Use the existing abstraction (`obj.protection_parent`) instead of `getattr` chains over known parent attributes.
- Behavior of enum options is documented on the enum (`__titles__`, docstring), not in a settings dict comment.
- Short names everywhere (`all_tags`, not `all_tags_must_be_present`); `tpl` for template variables.
- New public symbols are re-exported in the module `__init__` and listed in `__all__`.
- Enums are `IndicoIntEnum` / `IndicoEnum`, never bare `(int, Enum)`. Option-like enums are `RichStrEnum` with `auto()` members and a `__titles__` dict; query-string choices are an `IndicoStrEnum` with `auto()`, never a nested `(Enum)` with int values; values derived from a member are `@property` named by what they return (`delimiter`, not `char()`).
- A workaround for surprising framework behavior (`form.x.enum[form.x.data]`) is a bug to trace with a debugger and fix at the source (`strip_whitespace` must not convert str enums), not a line to keep.
- Bulk endpoints whitelist the compatible actions in the webargs validation (`fields.Enum(..., validate=validate.OneOf([...]))`), not with early returns in the body; `fields.Enum`, never `marshmallow_enum.EnumField`. Items the bulk action skips are reported, not silently dropped.
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
- Previews use a lightweight mock object (`MockX(regform, first_name, last_name)`), not an unsaved model plus `self.commit = False`. When the real model's properties are needed, link the instance only to the form (never to the event or other persisted rows), fill the default personal data fields so the output does not look broken, and confirm in the SQL log that nothing is inserted. Sample values are dummy names and `test@example.com`, never translated placeholders.
- Request data comes through `@use_kwargs` (`fields.Enum(StateEnum, required=True, validate=validate.OneOf([...]))`), never `request.form.get`; `@no_autoflush` goes below the webargs decorator.
- Internal errors that no user can trigger (`'Invalid state'`) get no i18n. Model methods raise `ValueError` (plain f-string) for states they cannot handle, as a catch-all so a new enum member fails loudly; HTTP exceptions are raised only in the RH, which wraps the model error with `NoReportError.wrap_exc(exc)` and checks the user-facing precondition itself.
- State-changing model methods take no `silent` flag and return nothing; the caller decides how to handle a no-op. A signal already sent by the inner method is not sent again by the outer one.
- Free-text user inputs (names, affiliation, address, phone, comments) carry a max length on both the schema and the client.
- Dialog triggers are declarative (`data-ajax-dialog`, `data-href`, `data-method`, `data-title` built with `html_params` in the form constructor, where the request context is available), not JS in the template setting `data-href` at runtime.
- `form.identifier.data`, not `form.data['identifier']` (builds the whole dict for one value); `user.local_identity`, not `next(iter(user.local_identities))`.
- A branch unreachable after an earlier `isinstance(exc, (A, B))` is a bug, not dead code to keep.
- A setting the UI enforces is enforced server-side too, and the create and edit paths behave the same.
- Behavior the admin may want either way (verbose vs generic login errors) is a config option defaulting to the current behavior; never set it unconditionally, never fail startup when it is missing.
- Security code never guesses (which form field is the identifier); when the information is not available, add an explicit attribute upstream (in the library) and wait for the bump.
- A global rate limiter check runs after form validation, never in a way that locks every user out once hit. Failed lookups of a username log at `info`, wrong passwords at `warning`.
- Parsing (CSV sniffing, delimiters) stays server-side; `csv.Sniffer()` over the first lines, empty input returns `[]`, failure raises `UserValueError`.
- Do not store uploads that are consumed immediately; process the stream and return the data instead of `UploadFileMixin` plus state kept in `validate_file`.
- Exercise every caller of a changed shared util (exports from other modules, objects without an ACL) before merging.
- One query for the set, then membership in Python; never a query per candidate inside a loop.
- Eager loading is measured on a large event, per list: `selectinload` when the relationship multiplies the parent rows (many persons per contribution), `joinedload` when the child is the queried object; `selectinload` for a to-one on a long list keeps the main query small. A `load_only(...)` must include the FK columns (`own_room_id`) of relationships read later, or the eager load silently falls back to one query per row. Removing a relationship filter (`primaryjoin`) means auditing every consumer of that relationship.
- Display names come from the model's canonical property (`room.full_name`), never rebuilt from parts at the call site.
- Debug leftovers (`print`, `console.debug`) never reach a PR; stage with `git add -p`.
- Extend the existing ACL helper (`get_manager_list(permission=..., explicit=...)`) instead of writing a near copy. Specific permissions are not inherited, so `recursive=True` combined with `permission` or `explicit` is rejected or ignored; notification audiences use `explicit=True`; defaults are not passed explicitly.
- Service integrations get a flag in the response (`reset`) instead of a callback endpoint; a service-only endpoint checks `self.is_service_call`.
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
- 120-character lines; no line breaks that fit on one line; long boolean expressions wrapped in parentheses, one operand per line, `and`/`or` at the end of the line.
- `Path.read_text()` / `write_text()` over `open()` blocks; `click.Path(path_type=Path)` for CLI paths; dev scripts fail gracefully (`click.secho(msg, fg='red')` then `sys.exit(1)`), and dumped files get `normalize_linebreaks`.
- Never access `current_app` at import time (module constants); wrap the lookup in a function.
- `Schema().jsonify(data)` over `jsonify(Schema().dump(data))`.
- Overlap checks go through `overlaps()` from `indico.util.date_time` with tuples and `inclusive=True`, never hand-written comparisons.
- Lookups: `Model.get_or_404(id, is_deleted=False)` and `filter_by(date=date)` over `filter(Model.date == date)`.
- Do not re-implement framework behavior: `IndicoFlaskParser` already strips surrounding whitespace from request data.

## Naming And Comments

- Names replace comments (`_check_unique_title_in_section`); a comment restating the name is removed; copy-pasted comments are checked for drift.
- Private helpers `_`-prefixed; attributes follow the class convention (no lone `_attr` in a class with public attributes).
- Siblings share a scheme (`auto_register` / `auto_checkin`; `RegistrationCheckinPermission` / `RegistrationModerationPermission`); descriptions follow one template.
- Precise locals (`page_token`); never `i` for non-numeric loop variables; no underscored import aliases.
- Comments state facts that hold; limitations are verified; hardcoded lists cite their source (provider docs).
- `# XXX` for external quirks; a knowingly rough approach gets a one-line why-it-is-safe comment.
- Wording matches the module (the Zoom plugin says "Zoom meeting"); user-facing labels are plain words ("Short name / abbreviation", not "Code").
- Docstrings: Sphinx roles (`:class:`, `:exc:`, `:data:`), double-backtick literals. Every documented `:param:` exists in the signature; generic helpers (`render_breadcrumbs`) get no object-specific params.
- Leftovers of a discarded approach (an unused class attribute, a docstring param, a `return` on an unused value) are removed before review. A property nothing reads (`events` on a booking) goes, even when a same-named one existed before; add it back when a consumer appears.
- Comments and strings follow a rename ("booking occurrences" after the link moved to occurrences). Module names keep their capitalization ("Room Booking occurrence(s)"), common nouns stay lowercase; menu titles name the process ("Room booking"), not a count.
- A model `url` property with no own endpoint yet uses the parent's locator with a comment, so no unused id lands in the query string.
- A recurring object is created only when the span needs it (`RepeatFrequency.NEVER` for a single day); defaults never force repetition. An enum whose member means "off" may use `0`.

## Imports

- All at top, grouped stdlib / third party / indico / plugin. Local import only to break a cycle.
- Long symbol lists become module imports (`from ...management import reglists`).

## Request Handlers And Access

- Override `_check_access` (super first) so errors name the right object; never `_check_management_permission` for object-level checks.
- Shared `PERMISSION` tuples live on an intermediate base class; subclasses never repeat an inherited `PERMISSION`.
- Every endpoint that lists, counts, exports or acts on the same objects applies the same filter and gate; feature-gated endpoints stay closed when the gate is off.
- Narrow permissions grant nothing beyond their purpose: logs, exports, configuration, legacy APIs stay with full management. Walk every flow as the new role: undo popups and bulk buttons often post to endpoints of another module, generic email endpoints still require full management, "create new session/track" and publish toggles stay hidden. A permission name is valid only on the class that declares it (`can_manage(user, permission='contributions')` raises on a `Contribution`).
- New helper endpoints start admin-only; loosen later when another consumer appears.
- Object lookup in `_process_args` via `@use_kwargs({'obj': ModelField(Model, filter_deleted=True, required=True, data_key='obj_id')}, location='view_args')` with the kwarg named explicitly (never `**kwargs`), also instead of `Model.get(request.view_args[...])`; always call the base `_process_args` even when it is a no-op.
- Base methods are called explicitly (`RHBase._process_args(self)`), never through `super()`; no `__init__` on RHs, attributes are set in `_process_args`. Admin-only overrides of `_check_access` call the base first, then `raise Forbidden`.
- Parallel families (file/picture upload, display/management) share the same base RH data (`self.field`); the public variant mirrors the management one with `normalize_url_spec` and `skipped_args`.
- Child objects are loaded through the parent (`Model.query.with_parent(self.event).filter_by(id=...).first_or_404()`), one chained call per line; the model gets a `locator_property` including the parent id (on the concrete subclass when the base lacks it) and the RH declares `normalize_url_spec = {'locators': {lambda self: self.entry}}`.
- `BadRequest` for a wrong object type or state, `Forbidden` only for permission failures; the server rejects what the UI disables (attachments present, still pending). `_check_access` holds permission checks only; state validation (already linked, dates do not overlap) raises `BadRequest` from `_process_args`.
- An action that makes data appear inside another object (linking a booking to an event) requires management rights on that object too. `allow_admin` follows the admin override flag sent by the client (`fields.Bool(load_default=False)` in `query`), never unconditional admin power; the frontend mirrors the same `canLink` logic.
- Endpoints useful only to managers check the management permission even when the data is not sensitive.
- User-provided names never become path components: match against a whitelist (`dir.glob('*.yaml')`, compare `stem`) and derive later paths from the matched entry so static analysis sees no tainted path.
- Path parameters are parsed with `@use_kwargs({...}, location='view_args')` (`fields.Date`), not `dateutil.parser.parse(request.view_args[...])`.
- RH and endpoint names say what they do (`RHBookingOccurrenceLink`, `booking_occurrence_link`, `registrations_update_price` rather than `registrations_base_price`); an `Actions` suffix only when one RH covers several actions. URL paths use hyphens (`/update-price`), never underscores.
- Query-string args are snake_case and parsed with `@use_kwargs({'group_by': EnumField(GroupBy, load_default='category')}, location='query')`, never `request.args.get` plus a manual enum lookup.
- Feature code lives in the module owning the object it changes (a registration fee form and RH in the registration module, not in payments), even when the feature is gated on another module's feature flag.
- Bulk actions touch only items in the applicable state; other states are skipped or covered by an explicit option (an action dropdown: remove, sync to default, custom value, plus a switch for the edge state). A form only reached from a dialog is `methods=('POST',)`; it carries `submitted = HiddenField()` and overrides `is_submitted()` as `super().is_submitted() and 'submitted' in request.form`, so the first POST renders instead of validating.
- When a dialog action changes what the list shows, return `jsonify_data(flash=False)` and reload the page so the flashed messages appear after the reload.
- Never load a whole large table (all categories) to post-process it; use the denormalized data on the row (`detailed_category_chain`, undeferred to avoid O(n) queries) and compute on the server.
- A state that cannot happen raises a plain `Exception` (logged, visible to admins), never `NotFound` or another HTTP error that reaches the client as a silent 4xx. No fake default objects (`{'id': 0, ...}`) for impossible cases.
- Page classes build breadcrumbs by overriding `_get_breadcrumbs` with `render_breadcrumbs(_('Calendar'), category=self.category)`; the last crumb is not a link. A breadcrumb trail behaves the same on every crumb (no per-crumb target logic).
- Keys from client-controlled or externally stored data are read with `.get()` so bad input fails with a validation error, not a `KeyError`.
- References submitted by managers are validated in the schema with `self.context`: same parent (`Model.query.with_parent(parent).filter_by(id=...).first()`), no self-reference, no cycles (walk the chain with a seen set), no disabled or manager-only targets, and a per-type capability flag on the field implementation (`allow_condition`).
- Deleting or disabling an item others depend on is refused with `NoReportError.wrap_exc(BadRequest(_('...')))`, including the parent section; no silent cleanup of dependents.
- Never derive server state from the partial payload the client sends (only changed fields arrive). Merge into the stored data first, then resolve derived state (hidden fields) recursively from the merged data; delete the data of hidden fields and skip their `required`. One shared utility for this check, used by the model and the util; `view_data` is for the frontend only.
- Field-type-specific behavior lives on the field implementation class (`get_data_for_condition`, `empty_value`), mirrored by the same-named function in the frontend registry; both docstrings state they must match.
- Celery tasks receive ids and reload the object (it may be gone when the task runs).
- The response to a mutation carries everything the UI must refresh (`has_pending_invitations`), not only the list.
- "All" is the absence of the key or `None`, never an empty list.
- A mode with its own filtering (linkable bookings) gets its own endpoint with bounded ints (`fields.Int(validate=validate.Range(min=0), load_default=0)`), not extra optional args on a paginated one; the server filters out what the user cannot act on, the client renders everything it receives.
- Query criteria are built per branch as full expressions (`(A > x) & (B <= y)`), never by mutating `criteria[0]` with `db.and_`. Prefer inclusive comparisons over client-side offset hacks unless pagination needs them.
- Schemas, args and selectors made obsolete by the final design are removed in the same PR.
- RH docstrings describe what the handler does now, not the earlier design.
- `@use_args(Schema)` with a positional `data` when the dict is passed on; `@use_kwargs` only when fields are consumed individually.
- Admin-level changes are logged with `AppLogEntry.log()`; models get a `log()` method that prefills `meta` with a namespaced id key (`editing_tag_id`, not `tag_id`, so log filters never mix objects of two modules) and, for objects owned by an event or a category, a `log_realm` property. Every mutation of the object (create, clone, update, delete, publish, unpublish) is logged with the relevant flags in `data` (`Published`, `Notified`). Log before `db.session.delete(obj)`, not on the deleted object.
- A formatted title that only suits log messages is `log_title`, not `verbose_title`.
- `populate_from_dict(data, keys=ATTRS)` takes the dict itself, no `.keys()`. `make_diff_log` field specs give `{'title': ..., 'type': 'string'}` for strings and pass enum members raw.
- Adding missing logging across a module is its own PR with its own changelog entry.
- A toggle is two RHs with two URLs (`/publish` POST+GET for the dialog, `/unpublish` POST), never one RH switching on `?publish=true`. Alternate URL shapes come from locator variants (`@locator.filename`, `@locator.registrant`) referenced from `normalize_url_spec`; query args a locator provides are listed in `copy_query_args`.
- Blueprint URL strings are never wrapped: `_bp.add_url_rule(` then the full URL on its own line.
- Respect type hints when calling (a `list` parameter gets a list, not a set); no f-string around a single expression.
- Signals receive the parsed `data`, not `request.json`; an empty payload after plugins ran is a no-op, not `BadRequest`.
- Links embedding a capability (ticket link with registration token) are hidden from roles without it.
- Permission-based redirects happen inside the RH, not by rewriting menu targets.
- Schemas limit what is accepted and returned. List APIs returning many rows expose foreign keys (`link_id`, derived by `SQLAlchemyAutoSchema`) rather than nested objects whose access would have to be checked per row; details load lazily from the item dialog. Nesting a new relationship in such a schema is checked with `bin/utils/db_log.py` and gets a `joinedload`.
- Validation applies identically on every path (import modes, API, UI).

## Signals

- Narrowing signals mutate the passed list in place; `values_from_signal(skip_none=True)` already drops `None`.
- Docstrings state sender, kwargs, return and combination semantics.
- Signals live in their topic module (`signals/affiliations.py`), named like the existing family.
- Core hooks need a core consumer.
- Plugins register handlers with `self.connect(signal, handler, sender=...)` in `init()`, never module-level `connect_via`.
- Signal kwargs have no defaults: an absent kwarg is the normal case, the special case is an explicit `silent=True` (or `no_log`), never `log=True` that every handler must default itself.
- A state transition performed by hand (a bulk action setting `complete`) still fires the state-change signal and notifies; pass `silent=True` when the generic log entry would mislead and log the action yourself.
- A handler that always yields exactly one item returns it instead of being a generator.

## Forms (WTForms)

- Dependent fields: `HiddenUnless('toggle', preserve_data=True)` plus `DataRequired` when empty makes no sense.
- No `Optional()` when it is the only validator.
- Uniqueness checks scope to enabled items and run again on re-enable; case-insensitive via `db.func.lower`.
- Per-event behavior is an event or room field, not a global plugin setting.
- Multi-value errors name the offending items.
- `markupsafe.escape` on user strings inside `ValidationError`.
- Forms referencing external accounts must load when the account disappeared; failing to save is fine.
- Never mutate `field.data` in `validate_*`; normalize in `process_formdata` or `post_validate`.
- Field definitions sit with the other fields, one kwarg per line when long; drop descriptions that restate the label. Keep the label on fields whose label is not rendered when sibling forms set it. Order fields by how the user fills them (file, delimiter, then switches) and keep the ordering tuple in sync.
- Single-use message strings are inlined in the `flash()` call, not exposed as properties.
- Values the client never changes are form constructor kwargs (`def __init__(self, *args, event, mode, **kwargs)`), not hidden fields round-tripped through the browser; never `kwargs.pop('x')`.
- `Decimal('0.01')` from a string, never `Decimal(0.01)`. `NumberRange` bounds match the model constraint (`999999999.99`) and the field's intent (`min=0.01` when zero is a separate action) so the right validator produces the message.
- Prices in labels and choices go through `format_currency`; a dialog changing a value shows the currency and pre-fills the current value. A switch description states the effect ("If enabled, registrations in the X state ... will ...").
- Relationships are edited through query fields (`IndicoQuerySelectMultipleCheckboxField`, `IndicoQuerySelectMultipleTagField`) so `populate_obj` assigns them; no id lists resolved by hand in the RH. Relationships already exclude soft-deleted rows; sort with `natural_sort_key`.
- "Nothing selected means no restriction" is stated in the description; labels stay short enough not to wrap ("Filter by forms").
- Rich-text fields that end up in emails: `[NoRelativeURLs()]` plus `TinyMCEWidget(absolute_urls=True, height=300)`.
- Widgets that hide or show other fields (`HiddenUnless`) need the underlying input in the widget HTML, not rendered by React: `initForms` runs before the script.
- Never append to `field.validators` or change `field.flags` in `__init__` (leaks into every instance); use `inject_validators` or `del self.field`.
- Subjects and other non-HTML strings get no `strip_tags`; escape where they are rendered.
- Check rendered field order after overriding an inherited field.

## Schemas (marshmallow)

- `@validates_schema(skip_on_field_errors=True)`, written explicitly even though default.
- `ValidationError(_('msg'), 'field')`; named placeholders in multi-value strings. A rule depending on another field or on a setting (reason required unless linked) lives in `@validates_schema` on the schema, never on an RH base class; on edit it reads the object from `self.context['booking']`, on create the payload (`booking.links if booking else data.get('link_id')`), never both.
- Settings schemas loaded with `partial=True` never mark fields `required=True`.
- Optional text fields take `load_default=''` or `None` and the client omits empty values (`nullIfEmpty`, `onlyIf`); no regex to allow "empty or 3+ chars", and a min-length validator that nobody needs is dropped.
- Nested objects the viewer may not access are blanked in `@post_dump(pass_original=True)` (`data['object'] = None` after `can_access`), not filtered in the RH; the client renders "Details hidden - no access". Nested schemas pass `only=(...)`. A summary endpoint never embeds details of linked objects (titles leak); details load from their own endpoint.
- Dotted attributes: `NaiveDateTime(attribute='occurrence.start_dt')`, not a `Function(lambda ...)`. The enum type of a `state` field is the owning model's enum. Fields and `HACK` getattr workarounds the client no longer reads are removed.
- `data['x']` for fields with `load_default`.
- Free-form metadata is `fields.Dict(keys=fields.Str())`; `null` rejected, empty is `{}`.
- `fields.Pluck(RelatedSchema, 'attr', many=True)` over a `fields.Method` that maps a relationship by hand.
- `load_default=lambda: []` for mutable defaults (`load_default`, never `default`); `@pre_load` hooks `deepcopy` `data` before mutating nested dicts and guard missing keys (`if 'attributes' in data and 'type' in data`), with a comment when a library (`OneOfSchema`) forces the shape.
- `fields.Int(strict=True)` where a string must be rejected; `fields.Dict(keys=..., values=...)`; `fields.List(fields.Nested(S))` rather than `Nested(S, many=True)` plus `data_key`.
- Defaults per field type are computed by one rule on the server and the client alike (`checkbox` -> `False`, text -> `''`, dropdown -> option at `default`).
- YAML written for humans keeps its order (`yaml.safe_dump(..., sort_keys=False)`).
- A binary response never smuggles JSON in a custom header; return JSON with the base64 payload plus the data, or the file alone.
- Backend regex validation mirrors the frontend one.

## SQLAlchemy And Migrations

- `contains_eager` after an explicit join; join via relationships (`.join(Model.rel)`), `.with_parent()` where it fits.
- Filter soft-deleted parents at every level, with a test per level.
- An object that produced artifacts (a template behind generated documents) is soft-deleted: `is_deleted` column, `get_or_404(id, is_deleted=False)`, backrefs with a `primaryjoin` excluding deleted rows instead of `cascade='all, delete-orphan'`, every listing filtered. Ordered children sort with `attrgetter('parent.position', 'position')`.
- Query the subtype class (`RegistrationFormField`) for subtype-only constraints.
- New FK to `User`: backref, alphabetized backref list, `merge_users` handling.
- `#:` column docs; keep the blank line between columns and relationships. `down_revision` points at the current head when the PR is opened and again before merge. `alembic` label on the PR; revision rebased at merge (filename date, `down_revision`); `op.add_column` calls fit on one line when under 120 characters.
- `column_property` changes that back an index update the index in `upgrade` and `downgrade`; `indico db_diff` must be empty.
- Pick NULL or empty string, not both; NULL gets `CheckConstraint("col != ''")`.
- Association tables declare `ondelete='CASCADE'` on both foreign keys; the closing parenthesis of `op.create_table` sits on the last argument line.
- Moving a relation (links from reservations to occurrences) renames the existing table instead of create plus drop: rename table, add the new column with its FK and index, migrate data with `UPDATE ... FROM`, drop the old column; rename the sequence, PK, indexes and constraints to the new table name with `op.execute('ALTER ...')`, mirrored in `downgrade`. Until the data migration exists in both directions, destructive steps stay commented out so testers keep their database. Reflected downgrades use `PyIntEnum`, not native PG types.
- `index=True` on the column instead of separate `op.create_index`; `downgrade` does not drop indexes of a table it drops. Enum copies inside migrations match the model enum member for member. Constraints exist in both migration and model, or in neither (drop a uniqueness check when duplicates are harmless). Blank line after the title in the revision docstring.
- Search over text columns: prefix match over substring, skip words under 3 chars, GIN/FTS index in the migration, results cached with `memoize_redis(ttl, versioned=True)` and the version bumped on writes.
- New relationships on a cloned model update its `EventCloner` (`uses`, mapping through `shared_data`, skip when the dependency was not cloned).
- Switching stored text from plain to HTML uses `RenderModeMixin` with a `render_mode` column (legacy rows stay plain text, new rows HTML), never a destructive data migration.
- Configuration the server must query or validate (references to other rows) lives in real columns with foreign keys, not inside a JSON `data` blob.
- Mutating a JSON column on a persisted object needs `flag_modified(obj, 'data')`; `db.session.add()` is redundant for objects already in the session. Build children with `parent=section`, not `parent_id=section.id` plus a flush.
- Row references between items of the same parent: the cloner maps old ids to new ones in a second pass after all items exist; `export.yaml` orders the rows topologically so idrefs resolve on import.
- Count queries on a large event before and after a list change; a per-row property that touches a relationship (latest comment date) turns a fixed number of queries into one per row. Compute it in SQL as a `column_property` with a correlated scalar subquery, registered in a module-level `@listens_for(orm.mapper, 'after_configured', once=True)` function (never inside the class), `deferred=True` plus `undefer()` when few views need it. A real column updated on every write is the fallback.
- A derived check used in several places is a model property (`is_condition` for "others depend on me", `is_conditional` for "I depend on another"); `column_property` only when it must be filtered on or loaded in bulk.
- Trailing comma only in single-element tuples: `methods=('POST', 'DELETE')`, `methods=('POST',)`.
- Multi-line queries: either `(` on its own line or `(Model.query` with chained calls aligned under it; match the style of the adjacent queries in the file. `Model.query` first, one `.filter(...)` with one criterion per line, `.has_rows()` last. A query that fits on one line stays inline in the `if`; otherwise it gets its own statement.
- `.one()` on lookups that cannot miss (soft-deleted rows still exist); no defensive `- {None}` or `or {}` without a reproducible case, and a comment when one exists.
- Set intersection is `a & b`, never `bool(a.intersection(b))`. Subset checks are `keywords <= allowed`; "any invalid" is `invalid := values - allowed`; `sorted(a & b)` over list comprehensions with membership tests; `dict.setdefault` over `if key not in d`.
- A POST that modifies data ends with `return redirect(url_for('.same_page'))`, never by rendering the page (F5 would resubmit).
- Never assign a field on a form class at runtime (shared globally); build a subclass per request: `type('_Form', (BaseForm,), {'field': field})` from a `form_class` property. A field added dynamically gets a one-line comment on the base form so its `validate_*` does not look orphaned.
- Whitelist validation of stored values adds the existing data (`field.object_data`) to the allowed set so a shrunk whitelist does not block saving unrelated changes. Keep whole hashes of a `ValidationError` message free of user input (it renders as HTML).
- Deterministic pure functions called in loops (`generate_contrast_colors`) get `@functools.cache`; cheap recomputation beats a conditional cache (no premature optimization).
- Setting proxies are named by scope (`global_event_settings`), never `misc`; `event_settings` is reserved for per-event plugin settings.
- Images from users: open with Pillow, catch `OSError`, allow `{'jpeg', 'png', 'gif', 'webp'}` by `pic.format`; never trust MIME type or extension, never `Image.OPEN` (lazy), never user SVGs in PDF rendering (the URL fetcher follows embedded URLs). No JPEG-to-JPEG roundtrip. Guard `event.has_logo` before reading the logo. Previews are cached with `@memoize_redis(3600)` on a module-level function.
- `raise ... from exc` when wrapping; catch the real exception, never bare `Exception`; `.first()` plus `if not x` over `.one()` in `try`. `Path(root) / 'a' / 'b'` segments as elsewhere in the module. Pick one noun per concept (`image`, not `picture`).
- Image-like user input in template custom fields is restricted to the internal scheme (`event://`) even when an URL fetcher would reject the rest; defense in depth is accepted.
- Encode invariants as CHECK constraints (e.g. `internal_name` required when `personal_data_type` is set) so edge cases such as cloning cannot produce bad rows.
- Partial-index `WHERE` clauses must be justified.
- Iterate enum members, never `range` over their values; SQL in triple-quoted strings indented under the call.
- Data migrations never hardcode the system user id; use `(SELECT id FROM users.users WHERE is_system)`.
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
- Event log: module is the object ("Registration", also for a fee change), log only actual changes (compute added/removed before mutating); items whose value did not change are left out of the entry and the count, and state changes caused by the action are logged too. Flash with `ngettext`, subject first ("Registration fee has been updated for {} registrations"). Titles say "Update", not "Edit", for changing a value. Cross-object actions (a booking linked to an event) are logged on the event with ids and times in `data`, times in the event timezone.
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
- Signed file links via `File.signed_download_url` and `RHFileDownload`; check `UploadFileMixin` before writing an upload handler. Never put a signed (expiring) link in an email: use an endpoint protected by the recipient's token (registrant locator) or attach the file.
- User-authored templates render in `SandboxedEnvironment(autoescape=True)`; `TemplateSyntaxError`, `TemplateRuntimeError`, `SecurityError` and `LookupError` become `UnprocessableEntity`.
- Anything that signs values inside `url_for` (a URL converter) must be opt-in (`_sign=True` kwarg stored on `g`), because the URL signing endpoint builds URLs for arbitrary endpoints; a test asserts that endpoint rejects underscored args. Cache-busting slugs in URLs stay.
- Picture sizes and similar magic numbers are module constants; `A if cond else B` without a negated condition.

## Behavior Changes

- Changes to existing workflows are opt-in per form, off by default, or narrowed to the unambiguous case.
- Features needing extra provider permissions get two switches: plugin-level `allow_x` (validated against the granted scopes at save time) and per-room `x` shown only when allowed; both default off. Related provider recommendations go in the description, not enforced. Link to the README section instead of listing scopes in the description.
- Settings dialogs with several topics use `_fieldsets` on the form and `jsonify_form(form, fieldsets=...)`; the attribute is always `_fieldsets`, and a macro argument that duplicated it is removed once the form carries the data.
- Walk state machines with payment (approve, pay, change, approve again) before claiming correctness.
- Warn users before surprising consequences. Images are never scaled up silently: flash a warning with the recommended width when an upload or a setting change leaves the current image outside the range, and state the recommendation on the management page.
- An action that needs an explanation for its recipient (request changes) cannot be fired without a comment; the bulk path gets the same dialog as the single one.
- Defaults only where they are what the user would choose.
- Keep source formats when converting data (PNG stays PNG).
- Every entry point building the same payload gets the behavior (user form, manager on-behalf, bulk).
- A new relation between items raises every interaction: paid items (lock the condition client-side, rely on the server price check), retention periods (a dependency cannot be purged before its dependents), cloning, export/import, manager-only sections, disabled and deleted items, default values. Answer each before asking for review.
- Terminology is one word per concept across labels, placeholders and errors ("Indefinite", not "Permanent" in one place).
- A locked value is written from its source (`value = invitation.email`), not by marking the field read-only and leaving it blank.
- Labels name the behavior plainly ("Lock email address", "cannot be changed during registration"); verbs are consistent across UI, flash messages and changelog ("re-send").
