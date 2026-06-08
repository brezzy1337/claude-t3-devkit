#!/usr/bin/env bash
#
# bootstrap.sh — one-shot scaffolder for a create-t3-turbo monorepo wired to
# the claude-t3-devkit Claude Code plugin marketplace.
#
# Usage:
#   ./bootstrap.sh <project-name> <marketplace-repo>
#   e.g.  ./bootstrap.sh my-app your-org/claude-t3-devkit
#
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ./bootstrap.sh <project-name> <marketplace-repo>

  <project-name>      Name of the new project directory to create (must not exist).
  <marketplace-repo>  GitHub marketplace repo in "owner/name" form.

Example:
  ./bootstrap.sh my-app your-org/claude-t3-devkit
EOF
  exit 1
}

# Phase 1: Argument validation
if [[ "$#" -ne 2 ]]; then
  echo "Error: expected exactly 2 arguments, got $#." >&2
  usage
fi

PROJECT_NAME="$1"
MARKETPLACE_REPO="$2"

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: project name must not be empty." >&2
  usage
fi

if [[ ! "$MARKETPLACE_REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
  echo "Error: marketplace repo '$MARKETPLACE_REPO' is not of the form 'owner/name'." >&2
  usage
fi

REPO_OWNER="${MARKETPLACE_REPO%%/*}"
REPO_NAME="${MARKETPLACE_REPO##*/}"
TARGET_DIR="./$PROJECT_NAME"

if [[ -e "$TARGET_DIR" ]]; then
  echo "Error: target directory '$TARGET_DIR' already exists. Refusing to overwrite." >&2
  exit 1
fi

echo "==> claude-t3-devkit bootstrap"
echo "    project          : $PROJECT_NAME"
echo "    marketplace repo : $MARKETPLACE_REPO (owner=$REPO_OWNER, name=$REPO_NAME)"

# Phase 2: Scaffold the create-t3-turbo monorepo (pnpm > bun > npm)
echo "==> Scaffolding create-t3-turbo into $TARGET_DIR"

if command -v pnpm >/dev/null 2>&1; then
  echo "    using pnpm"
  pnpm create t3-turbo@latest "$PROJECT_NAME"
elif command -v bunx >/dev/null 2>&1; then
  echo "    using bunx"
  bunx create-t3-turbo@latest "$PROJECT_NAME"
elif command -v npm >/dev/null 2>&1; then
  echo "    using npm"
  npm create t3-turbo@latest -- "$PROJECT_NAME"
else
  echo "Error: none of pnpm, bun, or npm were found on PATH." >&2
  echo "       Install one of them and re-run this script." >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: scaffolding completed but '$TARGET_DIR' was not created." >&2
  exit 1
fi

# Phase 3: Wire up the marketplace + plugin via .claude/settings.json
echo "==> Writing $TARGET_DIR/.claude/settings.json"

CLAUDE_DIR="$TARGET_DIR/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
mkdir -p "$CLAUDE_DIR"

if [[ -e "$SETTINGS_FILE" ]]; then
  echo "    Warning: $SETTINGS_FILE already exists; backing up to settings.json.bak" >&2
  mv "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
fi

cat > "$SETTINGS_FILE" <<EOF
{
  "extraKnownMarketplaces": {
    "$REPO_NAME": { "source": { "source": "github", "repo": "$MARKETPLACE_REPO" } }
  },
  "enabledPlugins": ["$REPO_NAME@$REPO_NAME"]
}
EOF

# Phase 4: Next steps
echo ""
echo "============================================================"
echo " Done. Your create-t3-turbo project is ready."
echo "============================================================"
echo ""
echo " Next steps:"
echo "   1. cd $PROJECT_NAME"
echo "   2. Open Claude Code in this directory."
echo "   3. Run: /claude-t3-devkit:subagent-orchestration"
echo ""
echo " Note: teammates who open this folder will be prompted to install"
echo "       the '$REPO_NAME' marketplace + plugin on folder-trust"
echo "       (wired via .claude/settings.json)."
echo ""
