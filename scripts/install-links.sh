#!/usr/bin/env bash
# Installs shared agent links from this submodule into the host repository.
#
# Usage:
#   bash agents/indico/scripts/install-links.sh [<skills-target-dir>]
#
# Without arguments, the script installs the universal markdown files at
# host-native paths:
#
#   <host>/AGENTS.md             -> agents/indico/AGENTS.md
#   <host>/CODING_GUIDELINES.md  -> agents/indico/CODING_GUIDELINES.md
#   <host>/indico/AGENTS.md      -> ../agents/indico/indico/AGENTS.md
#                                   (only when an `indico/` directory exists
#                                   at the host repository root)
#
# When a destination lives inside a nested submodule (such as the upstream
# `indico/` submodule), the script also appends the destination path to that
# submodule's local `.git/info/exclude` so the host-side symlink does not
# pollute the submodule's status.
#
# With one argument, the script additionally installs each shared skill under
# the given directory. The argument is the path (relative to the host
# repository root) where your AI assistant looks for skills:
#
#   bash agents/indico/scripts/install-links.sh .claude/skills   # Claude Code
#   bash agents/indico/scripts/install-links.sh .codex/skills    # OpenAI Codex
#   bash agents/indico/scripts/install-links.sh .cursor/skills   # Cursor
#
# Skill symlinks are intentionally per-user (different teammates use different
# assistants). They should not be committed by the host repository. Add the
# chosen skills directory to the host repository's `.gitignore`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST_ROOT="$(git -C "$SUBMODULE_ROOT" rev-parse --show-superproject-working-tree)"
if [ -z "$HOST_ROOT" ]; then
  echo "error: $SUBMODULE_ROOT is not mounted as a submodule of any superproject" >&2
  exit 1
fi

SKILLS_TARGET="${1:-}"

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

link_one() {
  local src_abs="$1"
  local dst_rel="$2"

  if [ ! -e "$src_abs" ]; then
    echo "error: missing source $src_abs" >&2
    exit 1
  fi

  local dst_dir
  dst_dir="$(dirname "$dst_rel")"
  mkdir -p "$HOST_ROOT/$dst_dir"

  local target_rel
  target_rel="$(relpath "$src_abs" "$HOST_ROOT/$dst_dir")"

  local dst_abs="$HOST_ROOT/$dst_rel"
  if [ -L "$dst_abs" ] || [ -e "$dst_abs" ]; then
    rm -f "$dst_abs"
  fi
  ln -s "$target_rel" "$dst_abs"
  echo "linked $dst_rel -> $target_rel"

  exclude_in_nested_submodule "$dst_abs"
}

cd "$HOST_ROOT"

# Universal markdown files
link_one "$SUBMODULE_ROOT/AGENTS.md" "AGENTS.md"
link_one "$SUBMODULE_ROOT/CODING_GUIDELINES.md" "CODING_GUIDELINES.md"

# Indico-submodule guidance (only when the host mounts upstream Indico)
if [ -d "$HOST_ROOT/indico" ]; then
  link_one "$SUBMODULE_ROOT/indico/AGENTS.md" "indico/AGENTS.md"
else
  echo "skip indico/AGENTS.md (host repository has no indico/ directory)"
fi

# Skills (only when a target directory is given)
if [ -n "$SKILLS_TARGET" ]; then
  mkdir -p "$HOST_ROOT/$SKILLS_TARGET"
  for skill_dir in "$SUBMODULE_ROOT/skills"/*; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    link_one "$skill_dir" "$SKILLS_TARGET/$name"
  done
else
  echo "skip skills (pass a target directory to install them, e.g. .claude/skills)"
fi
