#!/usr/bin/env bash
# pre-compact.sh — hook PreCompact (matcher: tutti; trigger = manual|auto).
# Ultima finestra utile PRIMA della compattazione (lossy). Qui NON si può chiedere
# conferma né bloccare: lo stdout di PreCompact NON entra nel contesto e l'exit code
# non ferma la compattazione. Quindi facciamo solo lavoro su filesystem:
#   1) backup grezzo del transcript .jsonl
#   2) un checkpoint Markdown con metadati (timestamp, trigger, branch, sessione)
#   3) aggiornamento del puntatore LAST_CHECKPOINT (lo rilegge SessionStart source=compact)
#   4) riga di log append-only
#
# Tutto fuori dai repo, in ~/.claude/state/{repo}/. Eseguibile in async (vedi settings.json).
# La sintesi "intelligente" delle decisioni NON spetta a questo script: la produce Claude
# col protocollo proponi→conferma PRIMA di arrivare qui. Questo hook è la rete di sicurezza.

set -uo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

in="$(cat 2>/dev/null || true)"
_field() { printf '%s' "$in" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' | head -n1; }

trigger="$(_field trigger)";        trigger="${trigger:-unknown}"
session_id="$(_field session_id)";  session_id="${session_id:-nosession}"
transcript="$(_field transcript_path)"; transcript="${transcript/#\~/$HOME}"

repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
repo_name="$(basename "$repo_root")"
branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(no-git)')"

ts="$(date +%Y%m%d-%H%M%S)"
state_dir="$CLAUDE_DIR/state/$repo_name"
ckpt_dir="$state_dir/checkpoints"
mkdir -p "$ckpt_dir" 2>/dev/null || true

# Metriche di calibrazione: byte del transcript + ultimo % token noto (dalla statusLine).
bytes=0
if [[ -n "$transcript" && -f "$transcript" ]]; then
  bytes="$(stat -c%s "$transcript" 2>/dev/null || stat -f%z "$transcript" 2>/dev/null || echo 0)"
fi
mb="$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1024/1024}')"
last_pct="?"
[[ -f "$state_dir/last-ctx-pct" ]] && last_pct="$(cut -f1 "$state_dir/last-ctx-pct" 2>/dev/null || echo '?')"

# 1) backup grezzo del transcript (se presente)
if [[ -n "$transcript" && -f "$transcript" ]]; then
  cp "$transcript" "$ckpt_dir/$ts-$trigger-transcript.jsonl" 2>/dev/null || true
fi

# 2) checkpoint Markdown con metadati
ckpt_md="$ckpt_dir/$ts-$trigger.md"
{
  echo "# Checkpoint pre-compattazione — $repo_name"
  echo "- Quando: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- Trigger: $trigger   (manual = /compact, auto = soglia contesto)"
  echo "- Branch: $branch"
  echo "- Sessione: $session_id"
  echo "- Contesto al compattamento: ~${last_pct}% token · transcript ~${mb} MB"
  echo "- Transcript grezzo: $ckpt_dir/$ts-$trigger-transcript.jsonl"
  echo
  echo "## Come riprendere"
  echo "Al riavvio (source=compact) l'hook repo-context.sh re-inietta il tech-stack curato"
  echo "e segnala questo checkpoint. Se servono decisioni/contesto non più in finestra,"
  echo "apri il transcript grezzo qui sopra."
} > "$ckpt_md" 2>/dev/null || true

# 3) puntatore all'ultimo checkpoint
printf '%s\n' "$ckpt_md" > "$state_dir/LAST_CHECKPOINT" 2>/dev/null || true

# 4) log append-only (con metriche di calibrazione: pct token e MB transcript)
[[ -f "$state_dir/compaction-log.tsv" ]] || \
  printf 'iso\ttrigger\tpct\tmb\tbranch\tcheckpoint\n' > "$state_dir/compaction-log.tsv" 2>/dev/null || true
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$trigger" "$last_pct" "$mb" "$branch" "$ckpt_md" \
  >> "$state_dir/compaction-log.tsv" 2>/dev/null || true

# stderr → mostrato all'utente (non a Claude). Utile come traccia visibile.
echo "🗜️  pre-compact ($trigger): checkpoint salvato in $ckpt_md" >&2
exit 0
