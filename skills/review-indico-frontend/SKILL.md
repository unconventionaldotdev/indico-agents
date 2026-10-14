---
name: review-indico-frontend
description: Frontend checklist for reviewing Indico core and plugin changes against upstream review standards. Covers React components, final-form fields, custom elements, SCSS and CSS modules, Jinja and email templates, i18n of user-facing strings, UI wording and the manual UI pass. Use through review-indico-pr or on its own for a client-only change.
---

# review-indico-frontend

Check the touched `client/`, `templates/` and `.scss` files and run the UI once.

## React

### Components and structure

- Function components with hooks only; no new class components.
- Components are `function` declarations, not expression-bodied arrows (`export default function X({...}) {}`), so a statement can be added while debugging.
- Component names say what the component is (`TemplateManagement`, not `Router`) and name one concept, never `XAndY`; acronyms stay uppercase (`QRDisplay`, `ShareURL`).
- Prefer named exports so the import site shows the real name; no `export default` for a component or element class used only inside its own module.
- Components used by one module stay in that module, not in the global `react/components` index.
- Pure helpers live at module level, not inside the component.
- Short named handlers sit above the JSX (`refresh`) instead of inline dispatch calls; the name says what the handler does, not what the control looks like.
- Function names follow the component spelling (`checkboxShowIfOptions`).
- `if (!show) return null;` before the JSX instead of wrapping the whole tree in `show && (...)`: keeps the diff reviewable.
- Sections with no value are not rendered (`{reason && this.renderReason(reason)}`); no empty boxes.
- Read values from props and state where they are needed instead of threading them through several method parameters.
- Follow the library's documented composition (one `Accordion` holding every `Accordion.Title`/`Accordion.Content` pair).
- Explicit over computed when nothing varies (`defaultActiveIndex={[0]}`); when an extension point makes it vary, name the hook.
- Per-type behavior (`showIfOptions`, `getDataForCondition`) lives in the field registry, not in `if/else` chains on `inputType`.
- Page-level widget scripts tolerate the widget markup being absent or reduced (a disabled variant on management pages): null-check the root lookup or return early.
- Values read from the same object are destructured in one statement; a second `const {x} = this.props` right after the main unpacking joins it (`booking, booking: {a, b}` or one separate statement for the parent).

### Shared components and reuse

- Search existing components in core and official plugins before writing one (list inputs, country dropdowns, `isoToFlag`); copy and adapt rather than reinvent.
- Shared helpers move to `indico/web/client/js/react/util/` and are imported from there; no copies.
- New components are generic (a file drop that hands the file to a callback), not bound to one workflow.
- A component shared across modules takes its URL builders as props (`getAllURL`, `createURL`, `editURL`); module-specific params are bound in the caller's closure and never known to the component.
- Generic widgets take a render prop (`actionView` receiving the item) instead of a config object enumerating use cases.
- Changing a shared component (date picker year range) is checked in every consumer (room booking); defaults stay generic and consumers narrow them (`yearsBefore={0}`).
- New wrapper props go in the component's `PROP_BLACKLIST` so they never reach the wrapped library component.
- Generalizing a behavior into a shared component (`FinalDropdown` search) means auditing every usage: option `text` may be missing or not a string; fall back to the default behavior instead of disabling the feature per consumer.
- Check the library's own option (`deburr`) before writing the logic yourself.
- When a library input is swapped for a custom one, every prop the old call received (`disabled`, `required`, `onFocus`, `onBlur`, placeholder) is forwarded or deliberately dropped.
- Replacing a library component removes its dead props at every consumer (`disabledDate={() => false}`, `initialVisibleMonth`), its constants imports, the CSS targeting its classes (`:global(.DateRangePicker_picker)`) and callbacks only it called.
- Remove what the change made redundant (a `title` replaces `TooltipIfTruncated`; one combined string replaces two tooltips).
- Once a more specific rendering covers a case (weekly recurrence listing its weekdays), the generic branch for that case is deleted, not kept as a fallback.
- Plugin hooks are fetched once (`const hooks = getPluginObjects('onX')`) outside the loop that runs them.
- `UserSearchTokenContext.Provider` and a `search-token` attribute appear only when the mounted tree contains a user search widget.

### Hooks and local state

- A `useEffect` registering a listener returns the cleanup.
- State updated through a chain of transformer functions is `useReducer`.
- Persisting UI state (filters) in local storage: one `useEffect` with `[]` loads it once; saving happens in the change handlers, not in a second effect watching the state.
- Persisting filter state (`localStorage` name) is optional; skip it where remembering filters makes no sense.
- A `ready` flag in state avoids flashing items that will be hidden once conditions resolve.
- Form-wide derived state (hidden fields) is computed once in a logic-only component (`useFormState` plus a dispatch to redux), never by subscribing every item to form state.
- A controlled picker takes `value` and `onChange`: no `useState` mirrored from props through `useEffect`, no effect calling `onSelect` on every render, no `setTimeout` repairing an empty selection.
- Constraints such as `requireOneSelected` are enforced as an early return in the click handler.
- Adapting a controlled component to a SUI-style handler happens at the call site (`onChange={value => this.onWeekdaysChange(null, {value})}`).
- UI state over a list is keyed by the item's natural key (`{[date]: expanded}`), not array indexes; a curried handler (`onClick={handleHeaderClick(date)}`) replaces index bookkeeping.
- Selection state is filtered against the current list so deleted items drop out.
- A comparison token that is not a timestamp (last update plus an "undone" marker) is named so nobody parses it as one; compare with `!==` when the value never decreases.
- Nothing time- or locale-dependent is computed at module load (`const TODAY = ...`); compute it in the handler or as a default parameter.
- Multi-state interaction logic (selection state x trigger used x click target) is implemented as pure functions driven by the agreed outcome table, so a corrected row is a one-line change.

### Redux

