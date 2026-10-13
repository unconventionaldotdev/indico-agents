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
- Shared helpers move to `indico/web/client/js/react/util/` and get imported; no copies.
- Selectors keep boolean fallbacks (`staticData.paid || false`) for keys absent in other modes; no unrelated fallback removals.
- Selection state is filtered against the current list so deleted items drop out; name id sets `xIds`.
- Optional payload keys are omitted (`selected ? {ids: selected} : {}`), never sent as `[]`.
- Format with biome (unquoted object keys where valid).
- Redux: actions are verbs (`toggleX`, `addLater`), state slices and props are nouns or booleans (`showX`, `earlier`). Mode-specific state lives in that mode's slice. Thunks read `getState()` instead of taking state as parameters. A value the action never carries is a constant in the reducer, not `action.x || false`; no fallback for state that is always initialized.
- Build request params per branch (`let url, params, body;` then one block per mode), not by accumulating across steps.
- Mode-specific filters, controls and refetch triggers are gated on the mode (`state.linking.type && ...`); leaving the mode clears its state and refetches the regular data.
- Filtered modes replace the list on every fetch instead of merging; no endless scrolling on heavily filtered results (fires immediately, duplicates on rapid toggling).
- Range controls show the current range ("Showing bookings up to N days before the event") and sit at the top and bottom of the list; link text names the action ("Load earlier bookings", not "Load more"). `PluralTranslate` even when the count is never 1 in English.
- Clickable `<a>` gets `href="#"` plus `preventDefault` so it is tabbable.
- Show the parser's own error (`JSON.parse` message) instead of a generic one.
- Persisting filter state (`localStorage` name) is optional; skip it where remembering filters makes no sense.
- No `#id` filter on objects without a friendly id.
- Test with large datasets (thousands of rows) before claiming a list scales; filter on input is fine for small lists only. Watch the request log: a view must not fire a chain of requests on load.
- Two visual states at most: actionable (white, with button) and not actionable (greyed, no button); a third shade confuses users.
- Remove what the change made redundant (a `title` replaces `TooltipIfTruncated`; one combined string instead of two tooltips).
- No no-op handlers (`preventDefault` on elements without default behavior).
- `styleName` over `className` + `:global()`.
- Consistent casing with the endpoint; with few fields prefer snake_case over `camelize` exceptions.
- All user text through `Translate` / `Translate.string`.
- Exported components destructure props in the signature; optional callbacks are optional in the body too: define the handler unconditionally and pass `cb ? handler : null`, never `const handler = cb && (() => ...)`.
- `FinalField` with `validate={null}` must keep the default required validator.
- Pure helpers at module level, not inside the component. Short named handlers above the JSX (`refresh`) over inline dispatch calls; the name says what it does, not what it looks like.
- No `console.debug` or other debug leftovers in the diff.
- A comparison token that is not a timestamp (last update plus an "undone" marker) is named so nobody parses it as one; compare with `!==` when the value never decreases.
- When concurrent edits outdate the view, every action is disabled, the comment form included; verify by changing state in a second tab. A prop that resets a form's state is a bug to understand, not a reason to leave the form enabled.
- `if (!show) return null;` before the JSX instead of wrapping the whole tree in `show && (...)`; keeps the diff reviewable.
- Local imports go before the stylesheet import.
- `useSelector(selector)`, not `useSelector(state => selector(state))`; `items.find(...)`, not `const [x] = items.filter(...)`.
- Never call `form.change` during render; use `useEffect`. Unset with `undefined`, not `null` (some field types reject `null`).
- Destructure every prop the component reads; `...rest` is only for pass-through.
- Form-wide derived state (hidden fields) is computed once in a logic-only component (`useFormState` plus a dispatch to redux), never by subscribing every item to form state. Check with React DevTools "Highlight updates" while typing.
- Coupled inputs (pick a field, then a value whose options depend on it) are one custom component driven by final-form state, not two fields with local `useState`.
- Per-type behavior (`showIfOptions`, `getDataForCondition`) lives in the field registry, not in `if/else` chains on `inputType`.
- Ambiguous short labels get an i18n comment: `/* i18n: Form field */` above the attribute (plain comment, not `{/* */}`). Labels follow cardinality ("Has value" / "Has values").
- A `ready` flag in state avoids flashing items that will be hidden once conditions resolve.
- Management views never hide items; they mark them with an always-visible icon plus tooltip and a background that changes when the condition is unmet. Icon size and alignment match the existing ones (locked, retention).
- Options the user must not pick stay visible but `disabled` in dropdowns.
- Function names follow the component spelling (`checkboxShowIfOptions`); PropTypes are the real type (`PropTypes.array`, not `node`).
- Selectors returning a function are nouns (`getPriceFormatter`, not `getFormatPrice`); no `_` prefix on locals unless shadowing a module name.
- `<Translate>` with `<Param>` inside JSX; `Translate.string` only outside markup.
- Prices are formatted locale-aware through one shared formatter that takes the item (so price and currency travel together), never `price + ' ' + currency` or `toFixed(2)`.
- Legacy jQuery code uses `$T.gettext(...)`, not `$T(...)`, and arrow functions; prefer `data-*` attributes on the trigger over an `ajaxDialog({...})` call.
- Explicit over computed when nothing varies (`defaultActiveIndex={[0]}`); when an extension point makes it vary, name the hook.
- Validators return their message; skip range validators on values the user did not change (manager-set values may be out of range). A validator handles `undefined` itself (early return in `maxLength`) instead of every call site guarding `value !== undefined &&`.
- After renaming a key or enum member (`contribution` to `contrib`), grep every TypeScript consumer; the compiler does not catch string-keyed lookups.
- New TypeScript code questions each `moment` use; native `Date` and `Intl` cover most needs.
- Dates and times are formatted locale-aware: `Intl.DateTimeFormat` with `locale.replace('_', '-')` and `formatRange` for ranges, or the existing helpers (`serializeDateTimeRange`); never hardcoded `ha` or 24h formats. Components that format dates render only after the locale is initialized.
- Client-side search over lists spreads the values into `searchableFields` (`...persons`), never `join('')`, which matches across concatenated names.
- Generalizing a behavior into a shared component (`FinalDropdown` search) means auditing every usage: option `text` may be missing or not a string; fall back to the default behavior rather than disabling the feature per consumer. Check the library's own option (`deburr`) before writing the logic.
- Conditionally rendered `Final*` fields unregister on unmount and lose their value; hide with CSS or keep mounted.
- Identifier inputs reject spaces and uppercase; help text states the real uniqueness scope.
- Dialogs autofocus the first input; related short fields share a row.
- Mount React from a custom element (`customElements.define('ind-...')`) with attributes, not `window.setupX()` plus inline script.
- No new features in the `WTF*` legacy wrappers; new behavior is React-based.
- Field values stay light (identifiers only); extra data is resolved server-side, not through callbacks that leak field internals.
- New components are generic (a file drop that hands the file to a callback), not bound to one workflow.
- Async requests behind a button (`preview`) go through `try/catch` with `handleAxiosError`; a failed submit closes overlays that would hide the error.
- Labels are plain words; messages one concrete sentence. `PluralTranslate` for anything with a count.
- No labels on dropzones; fix error display another way.
- Test long content, truncation, empty states.

