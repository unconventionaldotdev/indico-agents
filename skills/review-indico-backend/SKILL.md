---
name: review-indico-backend
description: Backend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers Python structure and naming, imports, request handlers, signals, WTForms, marshmallow, SQLAlchemy and Alembic, config, logging and errors, external services, security and behavior changes. Use through review-indico-pr or on its own for a Python-only change.
---

# review-indico-backend

Check the touched Python files and their callers against every item.
Pick the sections that match the file (a controller module gets Request Handlers, Logging and Security; a `models/` file gets SQLAlchemy; `forms.py` gets Forms; `schemas.py` gets Schemas) and walk every bullet of those sections, plus Structure, Naming and Imports for every file.

## Structure

### Control flow

- Return early for the short branch, then keep the main branch flat instead of nesting blocks.
- A guard with a non-obvious sentinel gets a one-line comment (`is_enabled is None` means the row is not flushed yet).
- Merge adjacent blocks that share the same guard.
- Collapse nested guards into one condition (`if python and po_file_empty(p):`, not `if python:` wrapping `if po_file_empty(p):`).
- A two-branch assignment is a ternary written as `A if cond else B` with a positive condition, never a negated one.
- Never nest ternaries: three or more branches become a helper function with `if/elif/else` (module-level, since nested `def`s are not allowed).
- `match` over `if/elif` chains on enum members, with `case _: assert False` for the impossible branch.
- `match` with class and sequence patterns for type dispatch instead of `isinstance` chains.
- Order branches with the common case first.
- A loop that searches for the first match returns from inside the loop; the fallback follows the loop.
- A branch unreachable after an earlier `isinstance(exc, (A, B))` check is a bug to fix, not dead code to keep.
- No guard for values no caller passes (`if not fmt: return None` when no caller passes a falsy `fmt`).
- Fail loudly instead of silently narrowing: abort when any requested id is not permitted, instead of processing the permitted subset.
- A check with known false positives (format-string validation) does not abort the operation it precedes, or it ships an opt-out flag (`--no-check`).

### Locals and expressions

- Walrus in guards: `if not (x := get()): return`, `if missing := compute(): raise ...`.
- Walrus in comprehensions and guards avoids repeated getter calls (`if flag and (items := data['items']):`); parenthesize `or` chains inside a walrus.
- Return the expression directly; no local assigned only to be returned.
- Declare variables where they are used, not at the top of the function.
- Reuse the local already computed (`user.email`, not `session.user.email` after `user = session.user`); a query result used twice in one expression becomes a local.
- Never reassign a parameter or local with a narrowed version of itself (`languages = set(languages) & set(renames)`); put the expression in the loop header.
- Expensive work runs only on the branch that uses it; a branch that redirects returns before the query.

### Comparisons and truthiness

- Truthiness checks (`if tags:`, `if not f.size`), never `len(x) > 0` or `== 0`.
- `not all(...)` over `any(not ...)`.
- IDs compare with `is not None`: `if editor_id` treats id `0` as missing.
- An "absent" sentinel is `None` (`getattr(obj, '_CORS', None) is None`), never `False`: an empty options dict is a valid value.
- `a != b`, never `not a == b`.
- Nested boolean conditions nest their parentheses so the grouping is visible; a boolean kwarg computed from a comparison is parenthesized (`required=(action != X)`).
- Compare against the explicit set of expected members (`fmt in ('first_last_upper', 'last_first_upper')`), never a substring of a member name, so a search for the member finds every consumer.
- Never compare ids across object types (`session.id == entry.id`); filter by type first and compare the related objects.
- Drop guards for relationships the type guarantees; collections that mix kinds (`Attachment.type` file vs link) are filtered by kind before reading kind-specific attributes.
- Set intersection is `a & b`, never `bool(a.intersection(b))`; subset checks are `keywords <= allowed`; "any invalid" is `invalid := values - allowed`.
- Set algebra over comprehensions with membership tests (`sorted(a & b)`, `locked - required_empty`).
- Respect type hints when calling: a `list` parameter gets a list, not a set.

### Collections and comprehensions

- A loop that only appends becomes a comprehension (walrus for the filtered value), never `# noqa: PERF401`; a loop filling a dict becomes a dict comprehension.
- A loop that only sets a flag becomes `any(...)` / `all(...)`.
- `[x for x in xs if cond]`, never `filter(lambda ...)`.
- Unreadable nested comprehensions become a named helper.
- Deduplicate by key with a dict (`{r.email: r}`), not by hashing dataclasses; cover the overlap case (the same email from two sources).
- Group with `group_list` from `indico.util.iterables`, not `itertools.groupby` (needs pre-sorted input).
- `key=itemgetter('position')` over `key=lambda x: x['position']`; ordered children sort with `attrgetter('parent.position', 'position')`.
- `sorted(d.values(), key=...)` over `list()` plus `.sort()`; no `list()` around an iterable passed to `sorted`.
- Build output in its final order (dicts keep insertion order) instead of sorting afterwards and deleting the sort key from every entry.
- No `.keys()` where the dict itself iterates (`validate.OneOf(SIZES)`, `x in d`, `populate_from_dict(data, keys=ATTRS)`).
- Iterate enum members, never `range` over their values.
- Collections keyed by a unique name are dicts (`{x.name: x.regex for x in handlers.values()}`), not lists of `{'name': ..., 'pattern': ...}` entries.
- `isinstance(x, (tuple, set, list))` for "is a collection" checks.
- `dict.setdefault` over `if key not in d`.

### Dicts and defaults

- `d.get(key, default)` replaces a membership check followed by indexing.
- `.get(key)` already yields a falsy `None`; no `.get(key, False)`.
- `d.get(key).attr` is always a bug: either `d[key].attr` or handle `None`.
- Index keys the code itself wrote (`data['body']`, `email['cc']`); `.get('x', [])` only for genuinely optional keys, never `.get('x') or []`.
- Keys from client-controlled or externally stored data are read with `.get()` so bad input fails with a validation error, not a `KeyError`.
- Keys added to a queued payload (email dicts) are read with `.get()` in the consumer: messages enqueued before the upgrade lack them.
- `session.pop(key, default)` replaces a `session.get` followed by `del session[key]`.
- Plain defaults in the signature; `None` plus `if x is None` only for mutable defaults and translated strings.
- No mutable default anywhere (`= {}`, `load_default=[]`): `None` plus the check, or `required=True` when every caller passes the value.
- Optional payload keys are added only when there is a value, never added and then popped.
- "All" is the absence of the key or `None`, never an empty list.

### Signatures and arguments

- New optional parameters are keyword-only (`*, flag=True`); when a caller passes the neighbours positionally, make those keyword-only too.
- Argument order: the object acted on first (`add_users_to_group(group, users)`), then the rest.
- The obvious first argument is passed positionally (`client.get(url)`).
- Prefer an attribute or a keyword with a default over a new positional argument when plugins subclass the class.
- A value that always travels with an existing tuple (`repetition = (frequency, interval)`) joins that tuple and the model property that builds it, instead of one more positional parameter threaded through every function in the chain; tests and templates follow in the same commit.
- A changed signature lands on every override and subclass.
- Return richer data through a kwarg (`full=True`) instead of reading a side effect (a cache) back.
- A method that returns nothing has no return annotation and uses bare `return`.
- Helpers do their own difference (`users - group.members`) so callers cannot misuse them; a name must not promise more than the body does.
- A helper that only validates raises and returns nothing; callers use the value they passed (`_validate(x)` then `x`, not `xs.append(_validate(x))`).
- State-changing model methods take no `silent` flag and return nothing; the caller decides how to handle a no-op.
- Several handlers that differ only in a parameter collapse into one with `any(...)`.

### Classes and dataclasses

- `@dataclass(frozen=True)` over `namedtuple`; plain defaults (`name: str = ''`, no `field()`), required attribute first so callers never pass `None, None`.
- Classes used inside one method are defined at module level, public (`AccompanyingPerson(PersonMixin)`) when a plugin may need them.
- Person names come from `PersonMixin`, never `f'{first} {last}'`; display names come from the model's canonical property (`room.full_name`), never rebuilt from parts at the call site.
- One definition point for shared infrastructure: one `cache` classproperty, one permission tuple constant, one `is_gravatar` enum property instead of repeated membership checks.
- `cached_classproperty` when class-level access is enough.
- A subclass does not adopt a better mechanism (`mm_field_class = MMFileField`) while its parent keeps the hand-rolled one; stay consistent and note the refactor.
- No override that only delegates to the base method (`def _check_access(self): Base._check_access(self)`); delete it.
- No nested `def` inside a function; make it a module-level helper.

### Helpers and reuse

- Functions that never touch `self` go to `util.py`; a helper whose only use of `self` is `self.event` is a plain function, not a mixin.
- No single-use extraction and no abstraction "for later overrides".
- Extend the existing mechanism before adding one (`PERMISSION` accepting a tuple instead of new mixins; `get_manager_list(permission=..., explicit=...)` instead of a near copy).
- Use the existing abstraction (`obj.protection_parent`) instead of `getattr` chains over known parent attributes.
- Use the existing accessor: `form.identifier.data`, not `form.data['identifier']` (builds the whole dict for one value); `user.local_identity`, not `next(iter(user.local_identities))`.
- No second accessor for data an existing object already exposes (`session.moment_lang` vs a new property); when the existing one lacks a detail, raise it in the review thread first.
- A workaround for surprising framework behavior (`form.x.enum[form.x.data]`) is a bug to trace with a debugger and fix at the source (`strip_whitespace` must not convert str enums), not a line to keep.
- A new action reusing an operation is checked against every assumption inside it (`_ensure_publishable_files` when the action may carry no files).
- Exercise every caller of a changed shared util (exports from other modules, objects without an ACL) before merging.

### Enums

- Enums are `IndicoIntEnum` / `IndicoEnum`, never bare `(int, Enum)`.
- Option-like enums are `RichStrEnum` with `auto()` members and a `__titles__` dict.
- Titles nobody displays are removed together with their `_()` markers; the enum then becomes `IndicoIntEnum`, not `RichIntEnum`.
- Query-string choices are an `IndicoStrEnum` with `auto()`, never a nested `(Enum)` with int values.
- Behavior of enum options is documented on the enum (`__titles__`, docstring), not in a settings dict comment.
- Values derived from a member are `@property` named by what they return (`delimiter`, not `char()`).
- A member classification lives on the enum as a property (`RevisionType.is_editor_action`); the model exposes it under a precise name (`is_editor_revision`), not a method listing members.
- The member for "nothing requested yet" is `none`; `pending` means submitted and waiting.
- Int members with no falsy meaning start at `1`, with `None` as the first `__titles__` entry; a member that means "off" may use `0`.

### Strings, JSON and URLs

