---
name: write-indico-test
description: Write tests for Indico code using its pytest infrastructure and built-in fixtures. Use when adding or modifying tests under any Indico module, before writing implementation code (TDD).
---

# write-indico-test

Write Indico tests with the project's pytest infrastructure. Test-first, fixture-based, no ORM mocks.

## When To Use

Always before writing implementation code in Indico. Production code added before the test must be deleted and rewritten under TDD.

## Core Rules

1. **Test first.** Red → verify red → green → verify green → refactor. No exceptions.
2. **Fixtures over mocks.** Indico ships dozens of factory fixtures. Use them.
3. **Never mock the ORM.** No `MagicMock` of SQLAlchemy sessions, queries, or model classes. Use real fixtures backed by a real (test) database.
4. **Mock only at external boundaries**: HTTP, filesystem, third-party SDKs, email gateways, process execution.

## Test File Layout

Tests mirror the production tree:

```
indico/modules/events/registration/util.py
indico/modules/events/registration/util_test.py
```

Indico uses `<name>_test.py` next to the file under test. Match the surrounding convention; do not invent `test_<name>.py` in a directory that uses `<name>_test.py`.

## Common Fixtures

Discover via `git grep -nE "^def (dummy_|create_)" indico/testing/ indico/modules/`. Frequently used:

| Fixture | What it provides |
|---|---|
| `db` | Transactional SQLAlchemy session (rolled back after each test) |
| `app_context` | Flask app context |
| `request_context` | Flask request context |
| `dummy_user` | A `User` row |
| `dummy_event` | An `Event` row |
| `dummy_category` | A `Category` row |
| `dummy_regform` | A `RegistrationForm` on `dummy_event` |
| `dummy_reg` | A `Registration` on `dummy_regform` |
| `dummy_contribution` | A `Contribution` on `dummy_event` |
| `freeze_time` | Time freezer (via `freezegun`) |
| `monkeypatch` | Standard pytest patcher (use only at boundaries) |

Before adding a new factory, search:

```sh
git grep -nE "^def (dummy_|create_).*<thing>" indico/testing/ indico/modules/
```

## Test Class Pattern

```python
class TestRegistrationApproval:
    def test_approval_sends_notification(self, dummy_regform, dummy_user, smtp):
        registration = create_registration(dummy_regform, dummy_user)
        approve_registration(registration)
        assert len(smtp.messages) == 1

    def test_approval_records_state_change(self, dummy_reg):
        approve_registration(dummy_reg)
        assert dummy_reg.state == RegistrationState.complete
```

## Parametrize Over Duplication

```python
@pytest.mark.parametrize(('initial', 'expected'), [
    (RegistrationState.pending, RegistrationState.complete),
    (RegistrationState.rejected, RegistrationState.complete),
])
def test_approve_transitions(initial, expected, dummy_reg):
    dummy_reg.state = initial
    approve_registration(dummy_reg)
    assert dummy_reg.state == expected
```

## What To Test

- Behavior exposed by the public API of the function or RH under test.
- Edge cases reachable from real callers: empty inputs, optional fields, duplicates, constraint violations, permission denials.
- Failure modes the production code is expected to handle gracefully.

Do not test private helpers in isolation when they only factor a public function. Coverage comes through behavior.

## Mocking Boundaries

```python
def test_external_api_failure(monkeypatch):
    def fake_post(*_args, **_kwargs):
        raise requests.ConnectionError()
    monkeypatch.setattr('requests.post', fake_post)
    with pytest.raises(IndicoError):
        sync_to_external_service()
```

Acceptable mock targets:

- `requests.*`, HTTP client libraries
- `subprocess.*`
- `open()` or filesystem I/O at the edge
- Third-party SDKs (Stripe, S3, OAuth providers)
- Email send functions when not testing email content
- `datetime.utcnow` / time (prefer `freeze_time` fixture)

Unacceptable mock targets:

- `db.session.*`
- Any `<Model>.query.*`
- `Model.<classmethod>` (`Registration.get`, etc.)
- Signal `send` (test the consumer's effect, not the signal call)

## Running Tests

```sh
# Single file
pytest indico/modules/events/registration/util_test.py

# Single test
pytest indico/modules/events/registration/util_test.py::TestRegistrationApproval::test_approval_sends_notification

# Whole module
pytest indico/modules/events/registration/

# Verify no new warnings
pytest -W error indico/modules/events/registration/util_test.py
```

## Cross-Reference With Skills

- Find the code under test → `../locate-in-indico/SKILL.md`
- Add an RH that needs tests → `../add-indico-rh/SKILL.md`
- Database changes that need a migration test → `../add-alembic-migration/SKILL.md`
