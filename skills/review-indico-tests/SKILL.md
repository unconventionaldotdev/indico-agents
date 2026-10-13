---
name: review-indico-tests
description: Test checklist for reviewing Indico core and plugin changes against upstream review standards. Covers pytest fixtures, assertions, snapshots, test data, test layout (pytest and Jest), plugin test boilerplate and the scenarios upstream tries by hand, grouped by area. Use through review-indico-pr or on its own when only tests changed.
---

# review-indico-tests

Check every touched `*_test.py` and `fixtures.py`.
Also check `__tests__/*.test.js` files, and use the Scenarios section for the manual pass over the changed area.

## Fixtures

- Reuse core fixtures (`create_regform`, `create_user`, `dummy_event`) instead of building the same rows by hand; plugins load them as described in Plugin Boilerplate.
- Side-effect fixtures (`db`, `smtp`, `request_context`) go in `@pytest.mark.usefixtures`, never as unused test arguments.
- A parametrize value consumed only by a fixture is not also an unused test argument.
- Drop every fixture argument the test body does not read.
- No imports from other test modules; shared setup is a factory fixture in `fixtures.py`.
- A module-level helper that takes `db` and the plugin is a fixture in disguise; make it one.
- No fixture that only wraps an existing model method (`room.set_attribute_value`); call the method directly.
- Factory fixtures accept `**kwargs` and pass them to the model constructor.
- Factory fixtures take required arguments positionally (`create_attachment(user, object, title, ...)`); keyword-only is for optional ones.
- Locals are named after the object they hold (`sess`, not an `entry` copied from a sibling fixture).
- Removing or renaming a core fixture, or its `pytest_plugins` import, breaks plugins that use it: grep the plugin repos and open the companion PR.
- Fixtures touching caches or globals clean up before and after the test.
- No `request_context` plus `session.set_session_user` only to make code run that could run without a request: the code must tolerate the missing request (backend skill); the test must not paper over it.
- Helpers used only by tests live in `indico/testing/util.py` as private functions, not in `indico/util`.
- `@pytest.fixture` without `scope='function'`: it is the default.
- Never redefine a core fixture name (`freeze_time`, `snapshot`) in a test module.
- A module-specific variant (`freeze_time_for_snapshots`) wraps the global fixture and is `autouse=True` when every test in the module needs it.
- Explicit fixture ids are high (`420`, `1337`), not `42`: a test creating that many rows collides with the sequence.
- No `db.session.add()` for an object constructed with a relationship to a fixture row (`RegistrationFormSection(registration_form=dummy_regform)`); the cascade adds it.
- When dropping such a line, remove the import that only it used.

## Assertions

- `assert x` / `assert not x`; never `is True` / `is False`.
- Assert outcomes: status code, returned set, mock called with exact args.
- Use the Indico query helpers: `obj.log_entries.one()`, `not obj.log_entries.has_rows()`.
- No branch inside a test that can never run; parametrize the cases instead.
- Strongest assertion available (`set(rh.PERMISSION) >= {...}` over a membership check per item).
- Negative tests cover redundant and nonsense inputs, not only the empty case.
- Every positive rule gets its counter test (the same type is allowed in another event).
- Expected lists derived from an enum are built from the enum in a fixture (`for opt in DataExportOptions`), not typed by hand.
- A property returning a tuple is asserted against the full tuple built from the columns (`(a, b, c) == obj.repetition`).
- Extending such a tuple updates every parametrized case with the new member (`None` where it does not apply) in the same commit.
- After a type change, fix every fixture and assertion that assumed the old type.

### Snapshots

