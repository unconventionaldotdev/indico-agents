---
name: add-indico-rh
description: Add a new Request Handler (RH) to an Indico module with the right base class, permission checks, blueprint registration, and return type. Use when adding a new endpoint, AJAX action, or page in Indico.
---

# add-indico-rh

Add a new Indico endpoint. Pick the right base class, wire permissions, register in the blueprint, return the right shape.

## When To Use

Adding any new endpoint to Indico: HTML page, JSON action, form submission, file download, AJAX handler.

## Base Class Taxonomy

Pick the most specific base. Each adds permission checks, breadcrumbs, and context.

| Base | Use for |
|---|---|
| `RH` | Public, unauthenticated endpoint. Rare. |
| `RHProtected` | Requires login. No further scoping. |
| `RHEventBase` | Endpoint scoped to an event. Loads `self.event`. |
| `RHDisplayEventBase` | Public-facing event endpoint. Adds display-side context. |
| `RHManageEventBase` | Event management endpoint. Requires manage permission. |
| `RHCategoryBase` | Scoped to a category. |
| `RHAdminBase` | Server admin only. |

The bases live in module-specific `controllers/base.py` files (e.g. `indico/modules/events/controllers/base.py`). Always extend a module-local base when one exists; do not jump straight to the lowest-level `RH`.

## Skeleton

```python
# indico/modules/events/registration/controllers/management.py

from flask import jsonify, request

from indico.modules.events.registration.controllers.management import RHManageRegFormBase
from indico.modules.events.registration.util import approve_registration
from indico.modules.events.registration.notifications import notify_registration_state_change


class RHApproveRegistration(RHManageRegFormBase):
    """Approve a pending registration."""

    normalize_url_spec = {
        'locators': {
            lambda self: self.registration,
        }
    }

    def _process_args(self):
        RHManageRegFormBase._process_args(self)
        self.registration = (
            Registration.query
            .filter_by(id=request.view_args['registration_id'], is_deleted=False)
            .first_or_404()
        )

    def _check_access(self):
        RHManageRegFormBase._check_access(self)
        # extra check beyond the base
        if self.registration.event != self.event:
            raise NotFound

    def _process(self):
        approve_registration(self.registration)
        notify_registration_state_change(self.registration)
        return jsonify(success=True, state=self.registration.state.name)
```

## Method Dispatch

- Override `_process()` to handle all HTTP methods.
- Override `_process_GET()` / `_process_POST()` / `_process_DELETE()` to split by method.

## Permission Checks

- `_check_access()` runs after `_process_args()`. Override to add scope-specific checks.
- Always call `super()._check_access()` first to keep the base's checks.
- Raise `Forbidden` or `NotFound` rather than returning a 4xx manually; Indico wraps these correctly.

## Return Types

| Return | Use |
|---|---|
| `flask.jsonify(...)` | JSON API response |
| `indico.web.util.jsonify_data(...)` | JSON for Indico's AJAX modal/widget conventions (returns `data`, `flashed_messages`, etc.) |
| `render_template(...)` | HTML page |
| `WPSomePage.render_template(...)` | HTML with Indico's "Web Page" layout (sidebar, breadcrumbs) |
| `redirect(url_for(...))` | Post-Redirect-Get |
| `send_file(...)` | File download |

## Blueprint Registration

Add the route in the module's `blueprint.py`:

```python
_bp.add_url_rule(
    '/manage/registrations/<int:registration_id>/approve',
    'approve_registration',
    RHApproveRegistration,
    methods=('POST',),
)
```

URL conventions:

- Management routes nested under `/manage/`.
- IDs in path use typed converters: `<int:event_id>`, `<int:registration_id>`.
- Endpoint name is snake_case, matches the action.

## Common Pitfalls

- **Forgetting `_process_args()`**: missing route params land in `request.view_args` but `self.event` / `self.registration` are not auto-loaded by `RH`. Use the base's loaders when available.
- **Skipping `super()._check_access()`**: silently removes scope checks. Always chain.
- **Calling `commit()` manually**: Indico commits at the end of the request automatically. Manual commits break transactional fixtures and signal ordering.
- **Returning raw `dict`**: Flask serializes naively. Use `jsonify` / `jsonify_data`.
- **Forgetting blueprint registration**: 404 with no clue. Always grep the blueprint for the new endpoint name after adding.

## Testing An RH

```python
def test_approve_registration_requires_manage_permission(dummy_reg, dummy_user, test_client):
    test_client.login(dummy_user)
    resp = test_client.post(
        url_for('event_registration.approve_registration',
                event_id=dummy_reg.event_id,
                reg_form_id=dummy_reg.registration_form_id,
                registration_id=dummy_reg.id)
    )
    assert resp.status_code == 403
```

See `../write-indico-test/SKILL.md` for fixture details.

## Cross-Reference With Skills

- Find the right module → `../locate-in-indico/SKILL.md`
- Add a backing model or migration → `../add-alembic-migration/SKILL.md`
- Write the test first → `../write-indico-test/SKILL.md`