- Actions are verbs (`toggleX`, `addLater`); state slices and props are nouns or booleans (`showX`, `earlier`).
- Mode-specific state lives in that mode's slice.
- Thunks read `getState()` instead of taking state as parameters.
- A value the action never carries is a constant in the reducer, not `action.x || false`; no fallback for state that is always initialized.
- `useSelector(selector)`, not `useSelector(state => selector(state))`.
- Selectors keep boolean fallbacks (`staticData.paid || false`) for keys absent in other modes; no unrelated fallback removals.
- A selector fallback is a module-level constant (`const EMPTY_DATA = {}`), never a literal inside the selector.
- Selectors returning a function are nouns (`getPriceFormatter`, not `getFormatPrice`).
- Reuse an existing action to reset a flag when its name fits the new use; when reusing would mislead, duplicate the one-line action under a fitting name instead.
- Redux request slices expose `isXFailed` and `getXFailedMessage` selectors (`request.error?.message`) so components can show the failure in place.
- Mode-specific filters, controls and refetch triggers are gated on the mode (`state.linking.type && ...`); leaving the mode clears its state and refetches the regular data.
- Admin-only menu entries and sections are gated on the positive admin flag (`isAdmin`), never on the negation of another role flag; a derived "role X and not admin" boolean is a smell.

### Props and PropTypes

- Exported components destructure props in the signature; destructure every prop the component reads; `...rest` is only for pass-through.
- Optional callbacks: define the handler unconditionally and pass `cb ? handler : null`, never `const handler = cb && (() => ...)`.
- A wrapper that preconfigures a component spreads the inner `propTypes` (`...FinalPersonLinkField.propTypes`, an inner component reusing `Wrapper.propTypes`).
- Props absent outside a mode are optional with a `null` default, never `isRequired`; props a connected selector always supplies are `isRequired` with no `defaultProps` entry.
- PropTypes match the value: `string` for a string enum (not `bool`), `PropTypes.array` for an array (not `node`).
- A rendered prop is `PropTypes.node` (or `oneOfType([PropTypes.string, PropTypes.node])`), never `PropTypes.object`.
- Object-valued props use `PropTypes.shape({...})`, never `PropTypes.object`; the shape of API data lists exactly the keys the current payload carries; keys that may be empty are not `isRequired`.
- A PropTypes warning is fixed by widening the type at the component, not silenced.
- A prop that every call site leaves at its default is removed; add it with the consumer that needs it.
- Placeholder values that are never rendered are plain strings, not `Translate.string`; a `defaultProps` value nobody relies on is `''` or `null`, not a translatable string.
- Converting a `.jsx` to `.tsx` drops `propTypes`; every prop lands in a typed interface and unused props or types are removed.
- No branch for values the TypeScript type rules out.
- After renaming a key or enum member (`contribution` to `contrib`), grep every TypeScript consumer: the compiler does not catch string-keyed lookups.
- SUI states are props (`primary={selected}`, `disabled={disabled}`), never class name strings assembled by hand; primary actions use `primary`, not `color="blue"`.
- Boolean DOM properties receive booleans (`el.hidden = !!numMatches`), never a count.
- `propTypes` keys follow the order of the props in the component signature, not alphabetical order.
- A plugin component rendered inside a form receives the minimal submission state it needs (`disabled`), never the whole `formProps` object; every surface rendering the entry point passes the same prop set.

### Final-form structure

- Dialogs with a form use `FinalModalForm`, never `FinalForm` plus `Modal` assembled by hand; submit buttons are `FinalSubmitButton`.
- `FinalForm` takes the render callable as children, never through the `render` prop.
- Inside a `FinalForm` render tree `form` is already in scope through the render props; no `FormSpy` just to reach it.
- A `FormSpy` that is needed sets `subscription={{}}` or only the keys it reads.
- Never call `form.change` during render; use `useEffect`. Unset with `undefined`, not `null` (some field types reject `null`).
- Unmounting a `FinalForm` drops its state; no `form.reset()` on cancel.

### Final-form fields

- A field that does not apply in the current mode is not rendered; never `type: 'hidden'` to blank it.
- A `Final*` field whose value must survive while hidden stays mounted and is hidden with CSS, because conditionally rendered fields unregister on unmount and lose their value.
- Hiding a mounted `Final*` field with CSS is `style={hidden ? {display: 'none'} : {}}`, not an always-present style object with a conditional value.
- `FinalField` with `validate={null}` must keep the default required validator.
- `FinalDropdown` gets only non-default props (no `hideValidationError`, `multiple={false}`, `search={false}`).
- A field wrapper passes `FinalField` only the props it needs; forwarding `{...props}` with `description` renders it twice.
- Wrapped final-form fields pass `onFocus` / `onBlur` to the inner input, and call both on non-input interactions like a trigger click, so `touched` works and errors show on blur.
- `required` yields a distinct "Please provide the X" message per sub-field; `value` may be `null` under `allowNull`.
- A `FinalField` whose value is an array or object passes `isEqual` (`unsortedArraysEqual` from `indico/react/forms` for order-free lists, `_.isEqual` otherwise), and the `FinalForm` gets `initialValuesEqual={_.isEqual}`: otherwise dirty tracking and reinitialization misfire.
- Coupled inputs (pick a field, then a value whose options depend on it) are one custom component driven by final-form state, not two fields with local `useState`.
- Initial values derive from the data present (`fileData[htmlName]`), not from a mode flag (`isUpdateMode`), so plugins can prefill in other modes.

### Popup forms

- A popup form is still a final-form: `onSubmit` posts the form `data` object as is and returns `handleSubmitError(e)` on failure; no status-code branching, no `handleAxiosError`, no local `error` state.
- In a popup form the field is a `FinalInput` whose `name` equals the webargs kwarg (`server_url`) so the server error lands on the field.
- A popup form subscribes to `pristine`, `submitting`, `submitError`, `submitFailed`, `dirtySinceLastSubmit`, shows `submitError` only while `!dirtySinceLastSubmit`, and its submit button is `disabled={pristine || submitting || (submitFailed && !dirtySinceLastSubmit)}` with `loading={submitting}`.

### Field values and payloads

- Optional text fields never send `''`: `nullIfEmpty` on the field, `onlyIf` in the serializer, `reason || undefined` when the edit payload is built by hand (a nicer validation error than "field cannot be null").
- The empty value of a field is its canonical empty shape (`{}`), never a sentinel key (`{'': -1}`); for a non-required field the empty value gets submitted.
- Field values stay light (identifiers only); extra data is resolved server-side, not through callbacks that leak field internals.
- Client state holds a multi-value field in the shape the API takes (a sorted array of keys, `PropTypes.arrayOf(PropTypes.string)`, payload key `recurrence_weekdays`) so the serializer passes it through; no object-of-booleans converted at the boundary.
- Optional payload keys are omitted (`selected ? {ids: selected} : {}`), never sent as `[]`.
- Build request params per branch (`let url, params, body;` then one block per mode), not by accumulating across steps.
- Keep casing consistent with the endpoint; with few fields prefer snake_case over `camelize` exceptions.
- A count comes back as `count` and lands in `numX`.
- A query-string rule for a list param parses a single value into a one-element array (`if (!Array.isArray(value)) value = [value]`).
- `data-*` attributes carry values the JS reads (sorting text), never an object repr.
- Multi-value text inputs split on `,` and `;`.
- Before flagging a `null` payload key, trace the request builder: shared serializers (`preProcessParameters`) already drop null leaves, only hand-built params need a guard.

