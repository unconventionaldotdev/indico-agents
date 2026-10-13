---
name: review-indico-backend
description: Backend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers Python style, SQLAlchemy, WTForms, marshmallow, signals, request handlers, config, logging and security. Use through review-indico-pr or on its own for a Python-only change.
---

# review-indico-backend

Every item below comes from a finding raised in upstream review of contributor PRs, or from a fix a reviewer pushed to a contributor branch. Run through them against the touched Python files and their callers.

## Control Flow And Structure

- **Early return instead of indentation.** `if not self.field.internal_name: return` at the top, then the body flat. Posted as a suggestion with "That way the whole rest of this check no longer needs to be indented."
- **Merge branches that share a guard.** Two `if not only_defaults:` blocks with nothing in between that depends on the first one are one block.
- **Fail instead of silently narrowing.** When a request carries ids the user may not act on, abort; do not quietly operate on the permitted subset. "What's the reason for not just failing ... and aborting if any registration cannot be managed?"
- **Apply filters where the data is loaded**, not as a check afterwards. Adding the criteria to the query that populates `self.registrations` kept the GET export working and made a separate blocking mechanism unnecessary; the mechanism was then removed.
- **No single-use extraction.** "Do you plan to override `_registration_list_criteria` in custom code later on? If not I'd keep it inside the method..."
- **Define shared infrastructure once.** One `cache` classproperty on the plugin (`make_scoped_cache(f'plugin/{cls.name}')`) instead of `make_scoped_cache` calls spread over modules.
- **Constants:** module level constants go right after the imports, never in the middle of a file. A value used once does not become a constant; inline it with a short comment ("List Users returns up to 2000 per page").
- **Class-level access when no instance is needed.** `plugin_config` became a `cached_classproperty` so `FooPlugin.plugin_config.API_KEY` works; the docs were updated in the same step.
- **Plain default arguments.** `template_name='forms/_form.html'` in the signature; the `None` plus `if x is None` dance is reserved for mutable defaults and translated strings.
- **One query for the set, not one query per candidate.** Checking "is this choice used?" with a query inside a loop over choices gets "IMHO it would be much better to query a list of used choice values". Same for tags, registrations, users: fetch the set once, then test membership in Python.
- **Do not swallow unexpected failures from external services.** Wrapping JSON parsing of an error response in a try/except "isn't useful": an exception for an unexpected response is more informative than silent handling, and an uncaught exception does not crash anything. Catch only the errors you handle.
- **Work without a request context.** Service functions that may run from the shell or Celery guard `session.user if session else None` instead of assuming a request.
- **Keep subclasses in sync.** A new parameter on `create_mm_field` also lands on `InvalidRegistrationFormField.create_mm_field` and every other override. Grep the method name before finishing.
- **Plugin compatibility shapes the API.** Passing a new flag through `self.management` instead of a new `get_validators` argument is accepted because the latter "would be much more likely to break plugins adding custom fields". When a core signature is used by plugin subclasses, prefer an attribute or a keyword with a default.
- **Index keys that always exist.** `data['content_type']`, `attachment['filename']`: "This key always exists." A `.get()` with a fallback on a key the code itself wrote hides bugs and invents states that never occur. When a key is genuinely optional and never holds a falsy junk value, `.get('x', [])`, not `.get('x') or []`.
- **Walrus in comprehensions** to avoid calling the getter twice: `{cid: url(idx) for idx, att in enumerate(atts) if (cid := att.get('content_id'))}`.
- **Functions that never touch `self` go to `util.py`**, not into the request handler class.
- **Use `locator`.** Models that are addressed by URL get a `@locator_property` and callers write `url_for('logs.event_email_attachment', self, attachment_id=...)` instead of spelling out `event_id=..., log_entry_id=...` at every call site.
- **Reuse the core file plumbing.** Signed links for a `File` come from `signed_download_url` and `RHFileDownload`; a custom token scheme with user matching "should be easily possible" to delete. Check `UploadFileMixin` before writing an upload handler, and explain concretely when it does not fit (data key, missing hook); the explanation is accepted ("Fine to leave it as is then").
- **Line length is 120.** A statement that fits in 120 characters stays on one line; "Remove unnecessary line break" is a real reviewer commit. Long boolean expressions use the parenthesized form with one operand per line and the operator at the line start.

## Naming And Comments

