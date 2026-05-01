#!/usr/bin/env bash
#
# Code Quality Skills installer
#
# Deploys the /quality framework into Claude Code:
#   - 11 agent files into ~/.claude/agents/quality-*.md
#   - 1 orchestrator command into ~/.claude/commands/quality.md
#
# Each agent file references the canonical skill markdown in this repo;
# the installer substitutes __SKILLS_DIR__ with the absolute path of
# wherever this repo lives on the user's machine.
#
# Usage:
#   bash install.sh                       # install with defaults
#   bash install.sh --dry-run             # show what would happen
#   bash install.sh --force               # overwrite without backups
#   bash install.sh --skills-dir /path    # canonical docs live elsewhere
#   bash install.sh --claude-home /path   # non-standard ~/.claude location
#   bash install.sh --uninstall           # remove what was installed
#   bash install.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS_DIR="${SKILLS_DIR:-$SCRIPT_DIR}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
FORCE=0
DRY_RUN=0
UNINSTALL=0

usage() {
  sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir)  SKILLS_DIR="$2"; shift 2;;
    --claude-home) CLAUDE_HOME="$2"; shift 2;;
    --force|-f)    FORCE=1; shift;;
    --dry-run|-n)  DRY_RUN=1; shift;;
    --uninstall)   UNINSTALL=1; shift;;
    --help|-h)     usage 0;;
    *) echo "Unknown option: $1" >&2; usage 1;;
  esac
done

SKILLS_DIR="$(cd "$SKILLS_DIR" 2>/dev/null && pwd || echo "$SKILLS_DIR")"

AGENTS_SRC="$SCRIPT_DIR/claude/agents"
COMMANDS_SRC="$SCRIPT_DIR/claude/commands"
AGENTS_DEST="$CLAUDE_HOME/agents"
COMMANDS_DEST="$CLAUDE_HOME/commands"

log()  { printf '  %s\n' "$*"; }
note() { printf '\n[%s] %s\n' "$1" "$2"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "dry-run: $*"
  else
    "$@"
  fi
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  note "UNINSTALL" "removing files from $CLAUDE_HOME"
  for src in "$AGENTS_SRC"/quality-*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    target="$AGENTS_DEST/$name"
    if [[ -f "$target" ]]; then
      run rm -f "$target"
      log "removed $target"
    fi
  done
  if [[ -f "$COMMANDS_DEST/quality.md" ]]; then
    run rm -f "$COMMANDS_DEST/quality.md"
    log "removed $COMMANDS_DEST/quality.md"
  fi
  note "DONE" "uninstall complete"
  exit 0
fi

[[ -d "$AGENTS_SRC" ]]   || die "missing $AGENTS_SRC — is this a clone of the repo?"
[[ -d "$COMMANDS_SRC" ]] || die "missing $COMMANDS_SRC"
[[ -f "$SKILLS_DIR/skills/code-quality.md" ]] || die "skills dir invalid: $SKILLS_DIR (no skills/code-quality.md found)"

note "PLAN" "installing /quality framework"
log "skills dir:    $SKILLS_DIR"
log "claude home:   $CLAUDE_HOME"
log "agents dest:   $AGENTS_DEST"
log "commands dest: $COMMANDS_DEST"
[[ "$DRY_RUN" -eq 1 ]] && log "mode:          DRY RUN"
[[ "$FORCE"   -eq 1 ]] && log "mode:          FORCE (no backups)"

if [[ ! -d "$CLAUDE_HOME" ]]; then
  log "warning:       $CLAUDE_HOME does not exist — Claude Code may not be installed"
  log "               see https://docs.claude.com/claude-code (continuing anyway)"
fi

run mkdir -p "$AGENTS_DEST" "$COMMANDS_DEST"

backup_if_needed() {
  local target="$1"
  [[ -f "$target" ]] || return 0
  [[ "$FORCE" -eq 1 ]] && return 0
  local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "dry-run: would back up $(basename "$target") → $(basename "$target").bak.$stamp"
  else
    cp "$target" "$target.bak.$stamp"
    log "backed up existing → $(basename "$target").bak.$stamp"
  fi
}

install_file() {
  local src="$1" dest="$2"
  local tmp; tmp="$(mktemp)"
  sed "s|__SKILLS_DIR__|${SKILLS_DIR}|g" "$src" > "$tmp"
  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    log "unchanged $(basename "$dest")"
    return 0
  fi
  backup_if_needed "$dest"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    rm -f "$tmp"
    log "dry-run: would install $dest"
  else
    mv "$tmp" "$dest"
    log "installed $dest"
  fi
}

note "AGENTS" "deploying 11 agents → $AGENTS_DEST"
count=0
for src in "$AGENTS_SRC"/quality-*.md; do
  [[ -e "$src" ]] || die "no agent files found in $AGENTS_SRC"
  install_file "$src" "$AGENTS_DEST/$(basename "$src")"
  count=$((count + 1))
done
log "$count agent file(s) processed"

note "ORCHESTRATOR" "deploying /quality command"
install_file "$COMMANDS_SRC/quality.md" "$COMMANDS_DEST/quality.md"

note "DONE" "Claude Code install complete"
log "try it:  open Claude Code in any git repo and run /quality"
[[ "$FORCE" -eq 0 && "$DRY_RUN" -eq 0 ]] && log "backups: any pre-existing files were saved as *.bak.<timestamp>"

cat <<EOF

────────────────────────────────────────────────────────────────────
GitHub Copilot setup (optional, manual — not automated by this script)
────────────────────────────────────────────────────────────────────

1) Per-skill prompts in VS Code Copilot Chat
   Add to VS Code user settings.json:

     "chat.promptFiles": true,
     "chat.promptFilesLocations": {
       "$SKILLS_DIR/copilot/prompts": true
     }

   Reload VS Code. In any workspace, type "/" in Copilot Chat to see
   /quality-code, /quality-arch, /quality-tests, etc.

2) Personal global instructions
   See: $SKILLS_DIR/copilot/global-instructions.md
   Paste the snippet into:
     - github.com → Settings → Copilot → Personal custom instructions
     - VS Code user settings.json (the "github.copilot.chat.*" block)

3) Per-repo cross-tool context (Claude Code, Copilot, Cursor, Continue)
   Drop $SKILLS_DIR/copilot/AGENTS.md into a repo's root.

Full guide: $SKILLS_DIR/Copilot-Integration.md
EOF
