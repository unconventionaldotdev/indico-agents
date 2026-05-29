#!/usr/bin/env bash
# Installs shared agent links from this submodule into the host repository.
#
# Usage:
#   bash agents/indico/scripts/install-links.sh [--skills] [--claude]
#
# Without flags, the script installs the universal markdown files at
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
# --skills installs each shared skill under `.agents/skills/`, the cross-agent
# convention read natively by Codex, Cursor, and other assistants:
#
#   <host>/.agents/skills/<name> -> agents/indico/skills/<name>
#
# --claude adds the Claude Code bridge. Claude reads `.claude/` and `CLAUDE.md`,
# not `.agents/` or `AGENTS.md`, so the bridge points the former at the latter:
#
#   <host>/.claude               -> .agents     (so Claude finds the skills)
#   <host>/CLAUDE.md             redirect to AGENTS.md via `@AGENTS.md`
#   <host>/indico/CLAUDE.md      redirect to indico/AGENTS.md (when indico/ exists)
#
# The `indico/CLAUDE.md` redirect lives inside the upstream Indico submodule, so
# the script adds it (alongside the `indico/AGENTS.md` symlink) to that
# submodule's local `.git/info/exclude`.
#
# Skill links and the `.claude` symlink are per-contributor (teammates use
# different assistants) and should not be committed by the host repository. Add
# these to the host repository's `.gitignore`:
#
#   /.agents/skills/
#   /.claude
#
# The generated `CLAUDE.md` is a stable redirect, identical for every clone, and
# is committed alongside the root `AGENTS.md`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST_ROOT="$(git -C "$SUBMODULE_ROOT" rev-parse --show-superproject-working-tree)"
if [ -z "$HOST_ROOT" ]; then
  echo "error: $SUBMODULE_ROOT is not mounted as a submodule of any superproject" >&2
  exit 1
fi

INSTALL_SKILLS=false
INSTALL_CLAUDE=false
for arg in "$@"; do
  case "$arg" in
    --skills) INSTALL_SKILLS=true ;;
    --claude) INSTALL_CLAUDE=true ;;
    *)
      echo "error: unknown argument: $arg (expected --skills and/or --claude)" >&2
      exit 1
      ;;
  esac
done

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

# Symlink a host path to a sibling that lives directly under the host root
# (no relpath computation, no nested-submodule handling needed).
symlink_sibling() {
  local dst_rel="$1"
  local target="$2"

  local dst_abs="$HOST_ROOT/$dst_rel"
  if [ -L "$dst_abs" ] || [ -e "$dst_abs" ]; then
    rm -f "$dst_abs"
  fi
  ln -s "$target" "$dst_abs"
  echo "linked $dst_rel -> $target"
}

# Write a CLAUDE.md that redirects to its sibling AGENTS.md. Claude resolves the
# `@AGENTS.md` import relative to the file, so the same body works at any depth.
write_claude_redirect() {
  local dst_rel="$1"

  local dst_abs="$HOST_ROOT/$dst_rel"
  mkdir -p "$(dirname "$dst_abs")"
  cat >"$dst_abs" <<'EOF'
# Claude Code entrypoint. Redirects to the shared cross-agent guidance.
@AGENTS.md
EOF
  echo "wrote $dst_rel (redirect -> AGENTS.md)"
}

cd "$HOST_ROOT"

# Universal markdown files (committed)
link_one "$SUBMODULE_ROOT/AGENTS.md" "AGENTS.md"
link_one "$SUBMODULE_ROOT/CODING_GUIDELINES.md" "CODING_GUIDELINES.md"

# Indico-submodule guidance (only when the host mounts upstream Indico)
if [ -d "$HOST_ROOT/indico" ]; then
  link_one "$SUBMODULE_ROOT/indico/AGENTS.md" "indico/AGENTS.md"
else
  echo "skip indico/AGENTS.md (host repository has no indico/ directory)"
fi

# Shared skills -> .agents/skills (cross-agent convention; per-contributor)
if [ "$INSTALL_SKILLS" = true ]; then
  mkdir -p "$HOST_ROOT/.agents/skills"
  for skill_dir in "$SUBMODULE_ROOT/skills"/*; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    link_one "$skill_dir" ".agents/skills/$name"
  done
else
  echo "skip skills (pass --skills to install them into .agents/skills)"
fi

# Claude Code bridge: .claude -> .agents plus CLAUDE.md redirects (per-contributor)
if [ "$INSTALL_CLAUDE" = true ]; then
  mkdir -p "$HOST_ROOT/.agents"
  symlink_sibling ".claude" ".agents"
  write_claude_redirect "CLAUDE.md"
  if [ -d "$HOST_ROOT/indico" ]; then
    write_claude_redirect "indico/CLAUDE.md"
    exclude_in_nested_submodule "$HOST_ROOT/indico/CLAUDE.md"
  else
    echo "skip indico/CLAUDE.md (host repository has no indico/ directory)"
  fi
else
  echo "skip Claude bridge (pass --claude to install it)"
fi
