#!/usr/bin/env bash
# bootstrap.sh — wiring IN-PLACE del Claude Context Kit dentro ~/.claude.
# NON copia file (a differenza del vecchio install.sh): assume che QUESTA cartella
# sia ~/.claude (clonata o estratta qui). Si limita a:
#   - rendere eseguibili hook e statusline;
#   - creare le cartelle runtime ignorate da git (state/, repos/);
#   - inizializzare il repo git se manca (nessun commit automatico).
# Esegui da dentro ~/.claude:  bash bootstrap.sh

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ "$here" != "$claude_dir" ]]; then
  echo "⚠️  Questa cartella:   $here"
  echo "    Claude Code usa:  $claude_dir"
  echo "    Per il modello \"tutto versionato\" questa cartella DOVREBBE essere $claude_dir."
  echo "    Clona/estrai qui, oppure esporta CLAUDE_CONFIG_DIR=\"$here\". Proseguo comunque."
  echo
fi

if [[ ! -f .gitignore ]]; then
  echo "‼  Manca .gitignore: rischi di committare segreti e transcript. Interrompo."
  echo "   Recupera il .gitignore del kit prima di procedere."
  exit 1
fi

echo "→ Rendo eseguibili hook, statusline e bootstrap"
chmod +x hooks/*.sh statusline.sh bootstrap.sh 2>/dev/null || true

echo "→ Creo le cartelle runtime (ignorate da git): state/ repos/"
mkdir -p state repos

if [[ ! -d .git ]]; then
  echo "→ Inizializzo il repo git qui (nessun commit automatico)"
  git init -q
  git add .gitignore 2>/dev/null || true
  echo "   repo creato; .gitignore in stage. NIENTE è ancora committato."
else
  echo "→ Repo git già presente (probabile clone): ok"
fi

cat <<'EOF'

✓ Bootstrap completato. Prossimi passi:
  1) Riavvia Claude Code
  2) /hooks   → approva lo snapshot dell'hook SessionStart
  3) /memory  → conferma che CLAUDE.md è caricato
  4) verifica che la statusLine in basso mostri "ctx %"

Versionare SOLO la configurazione (consigliato — niente segreti né transcript):
  cd "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  git add .gitignore CLAUDE.md settings.json statusline.sh hooks/ \
          skills/ repos/_TEMPLATE/ README.md INSTALL.md bootstrap.sh
  git commit -m "feat: claude context kit"
  # su un TUO remote PRIVATO:
  # git remote add origin <url-privato> && git push -u origin main

Privacy: state/ e i contesti repo reali (repos/<repo>) sono IGNORATI apposta
(contengono transcript e architetture dei progetti). Per versionare un singolo contesto,
consapevolmente:  git add -f repos/<nome-repo>/
EOF
