---
name: review-indico-frontend
description: Frontend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers React components, SCSS and CSS modules, Jinja templates, i18n and client-side validation. Use through review-indico-pr or on its own for a client-only change.
---

# review-indico-frontend

Items observed in upstream review of contributor PRs and in fixes reviewers pushed to contributor branches. Check the touched `client/`, `templates/` and `.scss` files and run the UI once.

## React

- **Prefer the native mechanism.** Blocking a submit while a list row is unsaved: `setCustomValidity` on the field, not custom submit interception. "Might also be much easier."
- **Remove what the change made redundant.** A `title` that is now always present replaces `TooltipIfTruncated`; stacking both produced two competing tooltips. Combine the information into one string: `'{filename} (uploaded on {date})'`.
- **No no-op defensive handlers.** `event.preventDefault()` on an `Icon` click: "I don't think clicking an Icon has a default behavior that needs to be disabled, does it?"
- **Styling through `styleName`** (react-css-modules), not `className` plus a `:global()` selector. "Then you don't need `:global` on the `.inactive-email` part of the selector, which is much cleaner!"
- **State shape:** keep props and state snake_case or camelCase consistently with how the endpoint serializes; do not mix `camelize` on one endpoint with snake_case elsewhere.
- **Labels and messages** go through `Translate` / `Translate.string`. No bare literals a user will read.
- **Test it with long content.** Truncated names, overflowing titles and empty lists are the states upstream clicks through first.

## SCSS And CSS Modules

- A `.module.scss` whose every rule is `:global(...)` is a plain `.scss` file.
- No inline `<style>` blocks in templates; move them to a standalone CSS/SCSS file like sibling plugins do.
- Reuse existing classes (`i-button`, `badge`) before adding new ones.

## Jinja Templates

- Reuse core macros before writing your own: `{% from 'events/display/conference/_util.html' import format_event_date %}` replaced a hand-rolled start/end comparison that was always false because events have a duration.
- Whitespace control where output is inline: `{{- page -}}`.
- `title` attributes that would open an odd hover qtip on every row get `data-no-qtip`.
- Relative endpoints inside a blueprint's templates: `url_for_plugin('.list', ...)`. Values that every link needs (a `user_id` in the URL) are injected once with `@blueprint.url_defaults`, not passed at each call.
- Template file names describe the page (`my_registrations.html`), not a generic noun (`dashboard.html`).
- `{% trans %}` does not work inside a macro call argument; use `_()` there. With the plugin's bound gettext in plugins.
- Every counter or list rendered from a filtered query uses the same filtered accessor. Upstream finds the one template still showing the unfiltered total.

## Verification Upstream Does

- Hover and click every new element; tooltips, truncation and empty states are compared against the screenshot in the description.
- Resize to force truncation when the component handles long text.
- Check the rendered field order when a form field was overridden in a subclass.
- Screenshots of what broke are pasted into the review, so provide your own as proof.