### Validation

- Native mechanism first (`setCustomValidity` over custom submit interception).
- Validators return their message.
- Skip range validators on values the user did not change: manager-set values may be out of range.
- A validator handles `undefined` itself (early return in `maxLength`) instead of every call site guarding with `value !== undefined &&`.
- The visual required marker and the actual validation are two props (`showAsRequired`, `isRequired`); a management override relaxes the validator and leaves the asterisk.
- Custom form items (`customFormItem`) receive `showAsRequired` like the generic path; a checkbox marks it with the `required` class on `fieldProps.className`.
- A custom `validate` honors `isRequired`: the empty-value message is returned only when required (`isRequired ? Translate.string('...') : undefined`); format checks on a filled value stay unconditional.
- A non-required field still validates what was typed; input matching no option is an error, not silently treated as empty.
- Identifier inputs reject spaces and uppercase; help text states the real uniqueness scope.
- After a widget changes semantics mid-review (combobox to select), validation branches for input it can no longer produce are removed.
- Show the parser's own error (`JSON.parse` message) instead of a generic one.
- No hardcoded allowed-extension lists in the client when a configurable mechanism exists; restrictions are data enforced server-side.
- Help text is dropped when the control already enforces the constraint or the explained feature is secondary.

### Dropdowns, options and filters

- Lists of options come from the data the server sends (default templates), never a hardcoded list; the "blank" or default choice goes first.
- Options the user must not pick stay visible but `disabled` in dropdowns.
- Option values are the identifiers; a selection is never resolved by matching captions, which are not unique (an option removed and re-added with the same caption).
- A dropdown that acts as a text input hides its icon (`icon=""`).
- A text input that drives a custom listbox sets `autoComplete="off"` so the browser autofill popup does not cover the options.
- A clear button on a select-like control is hidden when the field is `required`, disabled together with the field, and clearing leaves the list closed (clearing means empty, not change).
- Autocomplete never rewrites what the user typed (no case change on match); matching is case-insensitive without replacing the input.
- Dependent controls (slot count after a choice) reset to a valid value when the parent choice changes and disappear when it is cleared; the displayed value always equals the submitted one.
- Data for a dropdown loads once with `useIndicoAxios` (`{manual: true}` when not always needed) plus an explicit "refresh" button, not on every open: a refetch on open also retriggers dependent effects (previews).
- Client-side search over lists spreads the values into `searchableFields` (`...persons`), never `join('')`, which matches across concatenated names.
- Filter semantics: a single selected value matches every item containing it; a "multiple values" filter is a separate option.
- Filtering on input is fine for small lists only.
- No `#id` filter on objects without a friendly id.
- No side-by-side radio buttons: a mode selector uses the widget sibling fields use (`FinalDropdown`); a two-state option is a `FinalCheckbox` `toggle` worded so the default is unchecked.
- A toggle button that is on but locked keeps `active` and adds `disabled`, so its state stays visible.

### Dialogs

- Dialog open state lives in the parent (`editItem` state); no `cloneElement` trigger wrapping.
- One `Confirm` for the selected item, with the item's identifier in state, never one rendered per row (a boolean flag opens all of them and the last one wins).
- One-click actions that are hard to undo get a confirmation dialog.
- A mode that users repeat (linking several occurrences) is not exited after one success.
- Dialogs autofocus the first input; related short fields share a row.
- The cancel button of a dialog sets the open state to `false`.
- A dialog opened from imperative code is mounted with `injectModal` resolving a promise, not a global `CustomEvent` on `window`.
- Deletions use `RequestConfirmDelete` with `persistent` and a `requestFunc` that returns `true` on error after `handleAxiosError`; the component handles the busy state, so no own `submitting` flag.

### Popups and overlays

- Popups and pickers close when their trigger is clicked again or on an outside click.
- When the outside-click handler fires before the trigger's own click, check `button.contains(evt.target)` and set an ignore flag for the next click, never a timeout.
- A popup that opens a nested popup becomes controlled (`open={isOpen}`) and its `onClose` ignores closes while the child popup is open (`onClose={() => !isChildOpen && setIsOpen(false)}`); the child reports its state through `onOpen` / `onClose`.
- Popups position inside the viewport and above sticky navigation (`position: fixed`, clamped); a popover opens above the trigger when there is no room below; no full-screen portal fallback.
- A `position: fixed` popup inside a transformed ancestor (a centered modal) is offset: fix it in that page's stylesheet.
- A failed submit closes overlays that would hide the error.
- `window.open` after an awaited request trips popup blockers: open on the user's own click, or show a success message with a button that opens the window.
- No translucent control overlaid on an image users may screenshot or photograph; place the action next to it.
- A trigger whose meaning changes after a click (generate, then download) changes its icon and `title` accordingly.

### Data fetching and errors

- Only the HTTP call goes inside `try/catch`; bugs in surrounding code must surface.
- Async requests behind a button (`preview`) go through `try/catch` with `handleAxiosError`.
- Explicit `edit ? await axios.patch(...) : await axios.post(...)` over picking a method reference.
- An `ExpectedError` (HTTP 418) from a data request is shown in place as `<Message error content={error.response.data.message} />` by the component that fired it, before falling back to `handleAxiosError`.
- A fetch helper that handled its error returns nothing; callers check `if (!res) return;` before destructuring.
- Inputs are disabled while their data loads (`disabled={loading}`).
- No flash of empty state between load and render; pass existing data in instead of refetching.
- No loader for a request that is always fast; loaders for slow requests appear after about 500 ms so fast responses do not blink.
- `data || []` turns a pending or failed request into the empty mode; gate on `data !== null`.
- A component must render while fetched data is still `null` (`data?.map(...)`): an exception during the first render unmounts the tree.

### Data updates and navigation