- Snapshots of nested data are YAML (`assert_yaml_snapshot`, `.yml`), not JSON.
- Ids, timestamps and uuids become placeholders through `strip_dynamic_data=True`, never through ad-hoc regexes in the test module.
- Snapshot normalization keeps `null` visible (`(?!null$)` before the placeholder) so a field that unexpectedly becomes empty still fails.
- The shared helpers (`assert_yaml_snapshot`, `assert_email_snapshot`, `remove_dynamic_data`) live in `indico/testing/util.py`.
- The snapshot directory is set once by a module-level wrapper (`_assert_yaml_snapshot(snapshot, data, name)` with `__tracebackhide__ = True` and `snapshot.snapshot_dir = SNAPSHOT_DIR`), not in every test.
- Every nested schema in a snapshot is exercised with at least one populated row: `[]` or `null` for a section hides typos in its `Meta.fields`.
- A field added to an export schema updates every export snapshot, the empty-user one included; run the snapshot tests and read the diff instead of regenerating blindly.
- Email templates get snapshot tests (`assert_email_snapshot`, `html=True` for the HTML part) covering every generated part.

## Test Data

- Real external types (integer Zoom ids, string ids in webhook payloads).
- Dummy names (`foo`, `FooPlugin`), never client or product prefixes.
- Connect signal handlers with `with signal.connected_to(handler):`.
- Post JSON with `client.post(url, json=...)`, not a hand-serialized body.
- Fake persisted rows get an explicit `id` when the code branches on it.
- Build related rows through relationships (`parent=section`), not `parent_id=section.id` after a manual flush.
- Denormalized pairs are set together as the application would (`affiliation` text with `affiliation_link`).
- Setup does only what the code under test checks: no `flush()` unless an id is read back.
- No `start_dt` or open-period dates when `create_registration` does not check them and the form has no end date.
- After a new CHECK constraint, every fixture call that builds rows satisfies it (`recurrence_weekdays=None` on a daily reservation).
- Do not keep values a new constraint rejects just because the fixture never flushed before.

## Layout

- Test modules are `*_test.py`; plugins keep tests in `tests/` and fixtures in the package.
- Plain test functions, no test classes (a class per module hints the module is too big); a helper or mock class defined in a test module has no blank line after `class X:`.
- Continuation lines aligned with the opening parenthesis.
- A call that fits in one line stays on one line.
- Multi-line dict literals close `}` on its own line.
- No banner comments; no `print()`.
- One-line docstrings only when the name cannot carry the behavior.
- `parametrize` over near-duplicate tests and over RH classes; `list(SomeEnum)` to cover all states.
- Long symbol lists become module imports (`from ...management import reglists`, then `reglists.RHRegistrationEdit`).
- Every new validation rule and every non-trivial query (grouped tag matching, subqueries) ships with a test.
- When a cross-cutting mechanism is rewired (CORS moved from blueprint config to a decorator), its tests are re-run and updated, including the error response path.
- JS unit tests live in `__tests__/<module>.test.js` next to the module and import it with `../module`.
- Pure client logic extracted into its own module (a selection state machine, a date parser, `formatDate`) ships with a Jest test.
- Jest cases use `test.each`: one case per transition table row, per locale format, per accepted and per rejected input.
- A web component PR without tests for its state machine is incomplete.

## Scenarios Upstream Tries

Pick the groups matching the changed area and try every scenario in them by hand or with a test.

### Parallel paths and state

- Both members of a parallel family (meeting/webinar, field/section, GET/POST).
- Every entry point building the same payload (user form, on-behalf, bulk).
- Soft-deleted parents at every level.
- Idempotency: a duplicate webhook, a participant already checked in.
- State transitions when payment is involved.
- Both alternatives of mutually exclusive endpoints: the typed endpoint rejects when no types exist, the untyped one rejects when types exist.
- The fallback mode for unconfigured data, run against existing data.

### Access and permissions

- Access matrix per role, including a manager of another event.
- Submitted ids that do not exist, belong to another event, or point at objects the user cannot access.
- A listing with public and restricted children, as a user with access to only some of them.
- Manager-only data sent by a user is ignored.
- Registrant-facing pages and file links opened logged out through the token link.
- Signed URL: a valid token bypasses protection; a missing or wrong token falls back to the normal check.
- Every public page the change touches, loaded logged out; the page script must not throw.
- Every page where the widget renders its disabled or reduced variant (management area); the page script must not throw.