- Ambiguous short strings get `pgettext('context', ...)`; `_` is never wrapped in a local helper (breaks string extraction).
- JSON is produced with `json.dumps(...)`, never `str()` of a list or dict; barcodes and external payloads use `separators=(',', ':')`.
- JSON pasted by admins is decoded with `json.loads`, never `ast.literal_eval`.
- Human-facing YAML is dumped with `allow_unicode=True` and keeps its order (`yaml.safe_dump(..., sort_keys=False)`).
- `.encode()` / `.decode()` without `'utf-8'` (it is the default).
- `html_to_markdown(text, inline_links=False).strip()` for HTML to plain text, not `strip_tags`.
- Subjects and other non-HTML strings get no `strip_tags`; escape where they are rendered.
- No parse-and-rebuild round trip that returns the input unchanged (`urlunsplit(urlsplit(url))`); validate with `urlsplit` and keep using the original string.
- Text composed for generated documents (badges, tickets, PDFs) stays locale-neutral: values joined with punctuation and separators, never `_()`, because the printing user's locale is not the attendee's.

### Dates, times and units

- APIs return dates and datetimes as `.isoformat()`, never a display `strftime`; the client formats.
- A date derived from a datetime is taken after `astimezone(event.tzinfo)`.
- Times shown to registrants use `event.display_tzinfo`, times in management `event.tzinfo`; an endpoint serving both takes a `force_event_tz` query flag.
- Dates shown from a payload reuse `make_format_event_date_func(category)(event)`, never a hand-rolled pair.
- Overlap checks go through `overlaps()` from `indico.util.date_time` with tuples and `inclusive=True`, never hand-written comparisons.
- Size limits convert to bytes once at the boundary (`config.MAX_X_SIZE * 1024**2`) and compare against `file.size`; a unit comment states the stored unit.

### Files and storage

- `Path.read_text()` / `write_text()` over `open()` blocks; `Path(root) / 'a' / 'b'` segments as elsewhere in the module.
- Pure string path manipulation uses `PurePath`, not `Path`; keep the original suffix instead of recomputing an extension.
- Open the file and handle `OSError` with `errno.ENOENT` (`return False`, otherwise re-raise) instead of an `os.path.exists` check before `open()`.
- Pure existence checks use `Path.glob('*/translations')` or `os.path.exists(os.path.join(...))`, never membership tests over `os.listdir()` output or nested `listdir` loops with `isdir` checks.
- File-format checks go through the library parser (`babel.messages.pofile.read_po`; an empty catalog is falsy), never substring counting (`data.count('msgid')`).
- Stored files are read through a context manager (`with file.open() as f, Image.open(f) as img:`); `file.open()` rather than `get_local_path()` (storage may be S3).
- A file from an upload endpoint is never referenced by copying `storage_backend` and `storage_file_id` into a new row (the upload `File` stays unclaimed and gets deleted): copy the content (`with file.open() as f: obj.save(f)`) or `.claim()` it.
- Stored records keep what is needed to recover later (filename, content type) and nothing more; key names follow existing Indico names (`storage_backend`, `storage_file_id`).
- Unique file names use a uuid, not a content hash (the same content saved twice must not fail).
- Do not store uploads that are consumed immediately; process the stream and return the data instead of `UploadFileMixin` plus state kept in `validate_file`.
- Parsing (CSV sniffing, delimiters) stays server-side: `csv.Sniffer()` over the first lines, empty input returns `[]`, failure raises `UserValueError`.
- Streaming a stored file into a ZIP: `ZipInfo(name, date_time=...)` with explicit `external_attr` (0o644) and `shutil.copyfileobj(src, zip_handler.open(info, 'w'))`, never `fd.read()`.
- Keep source formats when converting data (PNG stays PNG); no JPEG-to-JPEG roundtrip.

### CLI commands and scripts

- CLI command names are set in the decorator (`@cli.command('create')`) when the function must be renamed.
- `click.Path(path_type=Path)` for CLI paths.
- Dev scripts fail gracefully: `click.secho(msg, fg='red')` then `sys.exit(1)`; dumped files get `normalize_linebreaks`.
- A CLI command whose exit code CI depends on keeps `sys.exit(1)` on failure; when its logic is reused by another command, split it into a helper returning a bool and keep the command exiting.

### Formatting

- 120-character lines; no line breaks for code that fits on one line.
- Long boolean expressions wrap in parentheses, one operand per line, `and`/`or` at the end of the line.
- A line over 120 characters inside a comprehension gets a shorter loop variable, not a line break.
- When a comprehension must wrap, break before `for` with the clause aligned under the expression; never split the iterable call's argument list across lines.
- A comprehension that builds dict literals puts `{` on its own line, one key per line, each `for`/`if` clause on its own line.
- Nested payload dicts stay compact (`{'defaultValue': {'language': 'en-US', 'value': x}}` on one line when it fits); multi-line literals carry trailing commas.
- A call whose kwargs do not fit on one line breaks after `(` with one kwarg per line and `)` on its own line; never a hanging indent under the first kwarg.
- A call whose only argument is a dict literal keeps `({` on the call line and closes with `})` or `}, kw=...)` at the call's indentation (`@use_kwargs({ ... }, location='query')`, `jsonify({ ... })`); never the dict exploded on its own lines.
- Parentheses for continuation, never a trailing `\`.
- Method chains break with the `.` at the start of the continuation line.
- No parentheses around a bare literal (`'; '.join(...)`); no f-string around a single expression.
- Trailing comma only in single-element tuples: `methods=('POST', 'DELETE')`, `methods=('POST',)`.
- No blank line after `class X:` or after a `def` line; no blank lines between consecutive statements of a short method body.
- `# noqa: CODE` trails the offending line; a standalone `# flake8: noqa` disables every rule for the whole file.
- Core has no `# pylint:` directives: the linter is ruff, suppressions are `# noqa: CODE` on the offending line.
- A signature with one argument per line and a trailing comma is accepted when the one-line form exceeds 120 columns with its type hints; not a formatting defect.

### Module layout