- After a mutation update local data or show "new entries available, refresh" rather than a full page reload or a refetch that resets the view.
- Filtered modes replace the list on every fetch instead of merging; no endless scrolling on heavily filtered results (it fires immediately and duplicates on rapid toggling).
- When concurrent edits outdate the view, every action is disabled, the comment form included.
- A prop that resets a form's state is a bug to understand, not a reason to leave the form enabled.
- A dummy entry injected for the empty case (`id: -1`) must not be confused with a real single entry: branch on the raw list, and use the same condition on every surface that pads.
- Inside an SPA, redirect with `useHistory().push(url)`, never `location.href`.
- After `location.href = ...` in a submit handler, `await new Promise(() => {})` so the form never leaves the submitting state.

### URLs and links

- Links use `indico-url:` builders (`tosURL()`), never hardcoded hrefs (`/tos`); every linked route is checked to exist.
- Query parameters of an `indico-url:` builder are passed as an object (`qrCodeImageURL({url, box_size})`), never concatenated with `?` and `encodeURIComponent`.
- Imports from `indico-url:` end in `URL` and match the endpoint name (`sessionBlocksURL` for `api_session_blocks`).
- Links never force a new tab (`target="_blank"`), except links rendered inside an editor preview.
- A clickable `<a>` gets `href="#"` plus `preventDefault` so it is tabbable.
- Links inside a checkbox label call `evt.stopPropagation()` so following the link does not toggle the checkbox.
- A link inside a translated sentence is a `<Param name="x" wrapper={<a href={xURL()} />}>` in one `<Translate>`.

### Lists, keys and pagination

- Lists sort with natural order: `new Intl.Collator(undefined, {numeric: true, sensitivity: 'base'})` and `collator.compare`.
- React `key` values are stable and unique per item (`file.path`, an id stored at creation): never `nanoid()` or `Math.random()` in render, never `file.size`, never a value the user can edit into a duplicate.
- A single element outside a list gets no `key`.
- `{count && <X />}` renders `0` when the count is zero; coerce with `!!list?.length`.
- Pagination controls hide what cannot change the view: no page-size picker when the smallest size fits every row, and only sizes below the row count plus "all".
- An empty list keeps the surrounding controls (search box, count) and shows a message where the rows would be.
- Tabs and groups keep the order managers configured.
- Range controls show the current range ("Showing bookings up to N days before the event") and sit at the top and bottom of the list.
- Range link text names the action ("Load earlier bookings", not "Load more").

### Item states and tooltips

- Management views never hide items; they mark them with an always-visible icon plus tooltip and a background that changes when the condition is unmet.
- Icon size and alignment of a new marker match the existing ones (locked, retention).
- Two visual states at most: actionable (white, with button) and not actionable (greyed, no button); a third shade confuses users.
- Struck-through text marks invalid items.
- A missing optional value renders nothing, never an invented label ("Unlisted").
- A tooltip does not repeat what is already visible next to it (date only when the time is in the row), with a one-line comment saying so.
- A tooltip with a date shows just the date in a `<time>` element, no translatable "On {date}".
- When a change removes a disabled state that displayed an effective value (the profile timezone in a greyed select), the value is shown another way (a hint line, a marked option).

### Interaction and layout

- A row that looks clickable toggles its checkbox from anywhere in the row; a pointer cursor only where clicking does something.
- An icon that looks like an expander expands something.
- A control inside a clickable header calls `evt.stopPropagation()` with a comment naming the parent handler it blocks.
- Buttons inside a form that do not submit get `type="button"`.
- No no-op handlers (`preventDefault` on elements without default behavior).
- No hover styling on non-interactive text.
- A new field aligns with its sibling fields; a widget variant matches its sibling in icon placement and alignment.
- Decorative elements that convey nothing are removed.
- No labels on dropzones; fix error display another way.
- Icons next to truncatable text get `flex-shrink: 0`; long names stay on one line with an ellipsis.
- `overflowY: 'auto'`, not `scroll`.
- Inputs for code-like values (regexes, URL patterns) use a monospace font.
- Rich text produced by the editor is rendered inside an `editor-output` container, in React (`dangerouslySetInnerHTML`) and Jinja (`sanitize_html` output) alike.
- Generated color palettes are deterministic per id, vary hue first and saturation/brightness after, and derive the text color from the background by a contrast rule.
- Controls with no alternative activation on touch devices stay visible.
- Icons follow the concept, not the glyph: reuse the icon the codebase already uses for that concept (`icon-quill` for registration) even when a more literal glyph exists in the font.

### Dates, prices and locales

- Dates from the server are formatted with `toMoment(x).format('L')`, never shown as a raw date string.
- Dates and times are formatted locale-aware: `Intl.DateTimeFormat` with `locale.replace('_', '-')` and `formatRange` for ranges, or the existing helpers (`serializeDateTimeRange`); never hardcoded `ha` or 24h formats.
- Components that format dates render only after the locale is initialized.
- New TypeScript code questions each `moment` use: native `Date` and `Intl` cover most needs.
- Dates cross component boundaries as ISO `YYYY-MM-DD` strings (`PropTypes.string`); consumers convert at the edge with `serializeDate` / `toMoment`; no moment or `Date` objects where siblings take strings.
- A possibly empty date string is parsed with `toMoment(value, format)`, never `moment(value, format)`.
- Date-only values never go through `new Date('yyyy-mm-dd')` or `toISOString()` (UTC shift); `toLocaleDateString('en-CA')` with a comment saying why.
- Date format constants are `export const ISO_FORMAT`, never hung on a function object.
- The current locale comes from Indico (`moment.locale()`), never from the browser; translation directory names convert to BCP 47 (`de_DE` to `de-DE`).
- First day of week and weekend days come from locale data (`new Intl.Locale(name).weekInfo`), never hardcoded Monday.
- Weekday and month names are never hardcoded English strings; labels come from moment locale data (`moment.weekdays(true)`, `moment().isoWeekday(wd).format('ddd')`).
- A stored weekday key is computed locale-independently (`.locale('en').format('ddd').toLowerCase()`).
- Prices are formatted locale-aware through one shared formatter that takes the item (so price and currency travel together), never `price + ' ' + currency` or `toFixed(2)`.

### Date picker contract and bounds

