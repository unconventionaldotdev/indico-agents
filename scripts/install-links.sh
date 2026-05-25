#!/usr/bin/env bash
# Materializes symlinks from a host repository into this submodule based on
# the host repository's .agents-links manifest.
#
# Run from the host repository root, or from inside the submodule:
#   bash agents/indico/scripts/install-links.sh
#
# Manifest format (.agents-links at the host repository root):
#   <src-relative-to-submodule-root>  <dst-relative-to-host-repo-root>
# Lines starting with `#` and blank lines are ignored.
#
# When a destination lives inside a nested git submodule, the script also
# adds the corresponding path to that submodule's local `.git/info/exclude`
# so the host-side symlink does not pollute the submodule's status.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST_ROOT="$(git -C "$SUBMODULE_ROOT" rev-parse --show-superproject-working-tree)"
if [ -z "$HOST_ROOT" ]; then
  echo "error: $SUBMODULE_ROOT is not mounted as a submodule of any superproject" >&2
  exit 1
fi

MANIFEST="$HOST_ROOT/.agents-links"
if [ ! -f "$MANIFEST" ]; then
  echo "error: manifest not found at $MANIFEST" >&2
  echo "create one with entries like:" >&2
  echo "  AGENTS.md             AGENTS.md" >&2
  echo "  CODING_GUIDELINES.md  CODING_GUIDELINES.md" >&2
  exit 1
fi

relpath() {
  python3 -c "import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$2"
}

exclude_in_nested_submodule() {
  local dst_abs="$1"
  local dst_dir
  dst_dir="$(dirname "$dst_abs")"

  local nested_root
  nested_root="$(git -C "$dst_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$nested_root" ] || [ "$nested_root" = "$HOST_ROOT" ]; then
    return 0
  fi

  local nested_git_dir
  nested_git_dir="$(git -C "$nested_root" rev-parse --absolute-git-dir)"
  local exclude_file="$nested_git_dir/info/exclude"
  mkdir -p "$(dirname "$exclude_file")"
  touch "$exclude_file"

  local nested_rel
  nested_rel="$(relpath "$dst_abs" "$nested_root")"
  local entry="/$nested_rel"

  if ! grep -qxF "$entry" "$exclude_file"; then
    printf '%s\n' "$entry" >>"$exclude_file"
    echo "excluded $nested_rel in $(relpath "$nested_root" "$HOST_ROOT")"
  fi
}

cd "$HOST_ROOT"

while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%#*}"
  trimmed="$(printf '%s' "$line" | awk '{$1=$1};1')"
  [ -z "$trimmed" ] && continue

  read -r src dst <<<"$trimmed"
  if [ -z "${src:-}" ] || [ -z "${dst:-}" ]; then
    echo "error: malformed line in manifest: $raw" >&2
    exit 1
  fi

  src_abs="$SUBMODULE_ROOT/$src"
  if [ ! -e "$src_abs" ]; then
    echo "error: missing source $src_abs (referenced by $raw)" >&2
    exit 1
  fi

  dst_dir="$(dirname "$dst")"
  mkdir -p "$dst_dir"

  target_rel="$(relpath "$src_abs" "$HOST_ROOT/$dst_dir")"
  dst_abs="$HOST_ROOT/$dst"

  if [ -L "$dst_abs" ] || [ -e "$dst_abs" ]; then
    rm -f "$dst_abs"
  fi
  ln -s "$target_rel" "$dst_abs"
  echo "linked $dst -> $target_rel"

  exclude_in_nested_submodule "$dst_abs"
done <"$MANIFEST"
