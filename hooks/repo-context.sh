#!/usr/bin/env bash
# repo-context.sh — hook SessionStart
# Inietta nel contesto: (1) il tech-stack curato del repo, (2) un folder-graph generato
# AL VOLO (mai salvato, mai stantio). Vive in ~/.claude/hooks/ — mai dentro un repo.
# Stampa su stdout: per SessionStart lo stdout diventa contesto di Claude.
# Esce SEMPRE 0: carica contesto, non deve mai bloccare la sessione.

set -uo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# --- 0. Sorgente della SessionStart: startup | resume | clear | compact ---
hook_input="$(cat 2>/dev/null || true)"
src="$(printf '%s' "$hook_input" \
       | grep -oE '"source"[[:space:]]*:[[:space:]]*"[a-z]+"' \
       | grep -oE '(startup|resume|clear|compact)' | head -n1 || true)"

# --- 1. Root del repo corrente (git se possibile, altrimenti project dir / cwd) ---
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
repo_root="$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null || echo "$project_dir")"
repo_name="$(basename "$repo_root")"

ctx_dir="$CLAUDE_DIR/repos/$repo_name"
tech_stack="$ctx_dir/tech-stack.md"
state_dir="$CLAUDE_DIR/state/$repo_name"

# --- 0b. Se ripartiamo DOPO una compattazione: ri-ancoraggio esplicito ---
if [[ "$src" == "compact" ]]; then
  echo "## 🗜️ Ripresa dopo compattazione"
  echo "Il contesto è stato compattato (lossy). Qui sotto trovi la base curata re-iniettata."
  if [[ -f "$state_dir/LAST_CHECKPOINT" ]]; then
    last_ckpt="$(cat "$state_dir/LAST_CHECKPOINT" 2>/dev/null || true)"
    [[ -n "$last_ckpt" ]] && echo "Ultimo checkpoint pre-compattazione: \`$last_ckpt\` (apri il transcript grezzo lì accanto solo se ti mancano decisioni)."
  fi
  echo "Non considerare perse le decisioni architetturali: riparti da tech-stack + checkpoint."
  echo
fi

echo "## Contesto repo: $repo_name"
echo "_(iniettato dall'hook SessionStart — fonte: ~/.claude/repos/$repo_name/)_"
echo

# --- 2. Tech-stack curato, oppure segnala la mancanza (auto-contestualizzazione) ---
if [[ -f "$tech_stack" ]]; then
  cat "$tech_stack"
else
  echo "⚠️ **CONTESTO MANCANTE**: non esiste \`$tech_stack\`."
  echo "Applica la skill \`repo-onboarding\`: deduce lo stack, ti propone la **BOZZA** e la salva"
  echo "**solo dopo conferma** in \`$ctx_dir/tech-stack.md\`."
fi
echo

# --- 3. Folder-graph generato adesso, profondità 2, output limitato (cap 10k char) ---
echo "## Struttura (generata ora, profondità 2)"
echo '```'
ignore='node_modules|dist|build|.git|.astro|.svelte-kit|coverage|target|vendor|.next|.output'
if command -v tree >/dev/null 2>&1; then
  tree -L 2 -d -I "$ignore" "$repo_root" 2>/dev/null | head -n 60
else
  ( cd "$repo_root" 2>/dev/null && \
    find . -maxdepth 2 -type d \
      -not -path '*/node_modules*' -not -path '*/.git*' -not -path '*/dist*' \
      -not -path '*/build*' -not -path '*/.astro*' -not -path '*/.svelte-kit*' \
      -not -path '*/target*' -not -path '*/vendor*' \
      | sort | head -n 60 )
fi
echo '```'

exit 0