- Names carry the intent so the comment can go: `_check_unique_title_in_section` replaces `# check unique title in section`. A comment that restates the method name is removed.
- Private helpers get the `_` prefix. Attributes follow the class they live in: when nothing else in the class is marked internal, a new `self._management` loses the underscore.
- User-facing labels are reviewed as words, not identifiers: "Code" on an affiliation form is "a bit misleading"; "Short name / abbreviation" says what goes there. Changelog entries get the same treatment ("Add a "Code" (short name) to predefined affiliations").
- Siblings share a naming scheme: `auto_register` and `auto_checkin`, not `webhook_checkin`.
- Ambiguous locals get a precise name: `page_token`, not `token`, when a token of another kind exists nearby.
- No underscored import aliases (`import hmac as _hmac`): "Why are these imports underscored?"
- Comments state facts that hold. A comment implying a limitation ("Zoom only honors this when the meeting was originally created with ...") gets "What does this imply for ...?" until the sentence is true.
- Quirk comments use `# XXX`: "Some Zoom events receive the ID as a string, others as a number".
- A knowingly rough approach gets a comment that says so and why it is safe: "this is a bit ugly, but cids are generally dynamic enough to avoid replacing unrelated content, and in any case it would not do any harm".
- Docstrings use Sphinx inline literals with double backticks (``` ``log`` ```), not single ones.
- Copy-pasted comments drift: "check unique internal name" above a title check gets a suggestion.
- Wording follows where the code lives: a field description in the Zoom plugin says "the Zoom meeting", not "the videoconference".

## Imports

- All imports at the top, grouped stdlib, third party, indico, plugin.
- A local import inside a function is acceptable only to break an import cycle (`from indico_vc_zoom.plugin import ZoomPlugin` inside a util function).

## Request Handlers And Access

- Override `_check_access` (call the parent, then the specific check) rather than `_check_management_permission`, so the error names the object ("You are not authorized to manage this registration", not "... this event").
- Shared behavior across endpoints lives in an RH base class driven by class attributes, not copied per handler.
- When access depends on a filter, every endpoint that lists, counts, exports or acts on the same objects applies it. Upstream tests by installing a filter and reading every counter on screen: "Both should be `2` since my filter hides one of the 3 registrations."
- Feature-gated endpoints stay closed when the gate is off, even if the exposure looks harmless. "It's cleaner to disable this endpoint as well."
- Request/response schemas limit what leaks: "That's why we have a schema to take and return only the expected data."

## Signals

- A signal that lets several handlers narrow a result mutates the passed list in place. Returning a new list from each handler and "applying in turn" overwrites the previous one unless you build combination logic nobody wants.
- `values_from_signal` already drops `None` (`skip_none=True`); a comprehension filtering `None` is redundant.
- Signal docstrings state the real contract: sender, kwargs, return value, and how multiple returns combine. The call site is checked against the docstring.
- Core additions need a core consumer. A hook that only a plugin will call gets questioned.

## Forms (WTForms)

- A field that only makes sense when a toggle is on uses `HiddenUnless('toggle', preserve_data=True)` and, when leaving it empty makes no sense, `DataRequired`.
- Per-event preferences are form fields on the event or room, not global plugin settings. "No need for a global setting."
- Validation errors on a multi-value field name the offending items; a generic message is fine for a single-value field.
- User-provided strings in a `ValidationError` are escaped (`markupsafe.escape`): the message renders as markup. This has been fixed by reviewers as an XSS.
- A form that references external accounts must not break on load when the external side changed (a co-host lost their Zoom account); failing to save until fixed is expected.
- Never mutate `field.data` in a `validate_*` method; normalize in `process_formdata()` or `post_validate()`.
- When overriding an inherited field, verify the rendered order of fields did not change.

## Schemas (marshmallow)

- `@validates_schema(skip_on_field_errors=True)` when the validator reads required fields; otherwise a missing field raises `KeyError`.
- `raise ValidationError(_('message'), 'field_name')`, not `ValidationError({'field_name': ['message']})`.
- Several placeholders in one translatable string are named: `_('The field "{field}" ... on form "{form}" ...').format(field=..., form=...)`.

## SQLAlchemy

- After `.join(Model.relationship)`, load it with `contains_eager`, not `joinedload`.
- Soft-deleted parents are filtered at every level: `~Event.is_deleted` and `~RegistrationForm.is_deleted`, with a test per level.
- Queries about a subtype use the subtype class (`RegistrationFormField`, not `RegistrationFormItem`) so sections do not match field-only constraints. Reproduce in master before claiming the wider scope.
- A new FK into `User` (or any core model) needs the backref, the entry in the model's alphabetized backref comment list, and handling in `merge_users` so the column does not go stale.
- Columns get `#:` doc comments. Migration PRs carry the `alembic` label; the revision gets rebased at merge time (filename date and `down_revision`).
- Changing a `column_property` that backs an index (`searchable_names`) changes the index too: the revision drops and recreates it in `upgrade` and `downgrade`, and `indico db_diff` must come back empty before the PR is ready. When the diff refuses to go away, express the property closer to the SQL the database reports.
- Bulk code paths issue one query per sync, not one per item: build the set of active registrations once and reuse it.

