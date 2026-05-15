# Coding Guidelines

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
- Follow the host repository's naming convention for test files. Prefer `test_*.py` for new Python tests unless
  extending an existing `*_test.py` pattern.

### What To Test

- Behavior exposed by the public API of the module under test.
- Edge cases reachable from real callers, such as empty input, missing optional fields, duplicate records, and
  constraint violations.
- Failure modes that production code is expected to handle gracefully.

Do not test private helpers in isolation when they only factor a public function. Test the public surface and let helper
coverage come through behavior.

## Running Checks

Prefer host repository Makefile targets, task runner commands, or documented scripts over direct tool invocation. They
encode the expected flags and environment.

When the host repository does not define commands, use the standard toolchain for the detected project:

- Python: `uv run pytest`, `uv run ruff check <paths>`.
- Rust: `cargo +nightly fmt --all`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`.
- Node: use the package manager and scripts declared in `package.json`.

For fast feedback, scope direct commands to the changed files. Before finalizing, run the host repository's required
checks when practical.

## Style

- Keep imports at the top of the file, grouped by standard library, third-party packages, framework packages, and host
  project packages.
- Avoid comments that explain what the code plainly does. Reserve comments for non-obvious reasons, invariants,
  constraints, or workarounds.
- Match the surrounding file's formatting, naming, and abstraction level.
- Prefer editing existing modules over creating new ones.
- Keep changes surgical. Do not reformat, rename, or refactor adjacent code unless required for the task.

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
- Never add `Co-Authored-By` trailers.
- Force-push only with explicit approval, and use `--force-with-lease`.

## PR Conventions

- Write descriptions at the big-picture level: what changed and why it matters.
- Avoid file-by-file narration, implementation details, version numbers, and CI status in the description.
- Reply to review comments like a teammate: state the problem, suggest the fix, and keep the thread focused.
- Put project-specific test instructions, deployment notes, and reviewer context in the host repository PR, not in this
  shared repository.