- A date picker's contract: `value` in and `onChange` out are ISO strings; `format` only drives display, parsing and the hint, defaulting to the locale (`moment.localeData().longDateFormat('L')`).
- The initial value is reformatted before it reaches the text input; free-text input is reformatted once it parses; two-digit years are rejected.
- A hand-written date parser lives in its own module under `utils/`.
- A picker's invalid-input sentinel never reaches consumers expecting a date or `null` (`invalidValue` prop); validators compare against it, side-effect handlers skip it.
- A date picker opens on the period currently displayed, not on today.
- Date bounds are declarative props (`min`, `max`, `rangeStartMin`, `rangeEndMax`), not a per-date callback; when a bound depends on another field, track that field as state and pass the bound.
- A `min` shorthand on a range sets both sides' minimum; a side's min and max are never the same value.
- Each bound has its own helper encoding its rule; a date bound is never derived by truncating a time bound.
- A `min`/`max` on one control that another path bypasses (year input vs calendar navigation) is enforced on both.

### Date picker interaction

- Locking one end of a range (`startDisabled`) applies to its input, its trigger and the dialog's state machine; restoring state on close reapplies the lock.
- A prop ignored because a precondition is missing emits `console.warn`.
- `readOnly` (the form does not let the user change it) and `disabled` (temporarily unavailable) are two props; a `readOnly` picker also disables its triggers.
- `disabled` reaches every interactive child of a composite input and matches the SUI look next to it.
- A text input paired with a picker stays typeable: only the trigger button opens the picker.
- When the picker dialog closes, focus returns to the trigger, never to a text input.
- Clicking the already-selected day keeps it selected and advances; it never deselects.
- Hovering a day previews the resulting range; one pure selection function drives preview and click in both the field-based and the inline picker.
- A multi-month calendar never shows the same date twice; an inline calendar reflects the pending selection before "Apply".
- A widget's calendar is its own custom element (`<ind-calendar>`) with its own React wrapper.
- When one form field alternates between a single-date and a range picker, the single variant adapts its value to the range shape through a thin wrapper and the validators unwrap it, so the stored value shape never changes with the mode.

### Accessibility

- The calendar grid is a `role=listbox` of `role=option` buttons with roving `tabIndex`, `aria-selected` per day and `aria-disabled` outside the bounds.
- Arrow keys leaving the month switch it and focus the target day.
- A `querySelector` that can match nothing is null-checked.
- A mode change inside a picker is announced through an `aria-live` region or a visible indicator.
- A format hint screen readers need stays in the DOM under `%visually-hidden`; a `placeholder` alone is not announced.
- Sub-labels with an obvious default (`rangeStartLabel`) are optional with translated defaults.
- Where space is tight the label stays in the DOM visually hidden, never removed; a trailing `:` is not rendered when the label is empty.

### i18n

- All user text goes through `Translate` / `Translate.string`, including text only exposed through constraint validation or assistive tech (`internals.setValidity(..., msg)`, visually hidden labels, filter labels inside a `<dialog>`).
- `<Translate>` with `<Param>` inside JSX; `Translate.string` only outside markup, so `{Translate.string(...)}` never appears inside JSX.
- `<Translate as="label">Recurring every</Translate>` when the translated string is the whole element.
- `Translate.string('Template "{title}" was added', {title})`, never a template literal inside `Translate.string`.
- A sentence is one translatable string, never assembled from translated fragments; each variant of a sentence is its own full `<Translate>` block, not conditional fragments joined with `and`.
- Words between placeholders ("and") live in the translatable string, never inside a `<Param>` value; `<Param>` names are plain singulars (`weekday1`, `weekday2`), not `weekdays_1`.
- An enumeration ("A, B and C") is built from `list.slice(0, -1).map(...).join(', ')` plus the same `<Translate>` used for the two-item case; never `.join(', ').replace(...)` on the last separator.
- `PluralTranslate` for anything with a count, even when the count is never 1 in English; one `PluralTranslate` per sentence with `<Singular>`, `<Plural>`, `<Param>`.
- Surrounding punctuation sits outside `<Translate>` / `<PluralTranslate>`.
- Literal punctuation in JSX is text (`(`), not `{' ('}`; check braces that leak into the output (`{'}'}`).
- Interpolated titles are quoted (`'View the "{title}" category'`), aria labels included.
- Product and format names ("Google Wallet", "PDF") are not translated.
- Ambiguous short labels get an i18n comment: `/* i18n: Form field */` above the attribute (plain comment, not `{/* */}`).

### Wording

- Labels follow cardinality ("Has value" / "Has values").
- Sentence case in every user string including placeholders and options; option labels do not repeat the widget type ("Expanded", not "Expanded dropdown"); the field label names what is displayed.
- Short hints carry no trailing period; full sentences do.
- Labels are plain words and reuse the existing term ("Venue", not "Location"); messages are one concrete sentence.
- Status messages speak from the user's side ("Your data is being prepared. We will notify you by email ..."); "by email", not "via email".
- Source strings are American English ("Program", "Analyze").
- Setting descriptions say when, not whether ("Specify when a booking reason must be provided.").
- Before proposing a wording change, grep the module templates and JS for the term the UI already uses for the same people or objects and reuse it ("participants" for registrants).

### Naming

- Generic loop variables are `x`; event handler parameters are `evt`, never `e`.
- Counts are `xCount` or `numX`, never `numberOfX`; sets of ids are `xIds`.
- Only components are PascalCase; plain functions are camelCase, also in registries.
- No `_` prefix on locals unless shadowing a module name.
- Handler locals never shadow a name of the enclosing component (`selected` next to `selectedChoice`); the lint warning is fixed by renaming.
- Locals are named by what they control (`showAsRequired`, `inputRequired`), not by the mode they were introduced for (`managementRequired`).

### Code style

- Arrow functions for callbacks and returned closures, never `function()` expressions.
- A callback with a single return is an expression-bodied arrow; a two-branch return is a ternary, not `if`/`return`.
- Boolean dispatch is an `if / else if / else` chain, never `switch (true)`.
- A value-to-value mapping is an object lookup (`{category: 'categoryId', ...}[groupBy]`), not a `switch`; `if (!attr) throw` when validation is wanted.
- Handlers start with guards (`if (busy) return;`) and keep the main path flat; nested `if`s with no code between them merge into one condition.
- Optional params are explicit (`position = undefined`); never `return` a value the caller ignores.
- Object properties with static names use dot access (`options.has_no_files`); optional chaining (`data?.count || 0`) over `(data && data.count) || 0`.
- No `?.` on a value an earlier line already dereferenced unconditionally; either guard the first access or drop the operator.
- No defensive normalization for input callers never produce: no `[...new Set(x)]` when duplicates cannot occur, `if (x.length === 0)` rather than `if (!x || x.length === 0)` unless `null` is a real input.
- No fallback chains for values the page always sets.
- `items.find(...)`, not `const [x] = items.filter(...)`.
- Id lookups use a plain object, not a `Map`, unless measured.
- A value built in two statements becomes one `const` expression.
- Related values are destructured together (`const {createdDt, modifiedDt} = block`).

