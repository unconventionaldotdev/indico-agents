---
name: review-indico-frontend
description: Frontend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers React components, SCSS and CSS modules, Jinja templates, i18n and client-side validation. Use through review-indico-pr or on its own for a client-only change.
---

# review-indico-frontend

Check the touched `client/`, `templates/` and `.scss` files and run the UI once.

## React

- Native mechanism first (`setCustomValidity` over custom submit interception).
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
- Labels are plain words; messages one concrete sentence.
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

## Verification

- Click through every page as every affected role; list what to hide (payments, ACL, tags, manage/clone/delete, customize list, logs, modify).
- Hover, truncate, empty, resize.
- Compare against the description's screenshot; attach your own.
