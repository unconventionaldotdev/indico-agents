---
name: review-indico-tests
description: Test checklist for reviewing Indico core and plugin changes against upstream review standards. Covers pytest style, fixture usage, assertions, test data realism and the scenarios upstream tries by hand. Use through review-indico-pr or on its own when only tests changed.
---

# review-indico-tests

Upstream reviewers rewrite tests that do not follow these conventions and push the result as a cleanup commit. Check every touched `*_test.py` and `fixtures.py`.

## Fixtures

- Reuse core fixtures before writing plugin ones: `create_regform`, `create_user`, `dummy_event`. In a plugin, load them with `pytest_plugins = ('indico.modules.events.registration.testing.fixtures',)`. "Why can't this use the `create_regform` fixture from the core?"
- Fixtures used only for their side effect (`db`, `smtp`, `request_context`) go in `@pytest.mark.usefixtures(...)`, never as an unused function argument.
- A parametrize argument consumed only by a fixture is also moved to `usefixtures` and dropped from the signature.
- No importing helpers from another test module ("It's not common to import stuff from other test modules"). Shared setup becomes a factory fixture in `fixtures.py`, possibly a fixture that returns the helper function.
- A module-level helper taking `db` and the plugin as arguments is a fixture in disguise; convert it.
- Fixtures that touch a cache or global state clean up before and after (`yield` in the middle).

## Assertions

- `assert reg.checked_in` and `assert not reg.checked_in`. Never `is True` / `is False` "unless you really care that it's False and not None".
- Assert the outcome, not the absence of an error: a status code, a returned set, a called mock with exact arguments (`assert_called_with(100000, {...})`).
- Each test discriminates: the setup must make only the behavior under test produce the asserted result.

## Test Data

- Match the external service's real types: Zoom meeting ids are integers (`itertools.count(start=100000)`), webhook payloads carry them as strings (`str(vc_room.data['zoom_id'])`). A fixture producing `'zmeeting1'` hides a type bug.
- Dummy names in tests and docs: `foo`, `FOO_TIMEOUT`, `FooPlugin`. Never a client or product prefix.
- Signals in tests: `with signal.connected_to(handler): ...`, not `signal.connect(handler, weak=False)`.
- Flask test client: `client.post(url, json={...})`, not `data=b'{"..."}'`.

## Layout And Style

- Files use the `*_test.py` suffix. Mirror the sibling layout; in plugins tests live in `tests/` and shared fixtures in the package's `fixtures.py`.
- Continuation lines of a long signature align with the opening parenthesis.
- No banner or section comments (`# ── Security tests ───`). Group by class or by file instead.
- Docstrings on tests are fine when they state the behavior in one line; names should already do that.
- `@pytest.mark.parametrize` over near-duplicate tests; a `list(SomeEnum)` parametrize covers "all states".

## Scenarios Upstream Will Try

Write the test before it is asked for:

- Both variants of a parallel API family (meeting and webinar; field and section; GET and POST of a bulk endpoint).
- Soft-deleted parents at every level (event, registration form, registration).
- The dependent toggle off: auto-register disabled, auto-checkin disabled, feature gate disabled.
- Idempotency: the webhook arrives twice, the item is already checked in.
- Unknown or stale external state: email not registered, account removed, meeting already deleted on the provider.
- Access matrix for a new endpoint: each role, including a manager of an unrelated event, with the expected status code.
- The degraded path of a cache: not populated yet, and a miss for one item.

## Plugin Test Boilerplate

- `pytest.ini` copied from a sibling plugin, only `indico_plugins` adapted. No `--basetemp` or other local workarounds upstream; keep those in `.envrc`.
- `pyproject.toml` `exclude` lists `tests/`, `*_test.py`, `test_snapshots/` and the client sources, with the same comments as the sibling plugins.
- Tests keep passing after a type change: fixing the meeting id type meant fixing every fixture and assertion that assumed a string.
