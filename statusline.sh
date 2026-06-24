#!/usr/bin/env bash
# statusline.sh — script statusLine di Claude Code.
# Doppio ruolo:
#   1) DISPLAY: stampa UNA riga di stato (modello · dir · branch · ctx%).
#   2) TRACKING: registra il dato AUTOREVOLE della finestra di contesto (token reali,
#      via context_window.used_percentage) per poter tarare le soglie con i numeri veri.
#
# Claude Code passa su stdin un JSON con context_window.used_percentage e current_usage.
# Lo stdout della statusLine NON entra nel contesto di Claude: è solo display. Per "parlare"
# con l'hook UserPromptSubmit scriviamo l'ultimo % in un file di stato condiviso.
#
# Vive in ~/.claude/ — mai dentro un repo. Deve essere VELOCE (gira ~ a ogni turno).
# Se hai già una tua statusLine, vedi i docs: copia solo il blocco "TRACKING".

set -uo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
in="$(cat 2>/dev/null || true)"

# --- parser: jq se c'è, altrimenti grep/sed (nessuna dipendenza obbligatoria) ---
if command -v jq >/dev/null 2>&1; then
  model="$(printf '%s' "$in"   | jq -r '.model.display_name // "claude"')"
  cwd="$(printf '%s' "$in"     | jq -r '.workspace.current_dir // .cwd // ""')"
  pct="$(printf '%s' "$in"     | jq -r '.context_window.used_percentage // empty')"
  ctxsize="$(printf '%s' "$in" | jq -r '.context_window.context_window_size // empty')"
  intok="$(printf '%s' "$in"   | jq -r '(.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0)')"
  session="$(printf '%s' "$in" | jq -r '.session_id // ""')"
else
  _num() { printf '%s' "$in" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*[0-9.]+" | grep -oE '[0-9.]+' | head -n1; }
  _str() { printf '%s' "$in" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' | head -n1; }
  model="$(_str display_name)"; model="${model:-claude}"
  cwd="$(_str current_dir)"
  pct="$(_num used_percentage)"
  ctxsize="$(_num context_window_size)"
  intok=""
  session="$(_str session_id)"
fi

dir_base="$(basename "${cwd:-$PWD}")"
branch="$(git -C "${cwd:-$PWD}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
repo_root="$(git -C "${cwd:-$PWD}" rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-$PWD}")"
repo_name="$(basename "$repo_root")"

# --- DISPLAY (prima riga di stdout) ---
pct_disp="${pct:-?}"
mark=""
[[ -n "$pct" ]] && awk -v p="$pct" 'BEGIN{exit !(p>=78)}' && mark="  ⚠"
echo "$model · $dir_base · ⎇ $branch · ctx ${pct_disp}%${mark}"

# --- TRACKING (blocco riusabile: copialo se hai già una tua statusLine) ---
# used_percentage è null a inizio sessione e subito dopo /compact: in quei casi non logghiamo.
if [[ -n "$pct" ]]; then
  state_dir="$CLAUDE_DIR/state/$repo_name"
  mkdir -p "$state_dir" 2>/dev/null || true
  now="$(date +%s)"
  # bridge verso l'hook UserPromptSubmit: ultimo % reale + epoch (per staleness)
  printf '%s\t%s\n' "$pct" "$now" > "$state_dir/last-ctx-pct" 2>/dev/null || true
  # serie storica per calibrare le soglie (append-only, tocca solo file, mai il contesto)
  samples="$state_dir/ctx-samples.tsv"
  [[ -f "$samples" ]] || printf 'iso\tsession\tmodel\tpct\tinput_tokens\tctx_size\n' > "$samples" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "${session:-?}" "$model" "$pct" "${intok:-?}" "${ctxsize:-?}" \
    >> "$samples" 2>/dev/null || true
fi
exit 0