### Comments, lint and formatting

- Layout magic numbers get a comment with the reason.
- Note comments use `XXX:` for general notes and `TODO:` for actual work items, never `NB:`; long comments wrap at the line length, in SCSS too.
- A comment describing a group of declarations moves with them.
- `eslint-disable` comments name the rule; no `eslint-disable-next-line no-undef` for a global a module provides (import it: `import _ from 'lodash'`).
- No `console.debug` or other debug leftovers in the diff.
- Format with biome (unquoted object keys where valid).

### Imports, dependencies and bundling

- Local imports go before the stylesheet import; imports with side effects (stylesheets) go last since they cannot be auto-sorted.
- Shared components come from the `indico/react/components` re-export, not deep paths.
- Cross-module imports use the `indico/modules/...` alias, never `../../../` paths climbing out of the module.
- JSX works in `.js` files; never `React.createElement(...)` by hand.
- No `window.` prefix on globals (`URL.createObjectURL`).
- Defer to the next tick with `_.defer(...)`, not `Promise.resolve().then(...)`.
- No lodash for what the platform provides (`Object.keys`, `Object.values(x).some(...)`), and no reimplementation of what a dependency in use provides (`_.range`, `nanoid`).
- Nothing loads from a CDN (pdf.js worker, editor assets): ship it through webpack (`CopyWebpackPlugin` into `dist/js`, `workerSrc` pointing there).
- A heavy module is lazy-loaded behind a wrapper component with a `Loader` (`await import(...)` in `useEffect`), the inner component reusing `Wrapper.propTypes`.
- Admin-only code goes in its own bundle (`module.json` `partials: {admin: './admin.js'}`, page bundles `module_x.admin.js`) so regular pages do not load it.
- Empty `index.js` files are deleted.
- Build-time scripts (`preval`) follow the runtime lint style and skip unexpected input (an unofficial locale directory) with `try/catch` plus `continue` and a comment.
- A new `client/js` directory that other bundles import by module path gets a path alias in `jsconfig.json` in the same change, or is imported relatively.

### Custom elements

- Mount React from a custom element (`customElements.define('ind-...')`) with attributes, not `window.setupX()` plus an inline script.
- Mount custom elements with `CustomElementBase.defineWhenDomReady(...)`.
- Custom elements that mount React in `connectedCallback` unmount it in `disconnectedCallback`.
- Custom elements are registered once from `indico/web/client/js/index.js`; components use the tag without importing the element module; siblings in `custom_elements/` import each other relatively.
- File order in a custom element module: component, its `propTypes` right after it, `customElements.define(...)` last.
- A custom element rendered from JSX reacts to every attribute React may change after mount (`observedAttributes` plus `attributeChangedCallback`).
- Boolean attributes are written `attr={flag || undefined}` and read with `hasAttribute`; the raw attribute string never reaches a boolean prop.
- Attributes the component stopped reading are removed from the element and the template.
- Custom element attributes carry one value each (`google-calendar-params`, `outlook-calendar-params`), never a delimited string the component splits (it breaks when a value contains the delimiter).
- Custom elements generate ids the same way: `static lastId` on the class and `<tag>-<n>` (`date-picker-3`), no ad hoc module counter and no `x-` prefix.

### Legacy JS

- No new features in the `WTF*` legacy wrappers; new behavior is React-based.
- Legacy jQuery code uses `$T.gettext(...)`, not `$T(...)`, and arrow functions.
- Prefer `data-*` attributes on the trigger over an `ajaxDialog({...})` call.
- Legacy JS keeps its `$('html').data('static-site')` branch around anything that opens a dialog.
- No `XMLHttpRequest`: `indicoAxios` in JS modules, `fetch()` in the rare inline script.

## SCSS

### Scope and selectors

- Styles of a single widget go in a `.module.scss` used through `styleName`, or nest under a unique root (the custom element tag); bare class names collide across pages.
- `styleName` over `className` + `:global()`.
- Class names are kebab-case, in CSS modules too.
- Classes that exist for JavaScript carry the `js-` prefix (`js-popup-container`); styling classes never double as hooks.
- A `.module.scss` that is all `:global` is a plain `.scss`; it never styles document-wide elements (`body`).
- `:global(.lib-class)` rules nest inside the component's own class, never at the top level.
- Rules sit under the element they style (`ind-date-picker` vs `ind-calendar`); check the compiled output.
- Layout fixes that only one page needs go in that page's `.module.scss`, not the component stylesheet.
- No inline `<style>`; reuse existing classes before adding new ones.
- No structural selectors into a third-party component's DOM (`> div:first-child > div > div`); add a class to the target element.
- Semantic elements (`<b>`) over single-purpose utility classes (`.bold`).
- A new log realm gets its icon in `logs.scss`.

### Partials, palettes and tokens

- Every bundle's main stylesheet forwards the reset first (`@forward 'base/reset';` before design-system `@use`s); check the reset before zeroing margins or padding.
- `@use 'base/palette' as *;` for shared partials, never `@import`; a palette `@import` that nothing in the file uses is removed.
- `@use` and other SCSS string paths take single quotes; relative imports between files of one package are written `./name` so they are not mistaken for top-level modules.
- A color used by one module goes in that module's palette (`rb:styles/palette`), not `base/_palette.scss`, and is named by role (`$filters-disabled-color`), not by shade (`$hazy-gray`).
- Every referenced CSS custom property resolves to a defined token.
- A rule for markup that no longer exists (`.i-button.signin`) is deleted when found next to the change; check `git log -S` for the removed markup.
- Unusual CSS values copied from a reference (system colors such as `Highlight`) cite the source in the thread or a comment.

### Framework overrides and legacy classes