## Config And Startup

- Plugins register signal handlers with `self.connect(signal, handler, sender=...)` inside `init()`, never with module-level `@signal.connect_via(...)` decorators: handlers must run only when the plugin is loaded, not whenever its module is imported.
- Plugin config keys live in a reserved namespace (`PLUGIN_<NAME>_<KEY>`), never shared with core keys. "That way it's clear `PLUGIN_*` should never be used for a core setting."
- Invalid configuration raises (`RuntimeError`), it does not warn and continue, even for "very unlikely" collisions.
- Never import plugin code while loading configuration: SQLAlchemy mappers are not set up and `livesync` plus `livesync_debug` is enough to reproduce the crash. Defer plugin-specific loading to `IndicoPlugin.init()` and run cross-plugin validation in `IndicoConfig.validate`.
- Credentials set in the config file disable and mask the corresponding admin UI fields; an admin must not read a secret that infrastructure provided. All credentials of one integration are configurable the same way, not half in the file and half in the UI.
- File-based secrets stay optional. For web-generated secrets the admin UI remains the default.

## Logging, Flashing, Errors

- No `flash()` in service or hook methods (`refresh_room`, signal handlers): they also run during event cloning and in Celery. Log instead.
- Log messages embed the static variant in the format string (meeting vs webinar) so Sentry groups them separately, and keep `%s` for the variable data; an f-string for the static part carries `# noqa: G004`.
- Expected external rejections (host cannot register, room already deleted) are filtered or handled, not logged as warnings on every run.
- Error messages tell the user how to fix the situation, especially when the failure is otherwise obscure (a co-host without an account).
- Event log entries use the module of the object ("Registration"), not of the feature ("Tags"), and record only what changed: compute `added = add - remove - reg.tags` and `removed = reg.tags & remove` before mutating, so a bulk action on registrations that already carry the tag logs nothing for them.
- Warnings shown to end users are short and concrete: "If you modify this registration, it needs to be approved again by the event organizer." beats two sentences about status resets.

## External Services And Performance

- Zoom (and any API with parallel families): meetings and webinars are checked against both endpoints' docs. "According to the Zoom API docs, `approval_type` exists for webinars as well."
- Match the external type exactly: ids arrive as strings in some events and numbers in others; normalize with `int(...)` and a quirk comment.
- Never do an O(n) external sweep per request. A full tenant walk belongs in a daily Celery task writing a scoped cache (TTL above the task interval), with per-item fallback on cache miss. Thresholds are "Fine for now", not a solution.
- Reason about the common case first: few registrations and many Zoom users is more common than the reverse.
- Re-fetch and verify after a PATCH when the provider is known to drop values silently; log, do not flash, when it did.

## Security

- Escape user-controlled strings in any message that renders as HTML.
- Secrets never reach the browser once they come from configuration.
- Scoped endpoints: a plugin endpoint is bound to an event, category or registration form; a global read leaks across events.
- Access-control defaults are checked against the provider's semantics (`approval_type=0` let anyone with the link self-approve into a meeting).
- A narrower management permission does not inherit side doors: logs, exports and configuration stay with full management. "Logs should remain manager-only." The RH that serves them must check the stronger permission, not just hide the button.
- Hardening is welcome when it is the standard primitive: `hmac.compare_digest` for signatures, `secrets` for generated passcodes, no signature values in logs.

## Behavior Changes And State

- A change that alters an existing workflow (resetting approval on modification) ships as an opt-in setting, off by default: "I believe this should be configurable (and off by default)." Communities differ; the default protects the majority.
- Walk the state machine with payment involved before claiming it works: register, approve, mark as paid, trigger the reset, approve again; the registration must end `complete`, not `unpaid`.
- Users get a warning before an action with a surprising consequence; silent resets "come as a complete surprise".
- Pre-filled defaults are only offered when they are what the user would pick: a custom uploaded profile picture yes, a gravatar or generated initial no, because "users tend to leave defaults".
- Keep the source format when converting data: a 256x256 PNG profile picture is not re-encoded as JPEG; add a target-format argument to the shared helper instead.
- Every entry point that builds the same payload gets the new behavior: user registration, manager registration on behalf, bulk registration from user accounts. Missing one was found by another contributor, not by tests.
