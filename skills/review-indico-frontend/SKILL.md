---
name: review-indico-frontend
description: Frontend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers React components, SCSS and CSS modules, Jinja templates, i18n and client-side validation. Use through review-indico-pr or on its own for a client-only change.
---

# review-indico-frontend

Check the touched `client/`, `templates/` and `.scss` files and run the UI once.

## React

- Native mechanism first (`setCustomValidity` over custom submit interception).
- Search existing components in core and official plugins before writing one (list inputs, country dropdowns, `isoToFlag`); copy and adapt rather than reinvent.
- Only the HTTP call goes inside `try/catch`; bugs in surrounding code must surface.
- Explicit `edit ? await axios.patch(...) : await axios.post(...)` over picking a method reference.
- Dialog open state lives in the parent (`editItem` state); no `cloneElement` trigger wrapping.
- No flash of empty state between load and render; pass existing data in instead of refetching; verify the loader is visible with a slowed request.
- After a mutation update local data or show "new entries available, refresh" rather than a full page reload or a refetch that resets the view.
- Reuse an existing action to reset a flag instead of adding one.
- Show the parser's own error (`JSON.parse` message) instead of a generic one.
- Persisting filter state (`localStorage` name) is optional; skip it where remembering filters makes no sense.
- No `#id` filter on objects without a friendly id.
- Test with large datasets (thousands of rows) before claiming a list scales; filter on input is fine for small lists only.
- Remove what the change made redundant (a `title` replaces `TooltipIfTruncated`; one combined string instead of two tooltips).
- No no-op handlers (`preventDefault` on elements without default behavior).
- `styleName` over `className` + `:global()`.
- Consistent casing with the endpoint; with few fields prefer snake_case over `camelize` exceptions.
- All user text through `Translate` / `Translate.string`.
- Exported components destructure props in the signature; optional callbacks are optional in the body too.
- Pure helpers at module level, not inside the component.
- Explicit over computed when nothing varies (`defaultActiveIndex={[0]}`); when an extension point makes it vary, name the hook.
- Validators return their message; skip range validators on values the user did not change (manager-set values may be out of range).
- Conditionally rendered `Final*` fields unregister on unmount and lose their value; hide with CSS or keep mounted.
- Identifier inputs reject spaces and uppercase; help text states the real uniqueness scope.
- Dialogs autofocus the first input; related short fields share a row.
- Mount React from a custom element (`customElements.define('ind-...')`) with attributes, not `window.setupX()` plus inline script.
- Labels are plain words; messages one concrete sentence. `PluralTranslate` for anything with a count.
- No labels on dropzones; fix error display another way.
- Test long content, truncation, empty states.

## SCSS

- A `.module.scss` that is all `:global` is a plain `.scss`.
- No inline `<style>`; reuse existing classes before adding new ones.

## Jinja

- Reuse core macros (`format_event_date`) before hand-rolling.
- `{{- x -}}` where output is inline; `data-no-qtip` on `title` attributes that must not open a qtip.
- `url_for_plugin('.endpoint')` inside blueprints; shared URL values via `@blueprint.url_defaults`.
- Template names describe the page; shared markup moves to a macro partial (`_name.html`).
- `_()` inside macro arguments (`{% trans %}` does not work there); plugin gettext in plugins.
- Every counter or list uses the same filtered accessor.
- Calls to action and links match the viewer's rights; a restricted role sees no link it cannot follow.
- Attribute continuation lines align with the first attribute; no blank line after a block opener.
- Plugin output reuses the core look (the standard join button, not a raw URL); pick the best available template hook and note the better one for later.

## Verification

- Click through every page as every affected role; list what to hide (payments, ACL, tags, manage/clone/delete, customize list, logs, modify).
- Test in Firefox as well as Chrome (scrollbars, loaders).
- Admin menu entries sit in the section matching their topic (`user_management` for affiliations).
- Hover, truncate, empty, resize.
- Compare against the description's screenshot; attach your own.
