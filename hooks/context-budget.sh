#!/usr/bin/env bash
# context-budget.sh — hook UserPromptSubmit.
# Inietta un segnale di pressione del contesto SOLO oltre soglia, così Claude può proporre
# /compact o /clear PRIMA dell'auto-compact. Esce SEMPRE 0 (un exit!=0 rifiuterebbe il prompt).
#
# DUE FONTI, in ordine di affidabilità:
#   1) % TOKEN REALE scritto dalla statusLine in ~/.claude/state/{repo}/last-ctx-pct
#      (autorevole: viene da context_window.used_percentage). Soglie in %:
#        CTX_SOFT_PCT (default 60)   CTX_WARN_PCT (default 78)
#      Considerato valido se più recente di CTX_PCT_MAX_AGE secondi (default 300).
#   2) FALLBACK euristico: dimensione del transcript .jsonl (se la statusLine non è
#      installata o il dato è stale). Soglie in MB:
#        CTX_SOFT_MB (default 1.5)   CTX_WARN_MB (default 3.0)
#
# Throttle per banda: niente spam a ogni turno. Stato fuori dai repo.

set -uo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

soft_pct="${CTX_SOFT_PCT:-60}"
warn_pct="${CTX_WARN_PCT:-78}"
pct_max_age="${CTX_PCT_MAX_AGE:-300}"
soft_mb="${CTX_SOFT_MB:-1.5}"
warn_mb="${CTX_WARN_MB:-3.0}"

in="$(cat 2>/dev/null || true)"
_field() { printf '%s' "$in" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' | head -n1; }
transcript="$(_field transcript_path)"; transcript="${transcript/#\~/$HOME}"
session_id="$(_field session_id)"

repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
repo_name="$(basename "$repo_root")"
state_dir="$CLAUDE_DIR/state/$repo_name"
mkdir -p "$state_dir" 2>/dev/null || true

band="none"; detail=""; source_used=""

# --- 1) % token reale (preferito) ---
pct_file="$state_dir/last-ctx-pct"
if [[ -f "$pct_file" ]]; then
  IFS=$'\t' read -r pct epoch < "$pct_file" 2>/dev/null || true
  now="$(date +%s)"
  if [[ -n "${pct:-}" && -n "${epoch:-}" ]] && (( now - epoch <= pct_max_age )); then
    source_used="pct"
    pct_int="$(awk -v p="$pct" 'BEGIN{printf "%d", p}')"
    if   (( pct_int >= warn_pct )); then band="warn"
    elif (( pct_int >= soft_pct )); then band="soft"
    fi
    detail="finestra di contesto ~${pct_int}%"
  fi
fi

# --- 2) fallback byte del transcript ---
if [[ -z "$source_used" && -n "$transcript" && -f "$transcript" ]]; then
  source_used="bytes"
  bytes="$(stat -c%s "$transcript" 2>/dev/null || stat -f%z "$transcript" 2>/dev/null || echo 0)"
  to_bytes() { awk -v m="$1" 'BEGIN{printf "%d", m*1024*1024}'; }
  (( bytes >= $(to_bytes "$warn_mb") )) && band="warn"
  [[ "$band" == "none" ]] && (( bytes >= $(to_bytes "$soft_mb") )) && band="soft"
  detail="transcript ~$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1024/1024}') MB"
fi

# nessuna fonte utile → silenzio
[[ -z "$source_used" ]] && exit 0

# --- throttle per banda ---
band_file="$state_dir/budget-${session_id:-nosession}.band"
last_band="$(cat "$band_file" 2>/dev/null || echo none)"
printf '%s' "$band" > "$band_file" 2>/dev/null || true
[[ "$band" == "$last_band" || "$band" == "none" ]] && exit 0

if [[ "$band" == "warn" ]]; then
  cat <<MSG
⚠️ CONTEXT BUDGET: ALTO ($detail).
Se stai per cambiare task, applica ORA la skill \`context-governance\`: proponi /compact
(correlato) o /clear (scollegato) PRIMA dell'auto-compact, con motivazione e manifesto
MANTIENI/SCARTA, e attendi conferma.
MSG
else
  cat <<MSG
ℹ️ CONTEXT BUDGET: in crescita ($detail).
Al prossimo cambio di task valuta un checkpoint (/compact) per restare snello.
MSG
fi
exit 0
