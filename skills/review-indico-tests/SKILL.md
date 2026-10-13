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

## Assertions

- `assert x` / `assert not x`; never `is True` / `is False`.
- Assert outcomes: status code, returned set, mock called with exact args.
- Indico helpers: `obj.log_entries.one()`, `not obj.log_entries.has_rows()`.
- No branch that can never run; parametrize the cases.
- Strongest assertion available (`set(rh.PERMISSION) >= {...}`).
- Negative tests cover redundant and nonsense inputs, not only the empty case.
- Every positive rule gets its counter test (different type allowed in another event).

## Test Data

- Real external types (integer Zoom ids, string ids in webhook payloads).
- Dummy names (`foo`, `FooPlugin`), never client or product prefixes.
- `with signal.connected_to(handler):`; `client.post(url, json=...)`.
- Fake persisted rows get an explicit `id` when the code branches on it.
- Build related rows through relationships (`parent=section`), not `parent_id=section.id` after a manual flush. Drop fixture arguments the test does not read. Multi-line dict literals close `}` on its own line.

## Layout

- `*_test.py`; plugins keep tests in `tests/`, fixtures in the package.
- Continuation lines aligned with the opening parenthesis; a call that fits in one line stays on one line; no blank line after `class X:`; no banner comments; no `print()`.
- Plain functions, no test classes (a class per module hints the module is too big).
- Every new validation rule and every non-trivial query (grouped tag matching, subqueries) ships with a test.
- One-line docstrings only when the name cannot carry the behavior.
- `parametrize` over near-duplicate tests and over RH classes; `list(SomeEnum)` for all states.

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

## Plugin Boilerplate

- `pytest.ini` and `pyproject.toml` `exclude` copied from a sibling plugin; no `--basetemp` or local workarounds upstream.
- After a type change, fix every fixture and assertion that assumed the old type.
