# Conventions

Shared baseline for Indico-related repositories. Host repository instructions are more specific and should win when they
conflict with this document.

## TDD

Test-first. No exceptions for production code.

1. **Red**: write one minimal failing test that pins the desired behavior.
2. **Verify red**: run it and confirm it fails for the right reason, not because of an import error, fixture bug, or
   broken setup.
3. **Green**: write the simplest production code that makes the test pass. Nothing more.
4. **Verify green**: run the relevant test module and confirm clean output with no new warnings.
5. **Refactor**: only after green. Keep tests green throughout.

If production code was written before the test, delete it and start over. The test must exist first.

## Test Conventions

The host repository's existing tests are the authoritative style guide. Before writing a new test file, read a sibling
test in the same area and mirror its structure, naming, fixture style, and assertion style.

### Fixtures, Not Mocks

Use real test fixtures. Preferred sources, in order:

1. Host repository fixtures in `tests/conftest.py` or module-local fixture files.
2. Indico core fixtures provided by the `indico` package.
3. New host repository fixtures added near the tests that need them.

Indico core fixtures are commonly found in `indico/testing/fixtures/` and module-local files such as
`indico/modules/<module>/testing/fixtures.py`. Before adding a new factory, search the host repository and Indico itself
for existing `create_*` or `dummy_*` fixtures.

Do not mock the database, ORM sessions, query objects, or model classes. Mocking at that layer hides regressions that
real migrations, constraints, and relationships would expose.

Mocks are acceptable at external boundaries: HTTP clients, filesystem access, process execution, third-party SDKs, email
gateways, object storage, and similar integrations.

When existing fixtures do not cover the setup, add a real fixture rather than patching a model, query, or framework
object with `MagicMock` or `monkeypatch`.

### File And Structure

- Place tests according to the host repository's existing layout, usually mirroring the production tree.
- Group related tests in a `class TestX:` when they cover one behavior or public unit.
- Use `@pytest.mark.parametrize` for case matrices instead of duplicating test bodies.
- Follow the host repository's naming convention for test files. Indico core and the plugin repositories use the
  `*_test.py` suffix; use `test_*.py` only where the host repository already does.

### What To Test

- Behavior exposed by the public API of the module under test.
- Edge cases reachable from real callers, such as empty input, missing optional fields, duplicate records, and
  constraint violations.
- Failure modes that production code is expected to handle gracefully.
- For a new endpoint, the access matrix: each relevant role, including managers of unrelated events, asserted against
  the expected status code.

Do not test private helpers in isolation when they only factor a public function. Test the public surface and let helper
coverage come through behavior.

Write tests that earn their keep:

- **Make each test discriminating.** Build the setup so only the behavior under test can produce the asserted result. If
  an unrelated filter (a different field, a narrower query) would make the test pass anyway, it proves nothing.
- **Assert the expected outcome, not the absence of an error.** Pin the concrete result (a status code, a returned set),
  not a weak negative such as "not a 403".
- **Test your own code, not the framework.** Do not re-assert Indico or core guarantees (full access implies management,
  a base permission holds) from a host or plugin test.
- **One focused test per behavior.** Merge near-identical tests that share setup and exercise the same path rather than
  keeping parallel copies.

### Client-Side Tests

- Frontend changes ship a jest spec alongside the component, under `client/js/**/__tests__/*.spec.js` or the host
  repository's equivalent location.
- Name `it()` blocks as behavior sentences ("renders the join button when the meeting is live"), not implementation
  notes.

## Running Checks

Prefer host repository Makefile targets, task runner commands, or documented scripts over direct tool invocation. They
encode the expected flags and environment.

When the host repository does not define commands, use the standard toolchain for the detected project:

- Python: `uv run pytest`, `uv run ruff check <paths>`.
- Node: use the package manager and scripts declared in `package.json`.

For fast feedback, scope direct commands to the changed files. Before finalizing, run the host repository's required
checks when practical.

## Style

- Keep imports at the top of the file, grouped by standard library, third-party packages, framework packages, and host
  project packages.
- Avoid comments that explain what the code plainly does. Reserve comments for non-obvious reasons, invariants,
  constraints, or workarounds. A why-comment about an external service's behavior may take several lines when the
  invariant needs them.
- Signal and public-API docstrings document the full contract: sender, kwargs, return value, and (for signals) how
  multiple listener returns combine.
- Match the surrounding file's formatting, naming, and abstraction level.
- Prefer editing existing modules over creating new ones.
- Keep changes surgical. Do not reformat, rename, or refactor adjacent code unless required for the task.
- Wrap user-facing strings for translation: server strings through `_()` (gettext), client strings through `Translate`
  or `Translate.string`. Never ship a bare literal a user will read.

## Design Principles

- **Readability first**: clear names, simple control flow, and self-documenting code beat cleverness.
- **KISS**: write the minimum code that solves the verified problem.
- **YAGNI**: do not add options, configuration, abstractions, or extension points before they are needed.
- **DRY**: extract repeated logic when it removes real duplication, but do not create single-use abstractions.
- **Goal-driven execution**: define the observable behavior before changing implementation.

## Git Workflow

- Follow the host repository's branch policy. If none is documented, do not commit directly on `main` or `master`.
- Stage files explicitly by name. Never use `git add -A`, `git add .`, or `git add -u`.
- Use single-line commit messages in English: `type: imperative subject`.
- Keep the subject lowercase after the colon and omit trailing punctuation.
- Commit style follows the target repository when it differs. The upstream Indico repositories have their own
  conventions; see `indico/AGENTS.md`.
- Know the merge strategy before writing fixup commits. In repositories that merge branches unsquashed, every commit
  subject must stand on its own; in squash-merge repositories, the PR title becomes the final subject.
- Never add `Co-Authored-By` trailers.
- Force-push only with explicit approval, and use `--force-with-lease`.

## PR Conventions

- Write descriptions at the big-picture level: what changed and why it matters.
- Avoid file-by-file narration, implementation details, version numbers, and CI status in the description.
- Default to brief. A new feature does not automatically earn headers and sections; add structure only when the reader
  needs it.
- Bug-fix descriptions state the root cause, not only the symptom. When behavior changes, a short Before/After pair
  makes the change reviewable at a glance.
- When one PR fixes several independent problems, introduce each with a bold category header followed by its
  explanation.
- When a design choice was close, add an `## Alternatives considered` section, and flag known catches yourself ("One
  catch worth flagging:") instead of waiting for review to find them.
- Cross-link companion PRs (core and plugin, or stacked branches) in both descriptions.
- Keep the description current: when review changes the scope or approach, update the description in the same push.
- Changes visible in the UI include a screenshot or short recording.
- Reply to review comments like a teammate: state the problem, suggest the fix, and keep the thread focused.
- Put project-specific test instructions, deployment notes, and reviewer context in the host repository PR, not in this
  shared repository.
