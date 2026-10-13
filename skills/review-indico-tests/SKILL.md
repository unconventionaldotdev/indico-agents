---
name: review-indico-tests
description: Test checklist for reviewing Indico core and plugin changes against upstream review standards. Covers pytest style, fixture usage, assertions, test data realism and the scenarios upstream tries by hand. Use through review-indico-pr or on its own when only tests changed.
---

# review-indico-tests

Check every touched `*_test.py` and `fixtures.py`.

## Fixtures

- Reuse core fixtures (`create_regform`, `create_user`, `dummy_event`); in plugins load them with `pytest_plugins = 'indico.modules.events.registration.testing.fixtures'`.
- Side-effect fixtures (`db`, `smtp`, `request_context`) in `@pytest.mark.usefixtures`, never as unused arguments; same for parametrize values consumed only by fixtures.
- No imports from other test modules; shared setup is a factory fixture in `fixtures.py`.
- A module helper taking `db` and the plugin is a fixture in disguise.
- No fixture that wraps an existing model method (`room.set_attribute_value`). Factory fixtures accept `**kwargs` and pass them to the model. Locals are named after the object they hold (`sess`, not an `entry` copied from a sibling fixture).
- Removing or renaming a core fixture (or its `pytest_plugins` import) breaks plugins that use it; grep the plugin repos and open the companion PR.
- Fixtures touching caches or globals clean up before and after.
- No `request_context` + `session.set_session_user` when the code can run without a request; make the code tolerate it instead.
- Long symbol lists become module imports (`reglists.RHRegistrationEdit`).
- Helpers used only by tests live in `indico/testing/util.py` as private functions, not in `indico/util`.
- Email templates get snapshot tests (`assert_email_snapshot`, `html=True` for the HTML part) covering every generated part.
- `@pytest.fixture` without `scope='function'`; it is the default. Never redefine a core fixture name (`freeze_time`, `snapshot`) in a test module; a module-specific variant (`freeze_time_for_snapshots`) wraps the global one and is `autouse=True` when every test needs it.
- Factory fixtures take required arguments positionally (`create_attachment(user, object, title, ...)`); keyword-only is for optional ones. Explicit fixture ids are high (`420`, `1337`), not `42`: a test creating that many rows collides with the sequence.
- A snapshot directory is set once by a module-level wrapper (`_assert_yaml_snapshot(snapshot, data, name)` with `__tracebackhide__ = True` and `snapshot.snapshot_dir = SNAPSHOT_DIR`); the shared helpers (`assert_yaml_snapshot`, `assert_email_snapshot`, `remove_dynamic_data`) live in `indico/testing/util.py`. A field added to an export schema updates every export snapshot (the empty-user one included); run the snapshot tests instead of regenerating blindly.

## Assertions

- `assert x` / `assert not x`; never `is True` / `is False`.
- Assert outcomes: status code, returned set, mock called with exact args.
- Indico helpers: `obj.log_entries.one()`, `not obj.log_entries.has_rows()`.
- No branch that can never run; parametrize the cases.
- Strongest assertion available (`set(rh.PERMISSION) >= {...}`).
- Negative tests cover redundant and nonsense inputs, not only the empty case.
- Every positive rule gets its counter test (different type allowed in another event).
- Expected lists derived from an enum are built from the enum in a fixture (`for opt in DataExportOptions`), not typed by hand. Snapshot normalization keeps `null` visible (`(?!null$)` before the placeholder) so a field that unexpectedly becomes empty still fails.

## Test Data

- Real external types (integer Zoom ids, string ids in webhook payloads).
- Dummy names (`foo`, `FooPlugin`), never client or product prefixes.
- `with signal.connected_to(handler):`; `client.post(url, json=...)`.
- Fake persisted rows get an explicit `id` when the code branches on it.
- Build related rows through relationships (`parent=section`), not `parent_id=section.id` after a manual flush. Drop fixture arguments the test does not read. Multi-line dict literals close `}` on its own line.
- Denormalized pairs are set together as the application would (`affiliation` text with `affiliation_link`). Every nested schema in a snapshot is exercised with at least one populated row; `[]` or `null` for a section hides typos in its `Meta.fields`.