- Module constants right after imports (or on the API client class), never inside the plugin class.
- A value used once is inlined with a short comment; a magic number that a calculation references (picture sizes, border widths) is an uppercase module constant with a fully qualified name (`QR_BORDER_SIZE`, never `border`), also when it lives on a mixin or RH class.
- New public symbols are re-exported in the module `__init__` and listed in `__all__`.
- Module `__init__.py` holds signal handlers and startup checks; helper functions called from controllers go in `util.py`.
- A large integration class (an external API client) gets its own module inside the owning package (`registration/google_wallet.py`), never appended to an unrelated file.
- Integration-specific helpers live on the integration class as static methods, not as properties on `Event`.
- Schemas serving one feature live in their own module (`export_schemas.py`).
- Feature code lives in the module owning the object it changes (a registration fee form and RH in the registration module, not in payments), even when gated on another module's feature flag.
- Code is not moved within a file while it is changed (a moved block hides the real diff); when inheritance order forces a move, the PR description says so.
- Remove methods, imports, schemas, args and selectors that a refactor or the final design left unused, in the same PR.
- Leftovers of a discarded approach (an unused class attribute, a docstring param, a `return` on an unused value) are removed before review.
- A property nothing reads (`events` on a booking) goes, even when a same-named one existed before; add it back when a consumer appears.
- Side menu items take a weight no sibling uses (read the module's `_sidemenu_items` first): `-100` for entries that go last (logs), positive weights for the rest.
- Admin menu entries sit in the section matching their topic (`user_management` for affiliations).
- When a guard blocks an operation unless a precondition holds (no field placeholders before unlinking), the cleanup inside the operation that handled the blocked case goes too, with its helper and tests.

## Naming And Comments

### Identifiers

- Short names everywhere (`all_tags`, not `all_tags_must_be_present`); `tpl` for template variables.
- Precise locals (`page_token`); never `i` for non-numeric loop variables; no initialism locals (`s_b_map`).
- Boolean names for booleans (`got_access_token`, not `access_token` when only truthiness matters).
- Private helpers are `_`-prefixed; attributes follow the class convention (no lone `_attr` in a class with public attributes) and the module's convention (`self.contrib`).
- Locals shadowing builtins get a trailing underscore (`min_`, `max_`), never a leading one.
- snake_case for every Python identifier, including kwargs that mirror a camelCase JS prop (`override_required`, not `overrideRequired`).
- `_dt` keys hold datetimes; a date-only key is `_date`.
- A list of dicts is not named `schema`.
- Pick one noun per concept (`image`, not `picture`); new names reuse the casing already in the codebase.
- User-facing identifiers use `friendly_id` (`f'#{registration.friendly_id}'`), never the database `id`.
- Class and function names name the concept, never enumerate behaviors with `And` (`RHQRCodeMetadata`, not `RHQRCodeAndMetadata`).
- A formatted title that only suits log messages is `log_title`, not `verbose_title`.
- Names replace comments (`_check_unique_title_in_section`).
- Template filters are named after what they do (`format_placeholders`).

### Siblings and consistency

- Siblings share a scheme (`auto_register` / `auto_checkin`; `RegistrationCheckinPermission` / `RegistrationModerationPermission`); their descriptions follow one template.
- Two sibling operations whose names differ only by a filler word (`create_new_paper_revision` vs `create_paper_revision`) are renamed so each says what differs.
- A variant name states the distinguishing property, not an incidental one (`Untyped`, not `Single`, when the untyped path accepts several files), applied to every sibling pair.
- Availability of a feature splits into named flags: `is_x_enabled` (own toggle), `is_x_configured` (global flag plus inherited configuration), `is_x_available` (both); each surface checks the flag it needs.
- Hook signals that let plugins alter a payload are named after the data (`google_wallet_ticket_class_data`); builders are `build_x_data`, remote calls `create_x` / `patch_x`.
- A column or field covering several things (terms of service and privacy policy) is named after the generic concept (`accepted_terms_dt`), never after one of them (`accepted_tos_dt`); its `#:` doc comment lists what it covers.
- One concept keeps one field name across the signup schema, the WTForm and the client payload (`accept_terms`), no per-surface variants (`accept_registration_terms`).
- Placeholders in translatable strings are plain words (`{max}`).
- A group or category key added next to an existing one shares its noun and scheme (`registrant` / `registrant_custom`), not a different noun (`regform_fields`).

### Comments

- A comment restating the name is removed; copy-pasted comments are checked for drift.
- Comments state facts that hold; limitations are verified; hardcoded lists cite their source (provider docs).
- `# XXX` for external quirks; a knowingly rough approach gets a one-line why-it-is-safe comment.
- A non-obvious condition (two revisions sharing editor and timestamp meaning one action) gets a comment stating what the combination means.
- Comments and strings follow a rename ("booking occurrences" after the link moved to occurrences).
- No section banner comments grouping classes in a module (`# Schemas for the X API`); class names carry it and later additions ignore the banner anyway.
- No comment between a decorator and its `def`; it goes inside the body.
- An attribute consumed in another runtime (a regex evaluated by JavaScript) says so in its `#:` doc comment, including what syntax to avoid.
- A model `url` property with no own endpoint yet uses the parent's locator with a comment, so no unused id lands in the query string.
- A comment that does not fit at the end of its line goes on its own line above the statement; never one comment split across two trailing comments.

### Docstrings

- Docstrings are full sentences ending with a period; the summary sits on the opening `"""` line (or starts on the next line when none fits), with no spaces inside the quotes (`"""Check ...`).
- The closing `"""` sits on its own line unless the whole docstring is one line.
- reST `:param x:` style, no Google-style `Args:` sections; every documented `:param:` exists in the signature; generic helpers (`render_breadcrumbs`) get no object-specific params.
- Sphinx roles: `:class:`, `:exc:`, `:data:`, `:func:` for module-level functions, `:meth:` only for methods; a role takes single backticks, a bare literal takes double backticks.
- Docstring summaries are imperative ("Get the server name", "Strip away the path"), never third person ("Gets", "Strips").
- A summary that only rephrases the function name is replaced by what the function actually verifies.
- An RH docstring is one sentence saying what the handler returns or does now ("Return metadata for the requested QR code."); it never lists parameters or option values inline and never describes the earlier design.
- Docstring summaries of plugin hook stubs may describe when the hook fires ("Hook called after ..."); the imperative-summary rule applies to functions that do something.

### User-facing wording and casing

- Wording matches the module (the Zoom plugin says "Zoom meeting"); user-facing labels are plain words ("Short name / abbreviation", not "Code").
- Module names keep their capitalization ("Room Booking occurrence(s)"), common nouns stay lowercase; menu titles name the process ("Room booking"), not a count.
- Product terms use their standard casing in messages and docstrings: "Indico" capitalized, "Indico-style" hyphenated, "QR code" with lowercase "code".
- Spelling and grammar in user strings are proofread ("are entered"); no double spaces.

## Imports

- All imports at the top, grouped stdlib / third party / indico / plugin; a local import only to break a cycle.
- Long symbol lists become module imports (`from ...management import reglists`).
- No underscored import aliases.
- `from marshmallow import fields` and `fields.X`; no individual type imports (`from marshmallow.fields import List`).
- When `g` is unavoidable, `from flask import g` with a one-line comment saying why.
- Never access `current_app` at import time (module constants); wrap the lookup in a function.
- No plugin imports while loading config (mappers are not ready); defer to `IndicoPlugin.init()`.

## Request Handlers And Access

### Base classes and module placement

- RHs inherit from their module's own base (`RHManagePapersBase`), which carries the feature and permission checks, never the generic `RHManageEventBase`.
- Event-scoped JSON endpoints extend the event base (`RHProtectedEventBase`, `RHDisplayProtectionBase`) and read `session.user`; never `RHUserBase`. Templates read `session.user` directly.
- An RH that resolves its object from the request payload rather than URL args still inherits the module's protected base and assigns `self.event` (and the object) in `_process_args`, so the standard access check runs; a bare `RH` with `_check_access` stubbed to `pass` lets any logged-in user read the data.
- A new RH goes into the existing controller module of its topic (`management.py`, `display.py`, `api.py`); no new file for one class.
- Shared `PERMISSION` tuples live on an intermediate base class; subclasses never repeat an inherited `PERMISSION`.
- Two RHs with identical access checks and flags share an intermediate base next to them, each keeping only its `_process`; when the shared part is a tiny `_process`, duplicating beats a mixin.
- A page RH reduced to one `render_template` uses the `WP` class directly, no `view_class` on a mixin.
- Parallel families (file/picture upload, display/management) share the same base RH data (`self.field`); the public variant mirrors the management one with `normalize_url_spec` and `skipped_args`.
- A new RH delivering an existing artifact in another form subclasses the artifact's RH (`RHTicketGoogleWallet(RHTicketDownload)`) so `_process_args` and `_check_access` stay shared; when unavailable it raises `NotFound('...')`.
- A management endpoint that already serves the generic case (file download) is reused for the new subtype; a dedicated RH only where handling differs.
- Mixins tied to another module's service (`TokenAccessMixin`, `SERVICE_ALLOWED`) never land on RHs of a module without such a service.

### Access checks and processing

- Base methods are called explicitly by class name (`RHBase._process_args(self)`), never through `super()`; always call the base `_process_args` even when it is a no-op.
- Override `_check_access` with the base call first so errors name the right object; admin-only overrides call the base, then `raise Forbidden`.
- Never `_check_management_permission` for object-level checks.
- `_check_access` holds permission checks only; state validation (already linked, dates do not overlap) raises `BadRequest` from `_process_args`.
- Exception to the previous rule: two alternative endpoints for the same action (typed vs untyped submission) each check in `_check_access` the condition that selects them (`PaperFileType.query.with_parent(self.event).has_rows()`), so they stay mutually exclusive server-side.
- No `__init__` on RHs; attributes are set in `_process_args`.
- `_process_args` only resolves objects from URL args; a query that depends on nothing in the URL runs in `_process` as a local.
- `_process` when every method runs the same logic; `_process_GET` / `_process_POST` only when the methods differ.
- Checks that need the current user run inside the RH flow (right after `_check_csrf()`), not in an `app.before_request` hook: `g.rh` is not set there, so `session.user` fails on `@allow_signed_url` endpoints.

### Permissions and gates

- Every endpoint that lists, counts, exports or acts on the same objects applies the same filter and gate; feature-gated endpoints stay closed when the gate is off.
- `EVENT_FEATURE = None` only where a page must work with the feature off (a dashboard), never on a list page whose APIs fail without it.
- Narrow permissions grant nothing beyond their purpose: logs, exports, configuration and legacy APIs stay with full management.
- Walk every flow as the new role: undo popups and bulk buttons often post to endpoints of another module, generic email endpoints still require full management, "create new session/track" and publish toggles stay hidden.
- A permission name is valid only on the class that declares it (`can_manage(user, permission='contributions')` raises on a `Contribution`).
- Specific permissions are not inherited, so `recursive=True` combined with `permission` or `explicit` is rejected or ignored; notification audiences use `explicit=True`; defaults are not passed explicitly.
- New helper endpoints start admin-only; loosen later when another consumer appears.
- Endpoints useful only to managers check the management permission even when the data is not sensitive.
- Plugin endpoints are scoped to an event, category or regform.
- An action that makes data appear inside another object (linking a booking to an event) requires management rights on that object too.
- Deleting something others built on (an editable with revisions) needs full event management, not management of the parent object alone.
- `allow_admin` follows the admin override flag sent by the client (`fields.Bool(load_default=False)` in `query`), never unconditional admin power; the frontend mirrors the same `canLink` logic.
- A list endpoint over event children applies `can_access(session.user)` per item; event access does not imply access to every child.
- Permission-based redirects happen inside the RH, not by rewriting menu targets.
- Links embedding a capability (a ticket link with the registration token) are hidden from roles without it.
- A model method that only wraps `can_manage(...)` or `is_admin(...)` is removed; callers (schemas, RHs) use `can_manage` directly, and the model sets `is_user_admin` so no caller needs an extra admin check.

### Arguments and parsing

- Request data comes through `@use_kwargs` / `@use_args`, never `request.form.get` or `request.args.get` plus manual parsing.
- `@use_args(Schema)` with a positional `data` when the dict is passed on; `@use_kwargs` only when fields are consumed individually.
- Query-string args are snake_case and parsed with `@use_kwargs({'group_by': fields.Enum(GroupBy, load_default=GroupBy.category)}, location='query')`; `location` is omitted when it is the form/json default.
- Path parameters are parsed with `@use_kwargs({...}, location='view_args')` (`fields.Date`), not `dateutil.parser.parse(request.view_args[...])`.
- Enum args are `fields.Enum(StateEnum, required=True, validate=validate.OneOf([...]))`, never `marshmallow_enum.EnumField`.
- Bulk endpoints whitelist the compatible actions in the webargs validation (`validate.OneOf([...])`), not with early returns in the body.
- Input validation is a webargs validator: a module-level `_check_x` raising `ValidationError`, attached with `validate=_check_x`; never an RH helper that returns the value and raises `BadRequest`.
- An input combination that yields nothing (a date range containing none of the selected weekdays) raises `ExpectedError(_('...'))` from one shared check (`check_impossible_repetition(data)`) that every endpoint consuming the combination calls first; the check returns early on missing keys so partial payloads pass through.
- A presence check over request args (`all(x in args for x in (...))`) lists only the args the client always sends; optional ones are read with `.get()` so a request without them still takes the main branch.
- Do not re-implement framework behavior: `IndicoFlaskParser` already strips surrounding whitespace from request data.
- `@no_autoflush` goes below the webargs decorator.
- Celery tasks receive ids and reload the object (it may be gone when the task runs).

### Validation and derived state

- A validation query checks the whole input: compare `len(rows)` with `len(ids)` so filtered-out ids are rejected; submitted ids must exist, belong to the owning event and be accessible to the user.
- An unresolvable input never ends in a silent `return`: an unknown identifier raises `BadRequest('Unknown code')`, a lookup that finds nothing raises `NotFound('No registration found')`, each as an early guard.
- `BadRequest` for a wrong object type or state, `Forbidden` only for permission failures; the server rejects what the UI disables (attachments present, still pending).
- Deleting or disabling an item others depend on is refused with `NoReportError.wrap_exc(BadRequest(_('...')))`, including the parent section; no silent cleanup of dependents.
- References submitted by managers are validated in the schema with `self.context`: same parent (`Model.query.with_parent(parent).filter_by(id=...).first()`), no self-reference, no cycles (walk the chain with a seen set), no disabled or manager-only targets, and a per-type capability flag on the field implementation (`allow_condition`).
- Never derive server state from the partial payload the client sends (only changed fields arrive): merge into the stored data first, then resolve derived state (hidden fields) recursively from the merged data.
- The data of hidden fields is deleted and their `required` skipped; one shared utility does this for the model and the util, and `view_data` is for the frontend only.
- Field-type-specific behavior lives on the field implementation class (`get_data_for_condition`, `empty_value`), mirrored by the same-named function in the frontend registry; both docstrings state they must match.

### Lists and bulk actions

- Items a bulk action skips are reported, not silently dropped.
- Bulk actions touch only items in the applicable state; other states are skipped or covered by an explicit option (an action dropdown: remove, sync to default, custom value, plus a switch for the edge state).
- A bulk action offers only the actions whose outcome users expect for every selected item (bulk "reject" on a change proposal sends it back to the submitter: not offered).
- Never load a whole large table (all categories) to post-process it; use the denormalized data on the row (`detailed_category_chain`, undeferred to avoid O(n) queries) and compute on the server.
- A mode with its own filtering (linkable bookings) gets its own endpoint with bounded ints (`fields.Int(validate=validate.Range(min=0), load_default=0)`), not extra optional args on a paginated one; the server filters out what the user cannot act on, the client renders everything it receives.
- A new column in a management list is a list-generator item managers can toggle, not always-on markup.
- A second renderer of the same data (a PDF of an existing view) reuses that view's loader, extracted into a util with keyword-only options returning a dataclass; never a second query path.

### Object lookup and locators

- Object lookup in `_process_args` via `@use_kwargs({'obj': ModelField(Model, filter_deleted=True, required=True, data_key='obj_id')}, location='view_args')` with the kwarg named explicitly (never `**kwargs`), instead of `Model.get(request.view_args[...])`.
- Child objects named in view args resolve with `@use_rh_kwargs({'contrib': ModelField(Contribution, with_parent='event', data_key='contrib_id')}, location='view_args', rh_context=('event',))`, never `get_or_404` plus a manual parent check.
- Child objects loaded by hand go through the parent (`Model.query.with_parent(self.event).filter_by(id=...).first_or_404()`), one chained call per line.
- The model gets a `locator_property` including the parent id (on the concrete subclass when the base lacks it) and the RH declares `normalize_url_spec = {'locators': {lambda self: self.entry}}`.
- Alternate URL shapes come from locator variants (`@locator.filename`, `@locator.registrant`) referenced from `normalize_url_spec`; query args a locator provides are listed in `copy_query_args`.
- `@use_kwargs(..., location='json')` may decorate `_process_args` for a lookup from the payload.
- `rh_context` lists only attributes the RH actually sets; a context name copied from another module is removed.
- A field that reads its data from the RH context takes no constructor arguments for the same objects; use `@use_rh_kwargs(..., rh_context=(...))` instead of `parser.parse`.
- Reach the event through the object (`self.form_item.registration_form.event`), never `g.rh.event`; code reading `event.category` handles unlisted events (`category` is `None`).

### URLs and blueprints

- URL prefix follows the audience: `/admin/` only for admin-only RHs; JSON endpoints live under `/api/` on the display side and `/manage/<module>/api/` on the management side.
- The URL names the resource, no `/data` suffix; collection URLs are plural with a trailing slash (`/favorites/`), item URLs append the id; an action endpoint (`/custom-qr-code`) has no trailing slash.
- Nested API URLs name each level by its resource in plural (`/event/<id>/forms/<id>/registrations/<id>`), never a singular model name followed by an id.
- URL paths use hyphens (`/update-price`), never underscores.
- RH and endpoint names say what they do (`RHBookingOccurrenceLink`, `booking_occurrence_link`, `registrations_update_price` rather than `registrations_base_price`); an `Actions` suffix only when one RH covers several actions.
- A toggle is two RHs with two URLs (`/publish` POST+GET for the dialog, `/unpublish` POST), never one RH switching on `?publish=true`.
- Read-only endpoints are `GET`; `POST` only for mutations or large payloads (lists of selected ids).
- The blueprint `methods` tuple lists only methods a client uses; no `methods=('GET',)` (the default), no `PUT` added "for later".
- Blueprint URL strings are never wrapped: `_bp.add_url_rule(` then the full URL on its own line.
- An endpoint rename follows into every consumer (`url_for`, `indico-url:` imports, `fields.Function` URLs).
- Match the blueprint with `request.blueprint`, never `request.endpoint.split('.', 1)[0]`.
- Blueprint `url_defaults` callbacks that read `request` guard with `has_request_context()`; `url_for` also runs in Celery and the CLI.
- An endpoint deriving an artifact from an object's URL (a QR code for the event link) takes the object id, builds the URL server-side with `url_for(..., _external=True)`, inherits the object's base RH (`RHProtectedEventBase`) and lives under the object's URL prefix (`/event/<int:event_id>/share/qr/image`); no free-text URL parameter plus hostname check.
- Per-endpoint cross-cutting behavior (CORS) is declared with an RH class decorator (`@cors`, next to `@json_errors`) that stores a class attribute read by the view-function factory, never with a blueprint-wide URL regex registration; the error handler applies the same options so error responses carry the headers too. A decorator usable with and without arguments takes `(rh=None, /, **options)`.
- A file tied to an account is served by its own RH (`/user/data-export.zip`, `file.send()`, `NotFound` when absent) under the owner's access check; `signed_download_url` is for contexts without an owner.
- URL values shared by every endpoint of a blueprint come from `@blueprint.url_defaults`, never repeated in each `url_for`.
- Action endpoints without a resource payload (link, unlink, toggle, resend) are `POST`, never `PATCH` or `PUT`; `PATCH` only updates fields from a partial payload. Every `data-method` in the templates matches the blueprint `methods`.
- Endpoint names drop qualifiers the blueprint already implies (`email_survey_send`, not `api_email_event_survey_send`); when URLs move under `/manage/`, re-check the names too.

### Responses and redirects

- `Schema().jsonify(data)` over `jsonify(Schema().dump(data))`.
- An endpoint returns the fields the client reads, not the output of an existing heavy serializer filtered client-side.
- The response to a mutation carries everything the UI must refresh (`has_pending_invitations`), not only the list.
- When a dialog action changes what the list shows, return `jsonify_data(flash=False)` and reload the page so flashed messages appear after the reload.
- A POST that modifies data ends with `return redirect(url_for('.same_page'))`, never by rendering the page (F5 would resubmit).
- Templates receive lists (`.all()`), never query objects.
- Display logic belongs in the template, not in the renderer or RH.
- Page classes build breadcrumbs by overriding `_get_breadcrumbs` with `render_breadcrumbs(_('Calendar'), category=self.category)`; the last crumb is not a link, and the trail behaves the same on every crumb (no per-crumb target logic).
- Admin pages pass the side-menu item name to `WP*.render_template(tpl, 'item')`.
- A binary response never smuggles JSON in a custom header; return JSON with the base64 payload plus the data, or the file alone.
- `get_file_context` returns a tuple; an endpoint accepting several files declares `FilesField`.
- Service integrations get a flag in the response (`reset`) instead of a callback endpoint; a service-only endpoint checks `self.is_service_call`.
- A per-request interception that redirects users returns early when `request.endpoint` is unset (404), allows only an explicit list of endpoints (its own blueprint, `assets.*`, `*.static`, `auth.logout`, `core.contact`, `core.change_lang`) and redirects only plain page loads (`request.method == 'GET'` and neither `request.is_xhr` nor `request.is_json`), so API calls and form posts are not silently redirected.
- Field data rendered into a list cell, email or export goes through the field's friendly renderer; a list value never appears as its Python repr.

### Previews and sample data

- Previews use a lightweight mock object (`MockX(regform, first_name, last_name)`), not an unsaved model plus `self.commit = False`.
- When a preview needs the real model's properties, link the instance only to the form (never to the event or other persisted rows), fill the default personal data fields so the output does not look broken, and confirm in the SQL log that nothing is inserted.
- Preview sample data is the current user's name and email when a user is in context, otherwise dummy names and `test@example.com`; never `<FIRST-NAME>` markers or translated placeholders.
- Previews of generated images are cached with `@memoize_redis(3600)` on a module-level function.

## Signals

### Declaring signals

- Signals live in their topic module (`signals/affiliations.py`), named like the existing family; the importable name matches the string name (`x_data` / `'x-data'`).
- Docstrings state sender, kwargs, return value and combination semantics.
- The discriminating name goes in `sender` so plugins can connect for one sender only; the payload goes in kwargs.
- Signals pass the whole object (`tpl_data`) rather than a slice of it; the handler picks what it needs.
- Signals receive the parsed `data`, not `request.json`; an empty payload after plugins ran is a no-op, not `BadRequest`.
- Signal kwargs have no defaults: an absent kwarg is the normal case, the special case is an explicit `silent=True` (or `no_log`), never `log=True` that every handler must default itself.
- A signal that can short-circuit a check documents the contract: `True` skips, `False` denies with a generic message, `None` runs the default, `False` wins over `True`, custom messages come from raising `Forbidden` in the handler; "any return value skips the check" is rejected.
- A new core hook needs a core consumer; a signal already declared and documented stays even while nothing consumes it.
- Narrowing signals mutate the passed list in place; `values_from_signal(skip_none=True)` already drops `None`.
- No `isinstance` check on signal return values that `values_from_signal` already filtered; only unexpected types justify a guard.
- Core supports every registered handler of a hook: build the result from all of them, never take `[0]` of the signal results.
- A state transition performed by hand (a bulk action setting `complete`) still fires the state-change signal and notifies; pass `silent=True` when the generic log entry would mislead and log the action yourself.
- A signal already sent by the inner method is not sent again by the outer one.
- A new hook at a point where a core signal already fires extends that signal (a new kwarg on `send()`), never a parallel hook; propose the hook only when the signal cannot carry the data.

### Handlers

- Plugins register handlers with `self.connect(signal, handler, sender=...)` in `init()`, never module-level `connect_via`.
- A handler lives in the module of the work it performs, not the module that emits the signal.
- Handlers name the sender by what it is (`event`, not `sender`), declare each kwarg they read, keep `**kwargs` only for future kwargs, and never `kwargs.get()` a key the signal always sends.
- A handler that always yields exactly one item returns it instead of being a generator.
- Handlers of broad signals (`event.updated`) intersect the `changes` keys with the fields they care about (`set(changes) & fields`) and return otherwise.
- `event.updated` is not reliable for date changes (auto-extension by moving a contribution bypasses it); date-dependent sync handles `event.times_changed`, or a comment says why it is unnecessary.
- A handler on a per-registration signal checks that registration's own form flag, not an event-wide query.
- Plugins extend data returned by a hook (`qr_data.update(...)` with each handler's dict); they never replace it.
- A placeholder context whose signal handler declares kwargs no placeholder reads gives them defaults in the handler; call sites call `get_sorted_placeholders(context)` and `serialize()` without dummy `None` arguments.

### Plugin extension points

- An extension point where plugins contribute typed things (a name, a pattern, a lookup function) is a base class in core (`CustomTicketCode` with `name`, `regex`, `lookup_registration`) returned through one signal and read with `named_objects_from_signal`; not freeform dicts merged into a payload, and not two signals (one for setup data, one for handling).
- Abstract class attributes on a base class default to `None`, never to an example value (`regex = None`, not `regex = r'...'`).
- The payload built from registered handlers is a dict keyed by name (`{x.name: x.regex for x in handlers.values()}`), and the key is always present (empty dict when nothing is registered), never added conditionally.
- A getter built on `named_objects_from_signal` gets an `@signals.core.app_created.connect` handler (`_check_x_handlers`) that calls it once, so duplicate names raise at startup instead of on the first request.
- When plugin data moves onto an existing signal, trace every early return between the entry point and the `send()` call; a no-op update path that skips the signal silently drops the plugin data.
- An interceptable hook or signal stub exposed to plugins keeps `**kwargs` so handlers can receive extra context later without a signature change; not an unused parameter.

## Forms (WTForms)

### Validators

- Conditional validators use `inject_validators(self, 'field', [DataRequired()])` before `super().__init__()`; appending to `field.validators` afterwards may only mark the field required in the UI.
- Never append to `field.validators` or change `field.flags` in `__init__` (leaks into every instance); use `inject_validators` or `del self.field`.
- A dependent field hidden with `HiddenUnless('toggle', preserve_data=True)` does not also carry `DataRequired`: the preserved value may be empty while hidden.
- `HiddenUnless` comes first in the validator list so a hidden field skips `DataRequired`, and it compares against the enum member.
- No `Optional()` when it is the only validator.
- Never mutate `field.data` in `validate_*`; normalize in `process_formdata` or `post_validate`.
- Cross-field rules (requiring a toggle only when related content is set) live in a `validate_*` method on the form so the error renders inline; a `flash()` plus redirect in the RH loses everything the user typed.
- Uniqueness checks scope to enabled items and run again on re-enable; case-insensitive via `db.func.lower`.

### Validation rules and messages

- Multi-value errors name the offending items.
- `markupsafe.escape` every user string inside a `ValidationError` message (it renders as HTML).
- Whitelist validation of stored values adds the existing data (`field.object_data`) to the allowed set so a shrunk whitelist does not block saving unrelated changes.
- `NumberRange` bounds match the model constraint (`999999999.99`) and the field's intent (`min=0.01` when zero is a separate action) so the right validator produces the message; `Decimal('0.01')` from a string, never `Decimal(0.01)`.
- Credentials entered in a settings form are verified against the provider in `validate()` after `super().validate()`, only when they or the related identifier changed; the client returns an enum of outcomes and the form appends one message per outcome to the field it concerns.
- URL validation and normalization for one field lives in the validator class (or the schema), not in a shared `web/util.py` helper that both the form and the RH call.
- Forms referencing external accounts must load when the account disappeared; failing to save is fine.
- Rich-text fields that end up in emails: `[NoRelativeURLs()]` plus `TinyMCEWidget(absolute_urls=True, height=300)`.

### Fields and layout

- Field definitions sit with the other fields, one kwarg per line when long; new fields follow the wrapping style of the sibling fields (no formatter-style multi-line field in a form whose other fields wrap by hand).
- Order fields by how the user fills them (file, delimiter, then switches) and keep the ordering tuple in sync; check the rendered field order after overriding an inherited field.
- Relationships are edited through query fields (`IndicoQuerySelectMultipleCheckboxField`, `IndicoQuerySelectMultipleTagField`) so `populate_obj` assigns them; no id lists resolved by hand in the RH.
- Query field relationships already exclude soft-deleted rows; sort choices with `natural_sort_key`.
- A mode dropdown is an `IndicoEnumSelectField(enum=RichIntEnum)`; context-dependent titles go through `field.titles`, unavailable members through `field.skip` (`{Mode.inheriting}` on the root).
- JSON pasted by admins (service account credentials) goes through `JSONField(widget=TextArea(), empty_if_null=True)` so the JSONB column stores an object, never a string.
- Widgets that hide or show other fields (`HiddenUnless`) need the underlying input in the widget HTML, not rendered by React: `initForms` runs before the script.
- Removing a field in `__init__` (`delattr`) removes every sibling whose `HiddenUnless` references it.
- Several fields that persist into one JSON settings column are assembled by a `@generated_data` property; the form's `data` property drops the individual fields so `populate_from_dict` never sees unknown attributes.
- Per-event behavior is an event or room field, not a global plugin setting.
- Settings dialogs with several topics use `_fieldsets` on the form and `jsonify_form(form, fieldsets=...)`; the attribute is always `_fieldsets`, and a macro argument that duplicated it is removed once the form carries the data.

### Constructor and dynamic forms

- Values the client never changes are form constructor kwargs (`def __init__(self, *args, event, mode, **kwargs)`), not hidden fields round-tripped through the browser; never `kwargs.pop('x')`.
- The form takes the owning object as a keyword-only constructor argument.
- Never assign a field on a form class at runtime (shared globally); build a subclass per request with `type('_Form', (BaseForm,), {'field': field})` from a `form_class` property.
- Label text that depends on settings uses the same per-request subclass (`type('_Form', (IndicoForm,), {})`), never an empty label with the text in the template.
- A field added dynamically gets a one-line comment on the base form so its `validate_*` does not look orphaned.
- Dialog triggers are declarative (`data-ajax-dialog`, `data-href`, `data-method`, `data-title`) built with `html_params` in the form constructor, where the request context is available; not JS in the template setting `data-href` at runtime.
- A form only reached from a dialog is `methods=('POST',)`; it carries `submitted = HiddenField()` and overrides `is_submitted()` as `super().is_submitted() and 'submitted' in request.form`, so the first POST renders instead of validating.
- Single-use message strings are inlined in the `flash()` call, not exposed as properties.

### Labels and descriptions

- Drop descriptions that restate the label; keep the label on fields whose label is not rendered when sibling forms set it.
- Field labels inside a fieldset do not repeat the fieldset name (`Issuer ID`, not `Google Wallet Issuer ID`).
- Descriptions of provider identifiers state operational constraints (never reused across servers, changing it breaks updates) and known limitations.
- "Nothing selected means no restriction" is stated in the description; labels stay short enough not to wrap ("Filter by forms").
- A switch description states the effect ("If enabled, registrations in the X state ... will ...").
- Prices in labels and choices go through `format_currency`; a dialog changing a value shows the currency and pre-fills the current value.
- Every checkbox has a clickable label (an empty label is an a11y bug); a long sentence becomes a short label (`Accept terms`) plus the sentence as `description=Markup(...)`.

## Schemas (marshmallow)

### Field types

- Dotted attributes: `NaiveDateTime(attribute='occurrence.start_dt')`, not a `Function(lambda ...)`; no `attribute=` equal to the field name (`fields.Bool()`, not `fields.Bool(attribute='is_open')`).
- The enum type of a `state` field is the owning model's enum.
- Computed fields longer than a one-liner are `fields.Method` backed by a named `_get_x`, not `fields.Function(lambda ...)`.
- `fields.Pluck(RelatedSchema, 'attr', many=True)` over a `fields.Method` that maps a relationship by hand.
- Free-form metadata is `fields.Dict(keys=fields.Str())`; `null` rejected, empty is `{}`; typed dicts declare both (`fields.Dict(keys=..., values=...)`).
- `fields.List(fields.Nested(S))` rather than `Nested(S, many=True)` plus `data_key`; nested schemas pass `only=(...)`.
- `fields.Int(strict=True)` where a string must be rejected.
- Email address lists are `fields.List(LowercaseString(validate=validate.Email()))`.
- Free-text user inputs (names, affiliation, address, phone, comments) carry a max length on both the schema and the client.
- `url_for` inside a schema names the blueprint explicitly (`'event_contributions.manage_update_contrib'`), never a blueprint-relative `.endpoint`.

### Defaults and optional fields

- Mutable defaults are `load_default=lambda: []` (`load_default`, never `default`).
- `data['x']` for fields with `load_default` (the key is always present).
- Optional text fields take `load_default=''` or `None` and the client omits empty values (`nullIfEmpty`, `onlyIf`); no regex to allow "empty or 3+ chars", and a min-length validator that nobody needs is dropped.
- An optional URL setting is either `None` or a valid URL: the schema rejects `''` (or disallows `null` and defaults to `''`); never normalize at the read site with `value or None`.
- Defaults per field type are computed by one rule on the server and the client alike (`checkbox` -> `False`, text -> `''`, dropdown -> the option at `default`).
- A field the client only sends when a setting is on is declared conditionally inside the schema (`if legal_settings.get('x'): accept_terms = fields.Bool(required=True, validate=not_empty)`); an unconditional `required=True` fails validation whenever the feature is off.
- Settings schemas loaded with `partial=True` never mark fields `required=True`.

### Validation

- `@validates_schema(skip_on_field_errors=True)`, written explicitly even though it is the default.
- `ValidationError(_('msg'), 'field')`; named placeholders in multi-value strings.
- A rule depending on another field or a setting (reason required unless linked) lives in `@validates_schema` on the schema, never on an RH base class; on edit it reads the object from `self.context['booking']`, on create the payload (`booking.links if booking else data.get('link_id')`), never both.
- A `@validates_schema` check never repeats what a field already validates; no hand-written type checks (`isinstance(x, list)`) on data the field type already rejects.
- A single-field truthiness check is `validate=not_empty` (or `validate_with_message(bool, msg)`) on the field, not a `@validates` method; `validate=not_empty` over `Length(min=1)`.
- Fields holding URLs validate as URLs.
- A validating field returns the raw value (the pattern string), not a derived object (a compiled regex); compile to validate and discard.
- A `ValidationError` built from a library exception catches the class the library raises (`re.error`) and wraps it with a translated label (`_('Invalid regex: {}').format(exc)`); an exception class that cannot occur is not listed.
- A validator resolving a reference returns early on an empty value, then raises `ValidationError('Invalid file')` (no i18n) when it does not resolve; it never passes silently and never drops conditions an earlier guard established.
- A string setting with a closed set of values gets `validate=validate.OneOf([...])`; an enum is overkill for two values.
- A closed set of string values accepted by several endpoints is one module-level tuple (`WEEKDAYS`) reused in every `validate.OneOf(...)`, in the model's CHECK constraint and in derived lookups (`WEEKDAYS[dt.weekday()]`); never a literal list repeated per field.
- A list field over a closed set validates its items (`fields.List(fields.Str(validate=validate.OneOf(WEEKDAYS)))`) on every args dict and schema that accepts it, plus a `@validates` duplicate check (`len(x) != len(set(x))`, plain `ValidationError('Duplicate weekdays')`, no i18n); the database carries matching CHECK constraints.
- Field settings with a cross-field rule (`maximum >= minimum`) need a schema class via `setup_schema_base_cls`, not a `setup_schema_fields` dict.
- Backend regex validation mirrors the frontend one.
- Options whose only consumer is the source module are dropped when a field is copied; an args schema is not reused across modules when its validators encode the source module's rules.

### Hooks and normalization

- `@pre_load` hooks `deepcopy` `data` before mutating nested dicts and guard missing keys (`if 'attributes' in data and 'type' in data`), with a comment when a library (`OneOfSchema`) forces the shape.
- Normalization that depends on another field (clearing `recurrence_weekdays` unless the repetition is weekly) is a `@post_load` hook on the schema, never a util helper called from the RH.
- A `@post_load` hook enforces the invariant positively (`if data['repeat_frequency'] != RepeatFrequency.WEEK: data[...] = None`), not the one transition the author tested (`== MONTH`).
- `@post_load` and `@validates` hooks are `_`-prefixed and named after the invariant (`_weekdays_only_weekly`, `_check_weekdays_unique`), not after a scenario (`handle_monthly_repetition`).
- A new column that older rows lack is backfilled at dump time with `@post_dump(pass_original=True)`, derived from existing data (`WEEKDAYS[booking.start_dt.weekday()]`), in every schema that exposes the field (details and calendar alike) so the client never special-cases legacy rows.
- Nested objects the viewer may not access are blanked in `@post_dump(pass_original=True)` (`data['object'] = None` after `can_access`), not filtered in the RH; the client renders "Details hidden - no access".

### Dumping and access

- Schemas limit what is accepted and returned; a summary endpoint never embeds details of linked objects (titles leak), details load from their own endpoint.
- List APIs returning many rows expose foreign keys (`link_id`, derived by `SQLAlchemyAutoSchema`) rather than nested objects whose access would have to be checked per row; details load lazily from the item dialog.
- Nesting a new relationship in such a schema is checked with `bin/utils/db_log.py` and gets a `joinedload`.
- Collections are serialized with `Schema(many=True).dump(items)`, the schema instantiated once outside the loop.
- A detail schema reused for a list endpoint excludes its heavy nested fields (`Schema(many=True, exclude=('registration_data',))`), and the list query eager-loads what the remaining fields read (`selectinload('data').joinedload('field_data')`, `selectinload('tags')`, `undefer(...)`).
- Counts in a schema never come from `len(relationship)` (`fields.Function(lambda r: len(r.registrations))`); they read an existing `column_property` (`existing_registrations_count`) or a new one, and the list RH undefers every count the schema dumps.
- A schema field dumping a lazy relationship with nested rows becomes a `fields.Method` calling a query helper that carries the eager-load options.
- Dump every schema against populated fixtures and read the output; a list of `null`s or an empty mapping means the field reads the wrong attribute.
- Fields and `HACK` getattr workarounds the client no longer reads are removed.

### Exports

- A user-facing export contains only what the user sees in the UI: no registration tags, no manager-only fields or sections (`field.parent.is_manager_only`), no internal `meta` blobs, no system-level configuration.
- For an association keep the user-specific data with the related object nested under it.
- A per-user export walks every relationship on `User`, legacy ones included, and both directions of a relation (`reservations` and `reservations_booked_for`); a new relationship on `User` lands in the personal data export schema.
- Denormalized pairs are both exported (`affiliation` and `affiliation_link`).
- Content the user authored in another entity (note revisions) is its own section with raw `source` and `render_mode`, linked by id.
- Soft-deleted rows stay in a personal data export with `is_deleted` exposed.
- An archive export writes one file per top-level section (`{key}.yaml`); member names are relative (no leading `/`), user-provided names go through `secure_filename` with the row id prefixed (`{id}_{stem}{suffix}`), and a blob referenced from several rows is written once; extract into an empty directory to verify.
- `export.yaml` orders the rows topologically so idrefs resolve on import.

## SQLAlchemy And Migrations

### Columns and constraints

- `#:` column docs; keep the blank line between columns and relationships.
- Datetime columns use `UTCDateTime`, date-only columns `db.Date`; never bare `db.DateTime`.
- Pick NULL or empty string, not both; NULL gets `CheckConstraint("col != ''")`.
- A nullable array column has `default=None`, never `default=[]`: `NULL` means not applicable, and a CHECK constraint ties non-NULL to the states where it applies (`(recurrence_weekdays IS NULL) OR repeat_frequency = 2`), interpolating the enum member in the model (`{RepeatFrequency.WEEK}`) and the literal in the migration.
- A special case in a diff or log routine (`old == 'None'`, skipping a field when `new is None`) points at a wrong default upstream (`default=[]` on a nullable column); fix the default to `None` and delete the special case.
- An array column over a closed set gets CHECK constraints for membership (`col::text[] <@ ARRAY[...]::text[]`) and uniqueness in model and migration alike.
- Encode invariants as CHECK constraints (`internal_name` required when `personal_data_type` is set) so edge cases such as cloning cannot produce bad rows.
- Constraints exist in both migration and model, or in neither (drop a uniqueness check when duplicates are harmless); `indico db_diff` must print nothing.
- Uniqueness scope matches the product: form or event level, never instance-wide constraints that collide on large installations.
- Partial-index `WHERE` clauses must be justified.
- `index=True` on the column instead of a separate `op.create_index`.
- Do not store values derivable from another stored value (a server name or domain next to its URL); parse them when needed.
- Configuration the server must query or validate (references to other rows) lives in real columns with foreign keys, not inside a JSON `data` blob.

### Relationships and properties

- New FK to `User`: backref, alphabetized backref list, `merge_users` handling.
- Association tables declare `ondelete='CASCADE'` on both foreign keys.
- A relationship to `File` never cascades deletes (the blob stays orphaned); copy an existing `File` relationship (`lazy=True`, named backref) and release with `file.claimed = False` so the cleanup task removes it.
- `__repr__` returns `format_repr(self, 'id', 'state', 'file')`, never a hand-built f-string.
- Switching stored text from plain to HTML uses `RenderModeMixin` with a `render_mode` column (legacy rows stay plain text, new rows HTML), never a destructive data migration.
- Properties never make API requests, modify remote data, or walk the parent chain with one query per level; that is a method or, for inherited values, a CTE `column_property`.
- Readiness is a boolean property (`configured`), not callers testing an internal attribute.
- A derived check used in several places is a model property (`is_condition` for "others depend on me", `is_conditional` for "I depend on another"); `column_property` only when it must be filtered on or loaded in bulk.
- A per-row property that touches a relationship (latest comment date) turns a fixed number of queries into one per row: compute it in SQL as a `column_property` with a correlated scalar subquery, registered in a module-level `@listens_for(orm.mapper, 'after_configured', once=True)` function (never inside the class), `deferred=True` plus `undefer()` when few views need it; a real column updated on every write is the fallback.
- Configuration children inherit uses a three-state `RichIntEnum` column (`InheritableConfigMode`) next to the JSON settings column, with CHECK constraints `(id != 0) OR (mode != inheriting)` and `(mode != enabled) OR (settings != '{}'::jsonb)` in model and migration.
- The effective inherited value is a recursive CTE classmethod mirrored from `get_protection_cte`, exposed as `column_property(query, deferred=True, expire_on_flush=False)` in `_mappers_configured`.
- Search over text columns: prefix match over substring, skip words under 3 chars, GIN/FTS index in the migration, results cached with `memoize_redis(ttl, versioned=True)` and the version bumped on writes.

### Queries

- `Model.query` over `db.session.query(Model)`; `query.has_rows()` over `count().scalar()`; a `has_x` helper returns a bool via `.has_rows()`.
- Lookups: `Model.get_or_404(id, is_deleted=False)`; `filter_by(date=date)` over `filter(Model.date == date)`.
- Never `filter_by` after a `join`: it applies to the last joined entity and reads as a filter on the queried one.
- Join via relationships (`.join(Model.rel)`), `.with_parent()` where it fits; `contains_eager` after an explicit join.
- Many-to-many membership is filtered through the relationship (`.any(User.id == user.id)`), never the association table.
- Query the subtype class (`RegistrationFormField`) for subtype-only constraints.
- Filter where data is loaded (query criteria), not with a check afterwards; remove mechanisms the filter makes redundant.
- Query criteria are built per branch as full expressions (`(A > x) & (B <= y)`), never by mutating `criteria[0]` with `db.and_`; prefer inclusive comparisons over client-side offset hacks unless pagination needs them.
- `.one()` on lookups that cannot miss (soft-deleted rows still exist); `.first()` plus `if not x` when they can, never `.one()` inside a `try`.
- No defensive `- {None}` or `or {}` without a reproducible case, and a comment when one exists.
- First and last of an ordered relationship come from one ordered query indexed `[0]` and `[-1]`, never two `next(...)` scans over differently ordered iterations; the emptiness guard is `if not any(occ.is_valid for occ in ...)`.
- One query for the set, then membership in Python; never a query per candidate inside a loop, and one query per bulk sync, not per item.
- Removing a relationship filter (`primaryjoin`) means auditing every consumer of that relationship.

### Eager loading

- Eager loading is measured on a large event, per list: `selectinload` when the relationship multiplies the parent rows (many persons per contribution), `joinedload` when the child is the queried object.
- `selectinload` for a to-one relationship on a long list keeps the main query small; `selectinload` for collections.
- A `load_only(...)` must include the FK columns (`own_room_id`) of relationships read later, or the eager load silently falls back to one query per row.
- Pair `joinedload(rel)` with `.raiseload('*')` so any lazy load surfaces during testing; `joinedload('rel').load_only('id', 'title')` on joined parents; deep chains go in a local strategy variable.
- When the filter joins or uses `.any()` over a relationship you also eager-load, select the ids first and load the rows by `Model.id.in_(ids)` with the loader options.
- Check the SQL log over fully populated fixtures; count queries on a large event before and after a list change.

### Query style

- Multi-line queries: either `(` on its own line or `(Model.query` with chained calls aligned under it; match the style of the adjacent queries in the file.
- `Model.query` first, one `.filter(...)` with one criterion per line, `.has_rows()` last; one chained call per line.
- A query that fits on one line stays inline in the `if`; otherwise it gets its own statement.
- Multi-line boolean SQL criteria use `and_(a, b, c)`; `a & b & c` only when it fits on one line.

### Soft deletion

- Filter soft-deleted parents at every level, with a test per level.
- An object that produced artifacts (a template behind generated documents) is soft-deleted: `is_deleted` column, `get_or_404(id, is_deleted=False)`, every listing filtered.
- Backrefs to soft-deletable rows use a `primaryjoin` excluding deleted rows instead of `cascade='all, delete-orphan'`; filtering the relationship itself replaces every `if not x.is_deleted` at the call sites (`with_parent`, `.any()`, model properties): none of them stays.
- No `is_deleted=False` filter on a `with_parent()` query whose relationship already excludes deleted rows.
- Files linked to a soft-deleted object stay `claimed` (unclaiming deletes them); only a hard delete (`*, soft=False`) unclaims.
- A unique constraint on a soft-deletable table becomes a partial unique index (`postgresql_where=sa.text('NOT is_deleted')`).
- The `downgrade` of a soft-deletion revision deletes the soft-deleted rows and their children in SQL before dropping the column.

### JSON columns and cloning

- Data read from a model's JSON column is never mutated while consumed (no change detection means silent persistence on the next flush); build a filtered copy.
- Mutating a JSON column on a persisted object needs `flag_modified(obj, 'data')`.
- `db.session.add()` is redundant for objects already in the session; build children with `parent=section`, not `parent_id=section.id` plus a flush.
- A datetime that travels through a JSON blob (registration request data) is stored with `.isoformat()` and parsed back with `datetime.fromisoformat` where consumed, with a one-line comment saying why it is a string there.
- New relationships on a cloned model update its `EventCloner` (`uses`, mapping through `shared_data`, skip when the dependency was not cloned).
- Row references between items of the same parent: the cloner maps old ids to new ones in a second pass after all items exist.
- Ids stored in JSON data that reference event objects are remapped in the cloner through `shared_data`, reset to `[]` when the dependency cloner did not run, and entries whose target no longer exists are dropped, never left as `None`.

### Alembic revisions

- One alembic revision per PR: schema changes added during review are folded into the existing revision and its title updated to cover the whole change.
- `down_revision` points at the current head when the PR is opened and again before merge; the revision is rebased at merge (filename date, `down_revision`).
- The revision title, docstring and filename name the schema change (`add_accepted_terms_dt_users`), not the feature ("force accepting terms of service"); a column rename during review renames the revision too.
- The revision docstring title is capitalized ("Add ...") with a blank line after it.
- Commented-out statements from earlier iterations and the autogenerated `# ### commands auto generated by Alembic` comments go.
- `op.add_column` calls fit on one line when under 120 characters and longer ones wrap; no 150-column lines; the closing parenthesis of `op.create_table` sits on the last argument line; SQL in triple-quoted strings is indented under the call.
- Never name indexes by hand (`op.create_index(None, ...)`); `downgrade` does not drop indexes or CHECK constraints of a table or column it drops.
- `downgrade` recreates every index and check constraint `upgrade` dropped, and uses the project types (`UTCDateTime`, `PyIntEnum`), not `postgresql.TIMESTAMP`.
- Renaming a column renames its FK constraint and index too (`ALTER TABLE ... RENAME CONSTRAINT fk_t_old_users TO fk_t_new_users`, `ALTER INDEX ... RENAME TO`) in both directions.
- `column_property` changes that back an index update the index in `upgrade` and `downgrade`.
- A NOT NULL column added with `server_default` gets `op.alter_column(..., server_default=None)` right after.
- A new column whose default is `inheriting` sets the root row to a non-inheriting value in the migration (`UPDATE ... WHERE parent_id IS NULL`, `# noqa: S608` on SQL built from enum values) and in `create_all_tables`.
- Moving a relation (links from reservations to occurrences) renames the existing table instead of create plus drop: rename table, add the new column with its FK and index, migrate data with `UPDATE ... FROM`, drop the old column; rename the sequence, PK, indexes and constraints to the new table name with `op.execute('ALTER ...')`, mirrored in `downgrade`.
- Until the data migration exists in both directions, destructive steps stay commented out so testers keep their database.

### Data migrations, enums and SQL functions

- Data migrations fetch the id of an inserted row with `RETURNING id`, never an uncorrelated `(SELECT id ... ORDER BY id DESC LIMIT 1)`; related ids are collected as a tuple and updated in one `WHERE id IN %s`.
- Data migrations never hardcode the system user id; use `(SELECT id FROM users.users WHERE is_system)`.
- Boolean SQL reads `NOT is_undone`, not `is_undone = false`, in migrations and `CheckConstraint` alike.
- No native PostgreSQL enum in a migration, also inside `ARRAY`: `PyIntEnum` or `sa.Enum(..., native_enum=False)`; `ALTER TYPE ... ADD VALUE` cannot run in the same transaction.
- Revisions never import model enums; they define a private `IndicoIntEnum` copy (`class _State(IndicoIntEnum)`) after the imports, matching the model enum member for member, or interpolating a member into a `CheckConstraint` string yields `State.success` instead of `2`.
- A SQL function a constraint needs lives in `indico/core/db/sqlalchemy/custom/<name>.py` with a `create_<name>_function(conn)` guarded by an `information_schema.routines` lookup, is registered in `_before_create`, and the migration runs the same `CREATE FUNCTION` with `op.execute` before the constraint and `DROP FUNCTION` in `downgrade`.

## Config And Startup

### indico.conf and startup

- Plugin keys under `PLUGIN_<NAME>_<KEY>`; collisions raise, never warn.
- Config is validated in `IndicoConfig.validate`; plugin-dependent checks wait for `IndicoPlugin.init()`.
- Derived config values are `@property` on `IndicoConfig` (or computed in `_postprocess_config`), never added to `DEFAULTS`; absolute URLs via `urljoin(self.BASE_URL, path)`, never `'http' in url`.
- A global kill switch (`ENABLE_X`) hides UI and gates every consumer; it never deletes stored configuration when toggled off.
- Behavior the admin may want either way (verbose vs generic login errors) is a config option defaulting to the current behavior; never set it unconditionally, never fail startup when it is missing.
- Config-provided credentials disable and mask the matching admin UI fields; all credentials of one integration are configurable the same way; file-based secrets stay optional.
- Log-type or derived data gets its own storage setting (default `None`), never `ATTACHMENT_STORAGE`, which holds long-term user content.
- An image an external service shows in a different context (a wallet card) gets its own URL setting with a matching `ABSOLUTE_*` property instead of reusing the site logo; the bundled default fits that context.

### Settings proxies and capabilities

- Setting proxies are named by scope (`global_event_settings`), never `misc`; `event_settings` is reserved for per-event plugin settings.
- A cheap setting read goes inline in the condition (`if editing_settings.get(self.event, 'service_url'):`), no local variable.
- `settings.delete('a', 'b')` removes several keys in one call; no one call per key.
- A setting holding a date or datetime gets a converter on the `SettingsProxy` (`DateConverter` next to `DatetimeConverter`); callers never parse the stored string themselves.
- A wrapper that rebinds a proxy forwards every constructor argument (`acl_names`, `converters`) and gets a test covering ACLs and converted values; a fix to stored setting values ships a migration mapping both directions.
- Capability flags of multipass objects (`supports_member_list`) are honoured; the section stays with a `message_box('warning')` saying why the data is unavailable instead of disappearing.
- Derive capability from the data (stored attachments count equals attachments count) rather than from a config flag; do not block actions on a flag that only gates creation when the data already exists.

## Logging, Flashing, Errors

### Loggers and messages

- One module-level `logger = Logger.get('module.submodule')` named after the module path; no inline `Logger.get()` with a broader name.
- Logging placeholders match the argument count; `%s` for data and for the exception itself (no `str(exc)`); `%r` of an object already names its parent.
- Static variants go in the format string (meeting vs webinar) for Sentry grouping, never interpolated; `# noqa: G004` on static f-strings.
- A log message names the operation that actually failed (the GET checking existence, not the create that never ran).
- Log arguments carry only what helps (no event id when it cannot be acted on).
- Failed lookups of a username log at `info`, wrong passwords at `warning`.
- Actions an admin runs on another user's data log target and actor at `info` (`'... for %r triggered by %r', self.user, session.user`).
- External sync code logs successes at `info` with the Indico ids and emails involved, so an action can be traced later; failures alone are not enough.
- Expected external rejections are handled, not logged as warnings on each run.

### Event and app log entries

- Admin-level and global changes are logged with `AppLogEntry.log()` (static, mirrors `Event.log`); nothing is monkeypatched onto `app`.
- Models get a `log()` method that prefills `meta` with a namespaced id key (`editing_tag_id`, not `tag_id`, so log filters never mix objects of two modules) and, for objects owned by an event or a category, a `log_realm` property.
- Every mutation of the object (create, clone, update, delete, publish, unpublish) is logged with the relevant flags in `data` (`Published`, `Notified`); log before `db.session.delete(obj)`, not on the deleted object.
- State changes that must be logged go through explicit operations (`grant_admin(user)`, `revoke_admin(user)` in `operations.py`), never through property setters; manual and automated changes log separately.
- Operations take `*, extra_log_data=None` and merge with `{**log_data, **(extra_log_data or {})}` or `dict(extra_log_data or {})`; never mutate the caller's dict.
- The log module is the object ("Registration", also for a fee change); cross-object actions (a booking linked to an event) are logged on the event with ids and times in `data`, times in the event timezone.
- Log only actual changes: compute added/removed before mutating; items whose value did not change are left out of the entry and the count; state changes caused by the action are logged too.
- Generic logging hooks honor `quiet=True` and the object's `logging_disabled` state (event creation, cloning); implicit side effects (submitter rights on speakers) are logged quietly or not at all.
- Settings pages log changes: `changes = {k: (old[k], v) for k, v in form.data.items() if old[k] != v}`, then `AppLogEntry.log(..., data={'Changes': make_diff_log(changes, log_fields)})`; the summary names the single changed field or says "Data updated".
- `make_diff_log` field specs give `{'title': ..., 'type': 'string'}` for strings and pass enum members raw; extend `make_diff_log` when a new value type appears.
- Settings stored in one JSON column are logged per key (expand the `(old, new)` pair into one `changes` entry per key with typed `make_diff_log` fields); secrets are replaced through a `convert` callable with a hash marker (`<hidden:{crc32}>`), never written in full.
- A field that belongs to an existing logged group (weekdays under the repetition) joins that group's tuple (`repetition_fields`) so the log says the group changed; no separate pretty name for it.

### Log entry content

- Log summaries are short ("Added to group {name}"); titles say "Update", not "Edit", for changing a value.
- Ids go in `meta` for filtering, not in the text; no extra `meta` keys that break existing filters.
- Log `data` stores useful detail (attachment filenames), not a bare count; keys are human-friendly (`'User ID'`) and say what they hold.
- Two values are two `data` keys, never squeezed into one; hierarchical titles use a shared helper and separator.
- Keys without a value (`IP` outside a request) are omitted, not set to `None`.
- Email log records `alternatives` so re-sending reproduces the original multipart message.
- A limit that truncates output sets a flag on the row (`max_size_exceeded`), logs a warning with the object, and the notification says what was left out and how to retry with less.

### Flash messages and user-facing errors

- Two messages mean two `flash()` calls behind an `if`, not one call with a conditional expression.
- A bulk operation that cannot decide for some items (several review tracks, no unique candidate) skips them and flashes a warning with the count.
- No `flash()` in service methods or signal handlers (cloning, Celery); log instead.
- Flash with `ngettext`, subject first ("Registration fee has been updated for {} registrations").
- Errors say how to fix; "not allowed" over "not valid"; end-user warnings are one concrete sentence.
- Messages no end user can see get no i18n: internal errors (`'Invalid state'`), system-level errors (an admin disabled a feature), a `ValidationError` on an input the UI never produces.
- A failure email says "due to an error", not only that it failed.
- Provider error bodies never reach the user: `resp.raise_for_status()` plus a decorator (`@handle_http_errors()`) that logs a warning and raises `ServiceUnavailable(_('Could not generate ticket'))` from `RequestException`; no `if status_code != 200: raise BadRequest(response.text)` chains.

### Exceptions

- A state that cannot happen fails loudly with `assert` (`case _: assert False`, a template missing `<body>`) or a plain `Exception` (logged, visible to admins); never a warning log, `NotFound` or another HTTP error that reaches the client as a silent 4xx, and no fake default objects (`{'id': 0, ...}`).
- Catch only the exception class the call raises (`HTTPError`, `StorageError`, `OSError`), never bare `Exception`; wrap only the call that can raise, not the surrounding block.
- `raise ... from exc` when wrapping an exception.
- Do not catch unexpected external errors just to log them; an uncaught exception is more informative and crashes nothing.
- Model methods raise `ValueError` (plain f-string) for states they cannot handle, as a catch-all so a new enum member fails loudly; HTTP exceptions are raised only in the RH, which wraps the model error with `NoReportError.wrap_exc(exc)` and checks the user-facing precondition itself.

## External Services And Performance

### API clients

- An API client is scoped to the long-lived parent (`Manager(event)`); per-item objects are method arguments.
- Client methods read their own configuration (`self.settings['issuer_id']`) and build identifiers through one helper instead of threading ids through every signature.
- Constructor state comes from a helper returning values (`self.credentials, self.http_client = self._load_credentials()`), never `self.x = None` placeholders plus a mutating `auth()`; constructor arguments only read inside `__init__` are locals.
- Match external types exactly; normalize with a quirk comment.
- Check both members of parallel API families (meeting and webinar).
- Provider defaults are verified (`approval_type`).
- Provider fields with semantic meaning (`gate`, `seat`) are not repurposed for custom content; use the provider's template override.
- A provider constraint gets a comment and a UI warning.
- When a library kwarg is misspelled and a correctly spelled alias exists, use the correct one; when only the misspelling exists, open an upstream issue proposing the fix with a fallback for the old name.

### Provider responses and errors

- An external service may answer with an empty body; parse with the schema only `if resp.text`.
- `resp.json()` sits inside the same `try` as `raise_for_status()` and the handler catches `(requests.RequestException, requests.JSONDecodeError)`; a 200 with a non-JSON body must not raise.
- Side-effect syncs triggered by an unrelated action fail silently (`silent=True`) with a logged warning so the main action succeeds; a 404 on the remote object is a no-op.
- Re-fetch after a PATCH when the provider drops values silently.
- A PATCH payload rebuilt from current data sets cleared keys to `None` explicitly, otherwise the provider keeps the stale value.
- Bypass cached tokens (`force=True`) when verifying scopes or permissions.
- Verify required scopes by exercising every API call (status updates, batch endpoints) on a real tenant; error messages list only the missing scopes and never propose legacy scopes unless already in use.

### Sync and lifecycle

- Sync features handle the full lifecycle: created, deleted, state changed (including reset to pending), parent deleted, room created, option enabled on an existing room (sync existing items then).
- Before pushing a full set, fetch the provider's current list and send only the difference.
- Bulk changes within a request are queued in `flask.g`, flushed once in `signals.core.after_process`, using the provider's batch endpoints.
- No O(n) external sweep per request: a daily Celery task, a scoped cache with TTL above the interval, a per-item fallback.
- Record that a remote object was created (its id in an `EventSettingsProxy`) so later handlers skip API calls when nothing was created and a query can list affected events; "in use" derives from that record, not from counting registrations.
- Remote artifacts link back to the Indico pages (`event.external_url`, `url_for(..., _external=True)`).
- Matching an external account: `find_enterprise_email(user)` first, registration email as fallback; lowercase once at the source (the DB already enforces lowercase on Indico emails).
- Optional provider settings are read with a default (`settings.get('locked_fields', ())`); exclusions that always apply (`- {'email'}`) are documented where the setting is.
- A locking rule never overrides an explicit admin action (an admin-desynced field stays desynced) and a field with no provider data is never locked, or signup breaks.

### Caching and query counts

- Expensive work inside a send loop (template module, agenda query) is computed once or memoized with `memoize_request`.
- `@memoize_request` over hand-rolled `flask.g` caches; drop a cache that never hits; deduplicate within a request through `flask.g` only when a memoized function does not fit.
- `@memoize` is process-wide and forever; anything derived from database state uses `@memoize_request`.
- Deterministic pure functions called in loops (`generate_contrast_colors`) get `@functools.cache`; cheap recomputation beats a conditional cache (no premature optimization).
- Compare query counts on a production-size event before and after a list change or a second renderer; count, do not guess.
- Accepted query spam (a `can_manage` per template) gets an `# XXX` comment with the reasons it is acceptable (admins short-circuit, bounded row count).

### Emails and background jobs

- `send_email(make_email(...))` in new code; the `email_sender` decorator is legacy.
- New emails are text/plain; HTML only as multipart with a separate text template, or with `html_to_markdown(..., inline_links=False)` producing the plain alternative. `EmailMultiAlternatives` is safe for plain emails too.
- Custom emails render through `emails/custom.html`.
- Inserted content goes inside `<body>`, with a separator (`<hr>`, `-------------`) between preface and original.
- Recipients are built as sets (`bcc = {session.user.email} if copy else set(); bcc.update(cc)`), and the UI says BCC when the code sends BCC.
- Keep related kwargs together in the call (`connection=` last).
- Emails sent from a Celery task render inside `with user.force_user_locale():`.
- Code reachable from the CLI, Celery or signal handlers uses `session.user if session else None`; exercise it through the `indico` CLI and the Celery path, where no request context exists, not only "send now".
- Notifications pick the user who performed the action (the revision's author), not the first revision's author; check with two contributors acting in turn.
- The notification email links to the page that offers the download, not to the file.
- A long-running job (an export) runs in Celery and emails the user when it finishes; no client polling loop.
- A per-user background job is unique: a running one blocks a new request, a finished one is replaced and its file released.
- A feature that claims a stored file owns its lifecycle: a scheduled task removes stale ones after N days and the row's state records the expiry.

## Security

### Input and output handling

- Escape user strings in HTML messages; never `| safe` on user content: `sanitize_html` or a render-mode `Markup` wrapper. Plain-text previews render no HTML at all.
- User-authored templates render in `SandboxedEnvironment(autoescape=True)`; `TemplateSyntaxError`, `TemplateRuntimeError`, `SecurityError` and `LookupError` become `UnprocessableEntity`.
- User-supplied regexes combined with `|` are each wrapped in `(?:...)`.
- User-provided names never become path components: match against a whitelist (`dir.glob('*.yaml')`, compare `stem`) and derive later paths from the matched entry so static analysis sees no tainted path.
- A redirect target from the request is never validated with `startswith('/')` (`//evil.com` passes); store the return path in the session and redirect from there, so no user-provided URL reaches `redirect()`.
- Images from users: open with Pillow, catch `OSError`, allow `{'jpeg', 'png', 'gif', 'webp'}` by `pic.format`; never trust MIME type or extension, never `Image.OPEN` (lazy), never user SVGs in PDF rendering (the URL fetcher follows embedded URLs); guard `event.has_logo` before reading the logo.
- Image-like user input in template custom fields is restricted to the internal scheme (`event://`) even when a URL fetcher would reject the rest; defense in depth is accepted.
- Secrets from config never reach the browser; no signatures in logs.
- Standard primitives for hardening: `hmac.compare_digest`, `secrets`.
- Scanner findings need a proof of concept or a reason; cheap hardening (`parseInt` on an id from the URL) is still accepted.

### Uploads, signed links and auth checks

- Signed file links via `File.signed_download_url` and `RHFileDownload`; check `UploadFileMixin` before writing an upload handler.
- Checks that hold for every upload (empty files) go in the mixin's `_process`, not one subclass.
- Upload size is checked after `f.save()` (large uploads are buffered to disk, `getbuffer()` breaks) and a rejected file is `f.delete()`d since it already sits in storage.
- Never put a signed (expiring) link in an email: use an endpoint protected by the recipient's token (registrant locator) or attach the file.
- Anything that signs values inside `url_for` (a URL converter) must be opt-in (`_sign=True` kwarg stored on `g`), because the URL signing endpoint builds URLs for arbitrary endpoints; a test asserts that endpoint rejects underscored args; cache-busting slugs in URLs stay.
- A resource an external service must fetch from a restricted object (an event logo) is exposed through a signed URL (`secure_serializer.dumps(self.event.id, salt='event-logo-download')` as a `token` query arg checked in `_check_access` before the normal check), never by requiring the object to be public.
- Security checks (password strength, pwned passwords) are never `@make_interceptable`; extra checks go through the signal they already fire, and weakening them is not offered.
- Security code never guesses (which form field is the identifier); when the information is not available, add an explicit attribute upstream (in the library) and wait for the bump.
- A global rate limiter check runs after form validation, never in a way that locks every user out once hit.

## Behavior Changes

### Opt-in and defaults

- Changes to existing workflows are opt-in per form, off by default, or narrowed to the unambiguous case.
- Defaults only where they are what the user would choose; a recurring object is created only when the span needs it (`RepeatFrequency.NEVER` for a single day), defaults never force repetition.
- Features needing extra provider permissions get two switches: plugin-level `allow_x` (validated against the granted scopes at save time) and per-room `x` shown only when allowed; both default off.
- Related provider recommendations go in the setting description, not enforced; the description links to the README section instead of listing scopes.
- Forbid configurations that multiply edge cases (a room with registration enabled attached to several events) instead of supporting them.
- An option that has no effect in a mode is hidden in that mode; a client-side toggle that only hides inputs still needs the server to ignore their values.
- A manager editing a registration never fills untouched fields with their defaults; defaults apply only when the registrant submits, so unanswered fields stay visibly empty.
- The "nothing selected" shape per field type is `empty_value` on the field implementation (`{}` for choices, `{'choice': None}` for accommodation, `None` for booleans), distinct from `default_value`.
- A locked value is written from its source (`value = invitation.email`), not by marking the field read-only and leaving it blank.

### Same behavior on every path

- Every entry point building the same payload gets the behavior (user form, manager on-behalf, bulk); every RH that builds a payload dict from args for the model (`new_booking_data`) includes the new field.
- A field that changes computed children (occurrences) lands in every set and comparison that decides recomputation (`populate_fields`, `occurrence_fields`, `has_same_dates`, `should_split_booking`); walk the edit flow changing only the new attribute.
- Validation applies identically on every path (import modes, API, UI).
- A setting the UI enforces is enforced server-side too, and the create and edit paths behave the same.
- Walk state machines with payment (approve, pay, change, approve again) before claiming correctness.
- A new relation between items raises every interaction: paid items (lock the condition client-side, rely on the server price check), retention periods (a dependency cannot be purged before its dependents), cloning, export/import, manager-only sections, disabled and deleted items, default values; answer each before asking for review.
- A view scoped to a child object (one session's timetable) has no parent context: display decisions derived from the parent are forced to the standalone-sensible value.
- An action that needs an explanation for its recipient (request changes) cannot be fired without a comment; the bulk path gets the same dialog as the single one.
- Features whose result reaches users without an account must deliver it where those users can see it (registration summary via token link).

### Warnings and wording

- Warn users before surprising consequences.
- Images are never scaled up silently: flash a warning with the recommended width when an upload or a setting change leaves the current image outside the range, and state the recommendation on the management page.
- Terminology is one word per concept across labels, placeholders and errors ("Indefinite", not "Permanent" in one place).
- Labels name the behavior plainly ("Lock email address", "cannot be changed during registration"); verbs are consistent across UI, flash messages and changelog ("re-send").