## SCSS

- A `.module.scss` that is all `:global` is a plain `.scss`.
- No inline `<style>`; reuse existing classes before adding new ones.
- Never widen or restyle shared legacy classes (`exclusivePopup`); scope through `ajaxDialog({dialogClasses: 'editor-output'})` or a module stylesheet.
- Markup and classes on event display pages are a public API for custom stylesheets: keep element types (`span.conference-title-link`) and floats, test against events with custom CSS, and ship a new layout behind an opt-in setting with the old CSS as default.

## Jinja

- Reuse core macros (`format_event_date`) before hand-rolling.
- Shared templates (`forms/_form.html`) never branch on one form's id; page-specific behavior lives with that page. No `XMLHttpRequest`: `indicoAxios` in JS modules, `fetch()` in the rare inline script, and preferably no inline request code at all.
- `{{- x -}}` where output is inline; `data-no-qtip` on `title` attributes that must not open a qtip.
- `url_for_plugin('.endpoint')` inside blueprints; shared URL values via `@blueprint.url_defaults`.
- Template names describe the page; shared markup moves to a macro partial (`_name.html`).
- Several possible parents: separate `{% extends %}` in an `if/elif` chain, not nested ternaries in one `extends`.
- Side menu items: weight `-100` for entries that go last (logs); positive weights for the rest.
- `_()` inside macro arguments (`{% trans %}` does not work there); plugin gettext in plugins.
- Every counter or list uses the same filtered accessor.
- Calls to action and links match the viewer's rights; a restricted role sees no link it cannot follow.
- A disabled button explains why in its own `title`, not through a separate info icon; every visible string, button text included, goes through `{% trans %}`.
- `url_for` with the locator object only (`url_for('.resend', entry)`), no redundant parent argument.
- Data attributes read from optional objects (`invitation.lock_email`) are guarded; load the page without that object.
- Attribute continuation lines align with the first attribute; no blank line after a block opener; tag contents indented; no collapsing of multi-line markup into one long line.
- Plugin output reuses the core look (the standard join button, not a raw URL); pick the best available template hook and note the better one for later.
- Default receipt templates: copy field descriptions and options from the existing default template (affiliation toggle, address override), spell-check default texts, offer `{date_range}` with the one-day/multi-day logic plus `{start_date}` and `{end_date}`. Filters are named after what they do (`format_placeholders`), output is marked `| safe` on the expression instead of an `{% autoescape false %}` block.
- HTML emails: indent normally, `<h3>` for section titles, `<ul>` for lists, `<a>` for links (link the title), no `trim`/`indent` filters or blank-line hacks carried over from the text template.

## Verification

- Click through every page as every affected role; list what to hide (payments, ACL, tags, manage/clone/delete, customize list, logs, modify).
- Test in Firefox as well as Chrome (scrollbars, loaders).
- Admin menu entries sit in the section matching their topic (`user_management` for affiliations).
- Hover, truncate, empty, resize.
- Compare against the description's screenshot; attach your own.