### Feature gates and inherited settings

- Dependent toggle off; feature gate off.
- Unlisted event (no category) using a category-inherited feature.
- Three-state inherited config: inheriting from an enabled parent, disabled under an enabled parent, enabled with own settings; the root never inherits.
- Global flag off: every surface hidden, stored settings untouched.
- Saving the parent form without touching the integration fields keeps them.
- Optional settings left unset (an effective date of `None`) on every page that reads them.
- A forced-acceptance flow with a freshly signed-up account, and with an effective date in the future (the user must not get stuck).

### Registration and forms

- A user editing values a manager set outside the user range.
- Dependency chains (a -> b -> c), with every type allowed as a dependency.
- Edits that omit unchanged fields.
- Files submitted through an upload endpoint survive the unclaimed-files cleanup task.
- Manager vs registrant on the same form: required fields enforced for the registrant (edit through the display RH raises `UnprocessableEntity`), skipped for the manager on create and on edit.
- `alwaysRequired` and personal-data fields stay enforced for the manager.
- Run `bin/utils/db_log.py -S` while submitting a changed form in each mode; a mode that should not persist a value (a "remember" flag with a non-custom option) must produce no write.

### Choice widgets

- Switch between choices with different slot limits: slots reset.
- Clear the choice: slots disappear.
- Type text matching no option on a non-required field: validation error.
- Sold-out option: visible, disabled.
- Field locked after payment, and form submitting: disabled.
- Two options differing only by case.
- Widget near the viewport bottom.

### Date widgets

- The edit path: initial value in canonical format.
- A non-UTC browser timezone round-trips the same day.
- A non-English locale.
- A month where every day is disabled by `min`: no focusable day, no console error.
- Reopen after selecting a range.
- Edit only one end of a long range.
- A bound toggled while the picker is open.
- Second click before the first, in both pickers.
- Per sub-field empty, invalid and out-of-bounds messages after the trigger was clicked and the dialog closed without typing.
- Locked end with and without a value.
- `readOnly` vs `disabled` vs both.

### Recurring bookings

- Changing only the new attribute on an ongoing booking triggers the split logic.
- A date range containing none of the selected weekdays, on every endpoint that builds the series (search, suggestions, conflicts, edit calendars, create).
- Switching repetition type back and forth in the edit form leaves no stale value in the payload.

### Lists, pagination and exports

- Paginated lists with more rows than the largest page size, exactly one page, zero rows, and a search with no match.
- Export with every option selected and every fixture populated; extract the archive into an empty directory and read the YAML.
- A child-object view next to the full one with the same data.

### Signals and integrations

- Handler of a broad update signal: an irrelevant change makes no API call, a relevant one does.
- Credentials unchanged on save: no verification request.
- Remote object missing (404) on a silent sync: no error, no creation.
- Stale external state: removed account, deleted meeting, unknown email.

### Cloning and legacy data

- Cloning with the dependency cloner disabled, and with a referenced object deleted since.
- Legacy data with quotes or line breaks in titles rendered into generated CSS or PDF.
- Editing a row created before a new column existed (a weekly booking with `NULL` weekdays): the dialog preselects the derived value and saving works.

### Performance

- Export or render of a production-size event (hundreds of pages): count queries before and after.
- Cache cold, and a single-item miss.
- Garbage input to a regex validator, and a pathological pattern that hangs the parser.

### CLI and tooling

- A CLI over external data is run against real inputs (a fresh Transifex pull, actual plugin directories).
- The files it should produce are checked on disk (`messages.mo` present, empty `.pot` files removed), not only the exit code.
- Translation catalogs may carry the `fuzzy` header flag; compilation covers that case.

## Plugin Boilerplate

- `pytest.ini` and the `pyproject.toml` `exclude` are copied from a sibling plugin.
- No `--basetemp` or other local workarounds in the upstream config.
- Core fixtures are loaded with `pytest_plugins = 'indico.modules.events.registration.testing.fixtures'` (the module path of the fixtures module), never copied into the plugin.
