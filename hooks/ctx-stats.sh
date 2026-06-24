#!/usr/bin/env bash
# ctx-stats.sh — legge i log di tracking del contesto e PROPONE le soglie.
# Trasforma i dati grezzi (campioni statusLine + eventi di compattazione) in numeri
# azionabili: picchi raggiunti, a che % è scattato l'auto-compact, soglie consigliate.
#
# Uso:
#   ~/.claude/hooks/ctx-stats.sh [nome-repo]   # default: repo corrente (git/cwd)
#   ~/.claude/hooks/ctx-stats.sh all           # aggrega tutti i repo
#
# Non scrive nulla: stampa e basta. Le soglie le applichi tu (env nel tuo shell/profilo).

set -uo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

arg="${1:-}"
if [[ "$arg" == "all" ]]; then
  repos="$(ls -1 "$CLAUDE_DIR/state" 2>/dev/null || true)"
else
  if [[ -n "$arg" ]]; then repo_name="$arg"
  else
    root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
    repo_name="$(basename "$root")"
  fi
  repos="$repo_name"
fi

[[ -n "$repos" ]] || { echo "Nessuno stato in ~/.claude/state/. Avvia qualche sessione con la statusLine attiva."; exit 0; }

for repo in $repos; do
  sdir="$CLAUDE_DIR/state/$repo"
  samples="$sdir/ctx-samples.tsv"
  clog="$sdir/compaction-log.tsv"
  [[ -f "$samples" || -f "$clog" ]] || continue

  echo "════════════════════════════════════════════════════════"
  echo "Repo: $repo"
  echo "════════════════════════════════════════════════════════"

  if [[ -f "$samples" ]]; then
    echo "— Campioni statusLine (% token reale) —"
    awk -F'\t' 'NR>1 && $4 ~ /^[0-9.]+$/ {
        n++; s=$4+0;
        if (s>max) max=s;
        if (!($2 in seen)) { seen[$2]=1; ns++ }
        if (s>peak[$2]) peak[$2]=s;
      }
      END{
        if (n==0){ print "  (nessun campione numerico ancora)" }
        else { printf "  campioni: %d · sessioni: %d · picco assoluto: %.0f%%\n", n, ns, max }
      }' "$samples"
  else
    echo "— Campioni statusLine: assenti (statusLine non installata?) —"
  fi

  if [[ -f "$clog" ]]; then
    echo "— Eventi di compattazione —"
    awk -F'\t' 'NR>1{
        c++; trig=$2; pct=$3; mb=$4;
        printf "  %s  trigger=%-6s  ctx=%s%%  transcript=%s MB\n", $1, trig, pct, mb;
        if (trig=="auto" && pct ~ /^[0-9.]+$/){ if (minauto==0 || pct+0<minauto) minauto=pct+0; an++ }
        if (trig=="auto" && mb  ~ /^[0-9.]+$/){ summb+=mb+0; mn++ }
      }
      END{
        if (c==0){ print "  (nessun evento)" }
        if (an>0) printf "  → auto-compact osservato a partire da ~%.0f%% (su %d eventi)\n", minauto, an;
        if (mn>0) printf "  → transcript medio agli auto-compact: ~%.1f MB\n", summb/mn;
      }' "$clog"
  else
    echo "— Eventi di compattazione: nessuno ancora —"
  fi

  echo "— Soglie consigliate —"
  # Deriva da: minimo % a cui è scattato auto-compact (ceiling empirico).
  read -r minauto avgmb < <(awk -F'\t' 'NR>1{
      if ($2=="auto" && $3 ~ /^[0-9.]+$/){ if (m==0||$3+0<m) m=$3+0 }
      if ($2=="auto" && $4 ~ /^[0-9.]+$/){ s+=$4+0; k++ }
    } END{ printf "%.0f %.1f", m, (k? s/k : 0) }' "$clog" 2>/dev/null || echo "0 0")
  maxpct="$(awk -F'\t' 'NR>1 && $4 ~ /^[0-9.]+$/ && $4+0>m{m=$4+0} END{printf "%.0f", m}' "$samples" 2>/dev/null || echo 0)"

  if [[ "${minauto:-0}" != "0" ]]; then
    warn=$(( minauto - 8 )); (( warn < 50 )) && warn=50
    soft=$(( warn - 15 ));   (( soft < 35 )) && soft=35
    echo "  Base: auto-compact a ~${minauto}% → margine di sicurezza sotto."
    echo "    export CTX_WARN_PCT=${warn}"
    echo "    export CTX_SOFT_PCT=${soft}"
    if [[ "${avgmb:-0}" != "0.0" && "${avgmb:-0}" != "0" ]]; then
      wmb="$(awk -v a="$avgmb" 'BEGIN{printf "%.1f", a*0.8}')"
      smb="$(awk -v a="$avgmb" 'BEGIN{printf "%.1f", a*0.6}')"
      echo "  (fallback byte, se usi una sessione senza statusLine:)"
      echo "    export CTX_WARN_MB=${wmb}    export CTX_SOFT_MB=${smb}"
    fi
  elif [[ "${maxpct:-0}" != "0" ]]; then
    warn=$(( maxpct > 5 ? maxpct - 5 : maxpct )); (( warn > 90 )) && warn=90; (( warn < 50 )) && warn=50
    soft=$(( warn - 15 )); (( soft < 35 )) && soft=35
    echo "  Nessun auto-compact ancora; picco osservato ~${maxpct}%."
    echo "  Parti prudente e affina dopo qualche auto-compact:"
    echo "    export CTX_WARN_PCT=${warn}"
    echo "    export CTX_SOFT_PCT=${soft}"
  else
    echo "  Dati insufficienti. Lavora qualche sessione lunga con la statusLine attiva,"
    echo "  poi rilancia: i default (WARN 78 / SOFT 60) sono un punto di partenza ragionevole."
  fi
  echo
done