- Never widen or restyle shared legacy classes (`exclusivePopup`); scope through `ajaxDialog({dialogClasses: 'editor-output'})` or a module stylesheet.
- Markup and classes on event display pages are a public API for custom stylesheets: keep element types (`span.conference-title-link`) and floats, and ship a new layout behind an opt-in setting with the old CSS as default.
- A library feature is enabled through the component's prop (`<Modal dimmer="blurring">`), never re-implemented with a `:global(.ui.dimmer)` rule.
- SUI styling leaks into nested controls of a widget placed inside `.ui.form`: the widget matches the size and density of neighbouring SUI controls, and the overrides are wrapped in named mixins so the debt can be found later.
- Framework override values (fonts, radii) are mixins in `_sui_debt.scss` and are not repeated in component stylesheets; a value also used outside SUI moves into that module, and nothing inside it is polished further.
- A custom element's disabled and hover styling lives in its own stylesheet, never inherited from a framework ancestor (`.ui.field`).
- Never edit the pasted icomoon block in `_icons.scss`; custom placeholders and overrides go after the `/* End of icomoon's icon definitions */` marker.
- `::before` rules cannot be extended, so an `%icon-x` placeholder duplicates the rule below the marker.
- A WTForms page keeps the standard `i-form` layout and never ships per-page CSS overriding `.i-form` or `.form-field`; a page needing a non-standard form layout is built in React.

### Visual details

- Dialog and list heights relative to the viewport use `vh`, not `em`.
- No device detection for layout; responsive through CSS or deferred.
- Focus styling on custom controls uses `:focus-visible`, never `:focus`, so a mouse click does not leave the ring on the control (or on a previously opened sibling).
- Hovering an already-selected item uses a distinct shade of the selection color; empty filler cells get no hover effect.
- Picker list items use compact padding (`var(--content-gap-within-inline)`).
- A floating panel gets a border plus shadow.
- A replacement dropdown matches the SUI one: same width, same clear icon, option text aligned with the input text, no bottom radius on the input while expanded, listbox above surrounding content (`z-index`), list height of 6 to 7 items.
- Secondary labels inside options (a price tag) stay right-aligned and on one line, dim together with a disabled option, and use a background distinct from the hover color.
- An option both selected and highlighted keeps readable contrast.
- After shrinking a widget, re-check text that fit before (long month names in a `<select>`).

## Jinja

### Indentation and markup

- Templates use 4-space indentation; the content of `{% block %}`, `{% trans %}`, `{% if %}` and `{% for %}` blocks is indented one level.
- `{% elif %}` and `{% else %}` align with their `{% if %}`.
- Attribute continuation lines align with the first attribute; tag contents are indented; no blank line after a block opener.
- No collapsing of multi-line markup into one long line; markup that fits the line after attributes were removed goes on one line.
- A custom element without content keeps its tags on one line (`<ind-x event-id="{{ event.id }}"></ind-x>`).
- Intentional empty elements are one-liners with one comment explaining why they exist.
- No XHTML self-closing tags (`<br>`, not `<br />`); check whether the renderer needs them before deviating.
- Attribute values are always quoted; an `alt` carries meaningful text or stays empty.

### Expressions and logic

- Spaces inside the delimiters (`{{ form_row(form.x) }}`, not `{{form_row(form.x)}}`).
- Single quotes in Jinja expressions (`url_for('x')`, `skip=('a', 'b')`); calls stay on one line and are never formatted with a Python formatter.
- Jinja booleans are lowercase (`false`).
- `{{- x -}}` where the output is inline.
- Blocks placed inside attributes trim whitespace (`{%- block name %}`) or move into the `{% set %}` above; a block that reads loop or local variables is `scoped`.
- Static text stays outside `{{ }}`; interpolate only the dynamic part (`.{{ c_id }} .inherited-bg-color {`), no `~` concatenation; conditional inline parts use `{%- if %}`.
- Joining values uses filters (`{{ parts | select | join(', ') }}`), not `loop.nextitem`.
- `{% for day, entries in days.items() %}` when the body indexes the dict.
- Never name a template variable `session`; use `sess`.
- Enum members compare by name (`entry.type.name == 'SESSION_BLOCK'`), never by raw value; dispatch uses an explicit `elif` per member, `else` only for "any other value".
- Output is marked `| safe` on the expression instead of an `{% autoescape false %}` block.
- Inline scripts: `<script>` without `language`, no jQuery in new code (`document.querySelector`, `classList`, `domReady.then(() => ...)`), arrow functions, and preferably no inline request code at all.

### i18n

- Every visible string, button text and table headers included, goes through `{% trans %}Layer 1{% endtrans %}` or `{% trans n=1 %}Layer {{ n }}{% endtrans %}`, not `gettext('...').format()`.
- The Jinja and JS catalogs are separate, so matching a JS string buys nothing.
- `_()` inside macro arguments (`{% trans %}` does not work there); plugin gettext in plugins.
- `{%- trans %}` on its own line for long strings.
- Plural strings use `{% trans count=n %}...{% pluralize %}...{% endtrans %}`, not `ngettext()` in an expression.
- A `{% trans %}` block whose only content is a variable is removed.
- A placeholder used inside a sentence goes into the translatable string itself (`{% trans %}{{ tz }} (your profile timezone){% endtrans %}`), never a bare fragment with a `{# Translators: ... #}` comment explaining the context.
- No `{{- x -}}` whitespace control around a placeholder inside a `{% trans %}` sentence; it strips the spaces around the word.
- A link inside a `{% trans %}` sentence is passed as variables (`{% trans link='<a href="%s">'|format(url_for('x'))|safe, endlink='</a>'|safe %}...{{ link }}text{{ endlink }}...{% endtrans %}`); the anchor is built with `|format`, never with `~` concatenation.
- Hyphenate compound modifiers ("user-submitted data"); "yet" goes at the end ("does not have an account yet").
- Sentence case on buttons ("Add from search"); reuse the terms the UI already uses ("authors").
- A label the content makes obvious ("Location:" above an address) is dropped; no trailing-colon labels.
- Help text for user-supplied regexes shows `\b` boundaries and mirrors the target service's notation.

### Macros and inheritance

