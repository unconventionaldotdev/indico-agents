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
- No `request_context` plus `session.set_session_user(...)` when the code under test can run without a request; make the code tolerate `session` being unbound and drop both from the test.
- Module imports over long symbol lists: `from ...controllers.management import reglists` and `reglists.RHRegistrationEdit` in the test body, "as we do in the registration module blueprint", once the import block grows past a handful of names.

## Assertions

- `assert reg.checked_in` and `assert not reg.checked_in`. Never `is True` / `is False` "unless you really care that it's False and not None".
- Assert the outcome, not the absence of an error: a status code, a returned set, a called mock with exact arguments (`assert_called_with(100000, {...})`).
- Each test discriminates: the setup must make only the behavior under test produce the asserted result.
- Use the relationship and query helpers Indico already has: `event.log_entries.one()` instead of `EventLogEntry.query.filter_by(...).all()` plus `len(...) == 1`; `not event.log_entries.has_rows()` instead of `.count() == 0`.
- A test with a branch that is never hit (`if isinstance(perm, tuple): ... else: ...`) "doesn't make sense"; assert the shape you expect and parametrize over the cases.
- Prefer the stronger set assertion: `assert set(rh.PERMISSION) >= {'registration', 'registration_edit'}` checks both permissions at once instead of `'registration_edit' in rh.PERMISSION`.
- "Actually test" the negative case: a test named `no_log_when_nothing_changes` with an empty changeset proves little; add the redundant change (adding a tag already present) and the nonsense change (add and remove the same tag) to the same test.

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
- `@pytest.mark.parametrize` over near-duplicate tests; a `list(SomeEnum)` parametrize covers "all states". A class holding one near-identical method per request handler collapses into one parametrized function over the RH classes.

## Scenarios Upstream Will Try

Write the test before it is asked for:

- Both variants of a parallel API family (meeting and webinar; field and section; GET and POST of a bulk endpoint).
- Soft-deleted parents at every level (event, registration form, registration).
- The dependent toggle off: auto-register disabled, auto-checkin disabled, feature gate disabled.
- Idempotency: the webhook arrives twice, the item is already checked in.
- Unknown or stale external state: email not registered, account removed, meeting already deleted on the provider.
- Access matrix for a new endpoint: each role, including a manager of an unrelated event, with the expected status code.
- The degraded path of a cache: not populated yet, and a miss for one item.
- Every entry point that builds the same data: user-facing form, manager "register on behalf", bulk registration.
- State transitions combined with payment: approve, pay, trigger the change, approve again.
- A user editing a registration whose manager-set values are outside the ranges the user may pick.

## Plugin Test Boilerplate

- `pytest.ini` copied from a sibling plugin, only `indico_plugins` adapted. No `--basetemp` or other local workarounds upstream; keep those in `.envrc`.
- `pyproject.toml` `exclude` lists `tests/`, `*_test.py`, `test_snapshots/` and the client sources, with the same comments as the sibling plugins.
- Tests keep passing after a type change: fixing the meeting id type meant fixing every fixture and assertion that assumed a string.