## Layout

- `*_test.py`; plugins keep tests in `tests/`, fixtures in the package.
- Continuation lines aligned with the opening parenthesis; a call that fits in one line stays on one line; no blank line after `class X:`; no banner comments; no `print()`.
- Plain functions, no test classes (a class per module hints the module is too big).
- Every new validation rule and every non-trivial query (grouped tag matching, subqueries) ships with a test.
- One-line docstrings only when the name cannot carry the behavior.
- `parametrize` over near-duplicate tests and over RH classes; `list(SomeEnum)` for all states.
- Snapshots of nested data are YAML (`assert_yaml_snapshot`, `.yml`), not JSON; ids, timestamps and uuids become placeholders through `strip_dynamic_data=True`, never ad-hoc regexes in the test module.
- JS unit tests live in `__tests__/<module>.test.js` next to the module and import it with `../module`. Pure client logic extracted into its own module (a selection state machine, a date parser, `formatDate`) ships with a Jest test: one case per transition table row, per locale format, per accepted and rejected input (`test.each`); a web component PR without tests for its state machine is incomplete.

## Scenarios Upstream Tries

- Both members of a parallel family (meeting/webinar, field/section, GET/POST).
- Soft-deleted parents at every level.
- Dependent toggle off; feature gate off.
- Idempotency (duplicate webhook, already checked in).
- Stale external state (removed account, deleted meeting, unknown email).
- Access matrix per role, including a manager of another event.
- Cache cold and single-item miss.
- Every entry point building the same payload (user form, on-behalf, bulk).
- State transitions with payment.
- User editing values a manager set outside the user range.
- Dependency chains (a -> b -> c), every type allowed as a dependency, edits that omit unchanged fields, manager-only data sent by a user (ignored).
- Both alternatives of mutually exclusive endpoints (the typed endpoint rejects when no types exist, the untyped one rejects when types exist); the fallback mode for unconfigured data against existing data; files submitted through an upload endpoint survive the unclaimed-files cleanup task.
- Submitted ids that do not exist, belong to another event, or point at objects the user cannot access; a listing with public and restricted children as a user with access to only some; cloning with the dependency cloner disabled and with a referenced object deleted since.
- Export or render of a production-size event (hundreds of pages): count queries before and after; a child-object view next to the full one with the same data; legacy data with quotes or line breaks in titles rendered into generated CSS or PDF; garbage input to a regex validator and a pathological pattern that hangs the parser.
- Unlisted event (no category) using a category-inherited feature; three-state inherited config (inheriting from an enabled parent, disabled under an enabled parent, enabled with own settings, root never inheriting); global flag off: every surface hidden, stored settings untouched, saving the parent form without touching the integration fields keeps them.
- Handler of a broad update signal: an irrelevant change makes no API call, a relevant one does; credentials unchanged on save: no verification request; signed URL: valid token bypasses protection, missing or wrong token falls back to the normal check; remote object missing (404) on a silent sync: no error, no creation.
- Date widgets: the edit path (initial value in canonical format); a non-UTC browser timezone round-trips the same day; a non-English locale; a month where every day is disabled by `min` (no focusable day, no console error); reopen after selecting a range; edit only one end of a long range; a bound toggled while the picker is open; second click before the first in both pickers; per sub-field empty, invalid and out-of-bounds messages after the trigger was clicked and the dialog closed without typing; locked end with and without a value; `readOnly` vs `disabled` vs both.
- Registrant-facing pages and file links opened logged out through the token link. Paginated lists with more rows than the largest page size, exactly one page, zero rows, and a search with no match. Export with every option selected and every fixture populated; extract the archive into an empty directory and read the YAML.

## Plugin Boilerplate

- `pytest.ini` and `pyproject.toml` `exclude` copied from a sibling plugin; no `--basetemp` or local workarounds upstream.
- After a type change, fix every fixture and assertion that assumed the old type.