- Reuse core macros (`format_event_date`) before hand-rolling.
- Template names describe the page; shared markup moves to a macro partial (`_name.html`).
- Macros used only inside their file are `_`-prefixed; unused macro imports (`message_box`) are removed when their last use goes.
- A macro name promises its argument type; several accepted types are dispatched explicitly with a comment, never probed (`x.object if x.object else x`); a macro that branches on the type throughout splits into one macro per type.
- A macro gaining a parameter updates every caller, including template-module calls from Python.
- Shared templates (`forms/_form.html`) never branch on one form's id; page-specific behavior lives with that page.
- Several possible parents: separate `{% extends %}` in an `if/elif` chain, not nested ternaries in one `extends`.
- A template that switches its base on a mode flag (`{% if preview %}{% extends ... %}`) becomes two templates, one in `display/` and one in `management/`.
- `full_width_base.html` only when the content needs the width.

### Forms, settings and page content

- A checkbox whose label text the template renders calls `form_row(field, skip_label=true)` and puts the text in a `form-field-description` div; no CSS to hide the label or the required marker.
- Integration settings get their own `form_fieldset` and field tuple (`form.X_FIELDS`); the template gates the fieldset on the same config flag that removes the fields from the form.
- A settings section shows a `message_box('warning')` when exactly one of two fields a feature needs is set; the template reads the flag the controller computes for the full page and the section refresh alike.
- When a flow stops reloading the page, server-rendered explanations that assumed the reload go, and button labels that referred to them are reworded.
- Plugin output reuses the core look (the standard join button, not a raw URL); pick the best available template hook and note the better one for later.
- Every counter or list uses the same filtered accessor.
- Calls to action and links match the viewer's rights; a restricted role sees no link it cannot follow.
- A disabled button explains why in its own `title`, not through a separate info icon.
- `data-no-qtip` on `title` attributes that must not open a qtip.
- A cell with an icon next to a name gets `white-space: nowrap`.
- A management action valid only in some object states keeps its button rendered and disabled in the other states (`disabled` attribute with a tooltip), instead of hiding the whole section.
- Action-box labels and descriptions name the audience and the subject ("Contact event participants", "Send an email to the event participants about this survey"), never a bare verb ("Email").

### URLs and data

- Links to objects use their named endpoint (`url_for('rb.booking_link', booking_id=...)`), never a path plus `modal=` query string.
- `url_for` with the locator object only (`url_for('.resend', entry)`), no redundant parent argument.
- `url_for_plugin('.endpoint')` inside plugin blueprints.
- Data attributes read from optional objects (`invitation.lock_email`) are guarded; load the page without that object.
- Templates rendered on public pages guard `session.user` (it is `None` for anonymous visitors) before reading `session.user.settings`.
- `data-params-selector` entries are anchored on a unique parent id (`#tz-selector [name=tz]`); a bare `[name=x]` matches any same-named input on the page.
- Pass `event.tzinfo` to date helpers, not the `event.timezone` string.
- `format_skeleton` for ICU skeletons (`HHmm`, `EEEEdMMMM`); a `format=` pattern only for a literal pattern.
- User strings interpolated into CSS (`content: '{{ event.title }}'`) are checked with quotes and line breaks; confirm autoescaping covers it or use `attr(data-*)`.

### Emails and document templates

- HTML emails: indent normally, `<h3>` for section titles, `<ul>` for lists, `<a>` for links (link the title); no `trim`/`indent` filters or blank-line hacks carried over from the text template.
- In HTML emails a list value is joined with `'<br>'|safe`.
- In emails the URL goes on its own line after the translated sentence, never inside the `{% trans %}` block.
- Default document templates carry no provider-specific logic (payment plugin fields) and no "Default" in the title users copy.
- Document template fonts are generic families (the PDF renderer has no web fonts).
- Document template labels are statements, not questions ("Add event logo"); an image field over a checkbox when a custom picture is plausible.
- Unused template variables in document templates are removed.
- Default receipt templates copy field descriptions and options from the existing default template (affiliation toggle, address override), with default texts spell-checked.
- Default receipt templates offer `{date_range}` with the one-day/multi-day logic plus `{start_date}` and `{end_date}`.

## Verification

### Roles, browsers and screenshots

- Click through every page as every affected role; list what to hide (payments, ACL, tags, manage/clone/delete, customize list, logs, modify).
- Test in Firefox and Safari as well as Chrome (scrollbars, loaders, `<dialog>`, click-outside, focus handling); navigation buttons must not close the dialog.
- Click options in Firefox while moving the mouse slightly: no text selection appears below the `<dialog>`; defer closing until the click has been handled when it does.
- Hover, truncate, resize; test long content and empty states.
- Compare against the description's screenshot; attach your own.
- Build with webpack and clear every new warning (duplicate side-effect imports, aliased imports of sibling modules).
- Every button of a new dialog is clicked once.

### Loading, data and concurrency

- Slow the request (a `time.sleep(3)` in the controller) and check that inputs are disabled and the loader is visible while loading.
- Watch the request log: a view must not fire a chain of requests on load.
- Test with large datasets (thousands of rows) before claiming a list scales.
- Verify filter semantics with real data before review.
- Check for concurrent-edit handling by changing state in a second tab: every action must be disabled once the view is outdated.
- Lists with a special first item (the current container) are tested where that item has no own entries (the Home category).
- Check form-wide derived state with React DevTools "Highlight updates" while typing: only the logic-only component should re-render.

### Widgets, pickers and accessibility

- When a library input is swapped for a custom one, check the field locked after payment and the form while submitting.
- Try a widget near the viewport bottom, inside a centered modal, next to a sticky toolbar, disabled, inside and outside `.ui.form`, with a non-English locale, and while editing an existing record; its disabled, hover and font styling must match in every context.
- Check single-month, two-month and inline picker variants at their natural width.
- Open a dropdown list with a value preselected to check the selected-and-highlighted contrast.
- Check generated color palettes visually for near-identical neighbours.
- Keyboard-only pass: tab to the trigger, arrows across a month boundary, Escape, focus back on the trigger; screen reader pass on selection and mode change announcements.
- Text derived from state (toggletip counts, live regions) is checked after navigating inside the widget.
- Drag the field in the registration form designer: a custom element gets disconnected and reconnected and must not throw.

### Templates and stylesheets

- Check the page on a wide screen before switching the base template to `full_width_base.html`.
- Loading a rendered policy as a plain fieldset (not an `<h3>`) is checked on a stock instance without customizations before posting screenshots.
- Test event display pages against events with custom CSS when their markup changes.
- Diff shared legacy partials (`_buttons.scss`) line by line; a flipped side or sign (`margin-left` to `margin-right`) changes every consumer, so compare before/after screenshots of a page that uses it.
